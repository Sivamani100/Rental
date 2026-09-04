import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/bouncing_button.dart';
import '../widgets/rental_app_icon.dart';
import 'posting_screen.dart';
import 'property_details_screen.dart';
import '../widgets/location_picker_sheet.dart';
import 'search_screen.dart';
import 'ai_chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/analytics_service.dart';
import '../services/transport_service.dart';
import 'package:latlong2/latlong.dart';
import '../models/property_model.dart';


class HomeScreen extends StatefulWidget {
  final String? initialPropertyId;

  const HomeScreen({super.key, this.initialPropertyId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Top-level isolate helper for JSON parsing
List<PropertyModel> _parsePropertiesIsolate(String jsonStr) {
  final decoded = jsonDecode(jsonStr) as List;
  return decoded.map((e) => PropertyModel.fromJson(e as Map<String, dynamic>)).toList();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedTypeIndex = 0; // 0 for PG / Hostel, 1 for Rental
  late final PageController _pageController;

  // Scroll position memory: one controller per tab
  final ScrollController _pgScrollController = ScrollController();
  final ScrollController _rentalScrollController = ScrollController();
  final ScrollController _buyScrollController = ScrollController();

  Position? _currentPosition;
  String _currentCity = 'Finding location...';
  String _currentArea = 'Detecting your area...';
  bool _hasLocationPermission = true;
  bool _isInitialLoading = true;

  // Custom location overrides
  Position? _manualLocationOverride;
  String? _manualLocationName;
  Timer? _locationPromptTimer;

  Position? get _effectivePosition => _manualLocationOverride ?? _currentPosition;

  List<PropertyModel> _allProperties = [];
  int _currentSearchRadiusKm = 5;

  final _supabase = Supabase.instance.client;
  // Replaced 1-second Timer with distance-filtered position stream
  StreamSubscription<Position>? _locationStream;
  RealtimeChannel? _propertiesChannel;
  bool _isRefreshingLocation = false;
  bool _hasOpenedInitialProperty = false;

  // Geocoding throttle — only re-geocode when user moves >500m
  Position? _lastGeocodedPosition;

  // Cache version guard — bump this whenever PropertyModel.fromJson schema changes
  static const int _cacheVersion = 3;

  // Double-back-to-exit support
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedTypeIndex);
    WidgetsBinding.instance.addObserver(this);
    _initAppAndLocation();
  }

  Future<void> _initAppAndLocation() async {
    // Load cached properties IMMEDIATELY so UI shows content fast.
    // GPS and fresh network data arrive in background.
    await _loadCachedPropertiesInstantly();
    await _loadManualLocation();

    // Start GPS stream and fresh data fetch in parallel (non-blocking)
    _startLocationStream();
    _fetchProperties(); // fire-and-forget

    // Subscribe to realtime new approvals
    _subscribeToRealtimeUpdates();

    if (mounted) {
      _checkAndOpenInitialProperty();
    }
  }

  /// Loads cached properties synchronously-fast from SharedPrefs,
  /// then immediately hides the loading gate so the feed is visible.
  Future<void> _loadCachedPropertiesInstantly() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Cache version guard: discard if schema is outdated
      final savedVersion = prefs.getInt('cached_properties_version') ?? 0;
      if (savedVersion < _cacheVersion) {
        await prefs.remove('cached_properties');
        await prefs.remove('cached_properties_ts');
        await prefs.setInt('cached_properties_version', _cacheVersion);
      }

      final cachedData = prefs.getString('cached_properties');
      if (cachedData != null && cachedData.isNotEmpty && mounted) {
        // Decode off main thread to avoid UI jank
        final cachedList = await compute(_parsePropertiesIsolate, cachedData);
        if (mounted) {
          setState(() {
            _allProperties = cachedList;
            _isInitialLoading = false; // Show feed immediately with cache
          });
          _precachePropertyImages(cachedList);
          _checkAndOpenInitialProperty();
        }
      } else if (mounted) {
        // No cache — keep loading spinner until first network result arrives
        // (will be dismissed in _fetchProperties)
      }
    } catch (_) {}
  }

  void _checkAndOpenInitialProperty() async {
    if (_hasOpenedInitialProperty) return;
    String? targetId = widget.initialPropertyId;
    if (targetId == null && kIsWeb) {
      targetId = Uri.base.queryParameters['propertyId'] ?? Uri.base.queryParameters['id'];
    }

    if (targetId != null && targetId.isNotEmpty) {
      _hasOpenedInitialProperty = true;
      try {
        PropertyModel? found;
        try {
          found = _allProperties.firstWhere((p) => p.id == targetId);
        } catch (_) {}

        if (found == null) {
          final res = await _supabase.from('properties').select().eq('id', targetId).maybeSingle();
          if (res != null) {
            found = PropertyModel.fromJson(res);
          }
        }

        if (found != null && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PropertyDetailsScreen(property: found!),
                ),
              );
            }
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _loadManualLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('manual_lat');
    final lng = prefs.getDouble('manual_lng');
    final name = prefs.getString('manual_name');

    if (lat != null && lng != null) {
      setState(() {
        _manualLocationOverride = Position(
          latitude: lat,
          longitude: lng,
          timestamp: DateTime.now(),
          accuracy: 1,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
        _manualLocationName = name;
        if (name != null) {
          _currentCity = name;
          _currentArea = 'Custom Location';
        }
      });
      _startLocationPromptTimer();
    }
  }

  Future<void> _saveManualLocation(Position pos, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('manual_lat', pos.latitude);
    await prefs.setDouble('manual_lng', pos.longitude);
    await prefs.setString('manual_name', name);
    
    setState(() {
      _manualLocationOverride = pos;
      _manualLocationName = name;
      _currentCity = name;
      _currentArea = 'Custom Location';
    });
    
    _startLocationPromptTimer();
    if (mounted) setState(() {});
  }

  void _clearManualLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('manual_lat');
    await prefs.remove('manual_lng');
    await prefs.remove('manual_name');
    
    _locationPromptTimer?.cancel();
    
    setState(() {
      _manualLocationOverride = null;
      _manualLocationName = null;
    });
    
    _refreshLocationFast(updateFeed: true);
  }

  void _startLocationPromptTimer() {
    _locationPromptTimer?.cancel();
    _locationPromptTimer = Timer(const Duration(minutes: 5), () {
      if (mounted && _manualLocationOverride != null) {
        _showLocationPromptSheet();
      }
    });
  }

  void _showLocationPromptSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardElevated : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF33333E) : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Iconsax.location_tick, size: 48, color: isDark ? AppTheme.primaryYellow : Colors.black),
              const SizedBox(height: 16),
              Text(
                'Use Current Location?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You are currently viewing a custom location. Would you like to switch back to your real-time GPS location?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: BouncingButton(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'No, Keep Custom',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: BouncingButton(
                      onTap: () {
                        Navigator.pop(context);
                        _clearManualLocation();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.primaryYellow : Colors.black,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Yes, Switch Back',
                          style: TextStyle(
                            color: isDark ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Uses Geolocator position stream with distanceFilter so GPS only fires
  /// when the user physically moves ≥15 meters. Replaces the old 1-second timer.
  void _startLocationStream() {
    _locationStream?.cancel();
    _locationStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 15, // metres — only fires on real movement
      ),
    ).listen((position) {
      if (!mounted) return;
      _currentPosition = position;
      if (_manualLocationOverride == null) {
        _updateGeocodingIfNeeded(position);
        if (mounted) setState(() {}); // Re-sort feed
      }
    }, onError: (_) {
      // Stream errors are non-fatal — fall back to single fetch
      _refreshLocationFast(updateFeed: false);
    });

    // Always do one immediate fetch so we have a position on first open
    _refreshLocationFast(updateFeed: false);
  }

  /// Supabase realtime: auto-refresh feed when admin approves a new property.
  void _subscribeToRealtimeUpdates() {
    try {
      _propertiesChannel = _supabase
          .channel('home-properties-feed')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'properties',
            callback: (payload) {
              // Only react to status becoming 'approved'
              final newStatus = payload.newRecord['status'];
              if (newStatus == 'approved') {
                _fetchProperties();
              }
            },
          )
          .subscribe();
    } catch (_) {
      // Realtime is optional — fail silently
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pgScrollController.dispose();
    _rentalScrollController.dispose();
    _buyScrollController.dispose();
    _locationStream?.cancel();
    if (_propertiesChannel != null) {
      _supabase.removeChannel(_propertiesChannel!);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Restart stream in case it was paused by OS
      _startLocationStream();
      _fetchProperties();
    } else if (state == AppLifecycleState.paused) {
      _locationStream?.cancel();
    }
  }

  Future<void> _fetchProperties() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Cache freshness check — skip network if cache is <5 minutes old
      final cachedTs = prefs.getInt('cached_properties_ts');
      final isCacheFresh = cachedTs != null &&
          (DateTime.now().millisecondsSinceEpoch - cachedTs) < 5 * 60 * 1000;

      if (isCacheFresh && _allProperties.isNotEmpty) {
        // Cache is fresh enough — no network call needed right now
        return;
      }

      // Fetch fresh data from network (only approved properties)
      final data = await _supabase
          .from('properties')
          .select()
          .eq('status', 'approved');

      // Update cache with timestamp and version
      final encoded = jsonEncode(data);
      await prefs.setString('cached_properties', encoded);
      await prefs.setInt('cached_properties_ts', DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt('cached_properties_version', _cacheVersion);

      if (mounted) {
        // Decode on background isolate to avoid UI jank
        final freshList = await compute(_parsePropertiesIsolate, encoded);
        setState(() {
          _allProperties = freshList;
          _isInitialLoading = false; // Dismiss spinner once we have real data
        });
        _precachePropertyImages(freshList);
        _checkAndOpenInitialProperty();
      }
    } catch (e) {
      if (mounted) {
        // Dismiss loading spinner even on failure so UI doesn't stay stuck
        if (_isInitialLoading) setState(() => _isInitialLoading = false);
        if (_allProperties.isNotEmpty) {
          AppSnackbar.error(context, 'Offline mode: Showing cached properties.');
        } else {
          AppSnackbar.error(context, 'Failed to load properties. Check connection.');
        }
      }
    }
  }

  void _precachePropertyImages(List<PropertyModel> properties) {
    if (!mounted) return;
    // Phase 1: Pre-cache thumbnails for first 10 visible cards immediately
    for (final prop in properties.take(10)) {
      if (prop.imageUrls.isNotEmpty) {
        final firstUrl = prop.imageUrls.first;
        if (firstUrl.startsWith('http')) {
          try {
            precacheImage(
              CachedNetworkImageProvider(firstUrl, maxWidth: 600),
              context,
            );
          } catch (_) {}
        }
      }
    }
    // Phase 2: Pre-cache full detail resolution after 2-second idle
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      for (final prop in properties.take(10)) {
        if (prop.imageUrls.isNotEmpty) {
          final firstUrl = prop.imageUrls.first;
          if (firstUrl.startsWith('http')) {
            try {
              precacheImage(
                CachedNetworkImageProvider(firstUrl, maxWidth: 1080),
                context,
              );
            } catch (_) {}
          }
        }
      }
    });
  }

  /// Single GPS fetch — used for initial load and manual refresh.
  /// The continuous stream (_startLocationStream) handles subsequent updates.
  Future<void> _refreshLocationFast({bool updateFeed = false}) async {
    if (_isRefreshingLocation) return;
    _isRefreshingLocation = true;
    if (mounted) setState(() {});

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() { _hasLocationPermission = false; _isRefreshingLocation = false; });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (mounted) setState(() { _hasLocationPermission = false; _isRefreshingLocation = false; });
          return;
        }
      }

      if (mounted) setState(() { _hasLocationPermission = true; });

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) return;
      if (!mounted) return;
      _currentPosition = position;
      if (_manualLocationOverride == null) {
        if (mounted) setState(() {});
        await _updateGeocodingIfNeeded(position, force: true);
      }
    } catch (_) {
      // Fallback already pre-rendered
    } finally {
      if (mounted) {
        setState(() { _isRefreshingLocation = false; });
      } else {
        _isRefreshingLocation = false;
      }
    }
  }

  /// Geocoding throttle: only call the network geocoding API when user moves
  /// more than 500 meters from the last geocoded position, unless forced.
  Future<void> _updateGeocodingIfNeeded(Position position, {bool force = false}) async {
    if (!force && _lastGeocodedPosition != null) {
      final movedMeters = Geolocator.distanceBetween(
        _lastGeocodedPosition!.latitude,
        _lastGeocodedPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      if (movedMeters < 500) return; // Not far enough to re-geocode
    }
    _lastGeocodedPosition = position;

    try {
      final placemarks = await Geocoding()
          .placemarkFromCoordinates(position.latitude, position.longitude)
          .timeout(const Duration(seconds: 3));
      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        setState(() {
          _currentCity =
              place.locality ?? place.subLocality ?? place.name ?? 'Finding location...';
          _currentArea =
              '${place.subAdministrativeArea ?? place.administrativeArea ?? ''}, ${place.country ?? ''}'
                  .replaceAll(RegExp(r'^,\s*'), '')
                  .replaceAll(RegExp(r',\s*$'), '');
          if (_currentArea.trim().isEmpty) {
            _currentArea = 'Detecting your area...';
          }
        });
      }
    } catch (_) {
      // Keep current city label — geocoding is non-critical
    }
  }

  List<PropertyModel> _getSortedPropertiesForType(String selectedTypeStr) {
    bool matchesType(PropertyModel property) {
      if (selectedTypeStr == 'Rental') {
        return property.type == 'Rental' || property.type == 'House';
      } else if (selectedTypeStr == 'Buy') {
        return property.type == 'Buy' || property.type == 'Sale' || property.type == 'Plot' || property.type == 'Land';
      } else {
        return property.type == 'PG' || property.type == 'Hostel';
      }
    }

    final currentPos = _effectivePosition;
    if (currentPos == null) {
      return _allProperties.where(matchesType).toList();
    }

    int searchRadiusKm = 5;
    List<PropertyModel> tempFiltered = [];

    // Increment radius by 5km until we find properties or hit 50km limit
    while (searchRadiusKm <= 50) {
      tempFiltered = _allProperties.where((property) {
        if (!matchesType(property)) return false;

        double distanceInMeters = Geolocator.distanceBetween(
          currentPos.latitude,
          currentPos.longitude,
          property.latitude,
          property.longitude,
        );

        return distanceInMeters <= (searchRadiusKm * 1000);
      }).toList();

      if (tempFiltered.isNotEmpty) {
        break;
      }
      searchRadiusKm += 5;
    }

    if (tempFiltered.isEmpty) {
      // Returning empty list triggers the empty state with our new custom location prompts
      tempFiltered = [];
    }

    // Sort strictly in ascending order by distance (closest first: 20m, 30m, 1.2km, etc.)
    tempFiltered.sort((a, b) {
      double distA = Geolocator.distanceBetween(
        currentPos.latitude,
        currentPos.longitude,
        a.latitude,
        a.longitude,
      );
      double distB = Geolocator.distanceBetween(
        currentPos.latitude,
        currentPos.longitude,
        b.latitude,
        b.longitude,
      );
      return distA.compareTo(distB);
    });

    _currentSearchRadiusKm = searchRadiusKm > 50 ? 50 : searchRadiusKm;
    return tempFiltered;
  }

  /// Get the scroll controller for the active tab
  ScrollController _controllerForType(String typeStr) {
    switch (typeStr) {
      case 'PG': return _pgScrollController;
      case 'Buy': return _buyScrollController;
      default: return _rentalScrollController;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show loading only when truly no data AND no permission issue
    if (_isInitialLoading && _allProperties.isEmpty && _hasLocationPermission) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkScaffold : const Color(0xFFFBF7F7),
        body: SizedBox.expand(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 190,
                    width: 260,
                    child: OverflowBox(
                      maxHeight: 500,
                      maxWidth: 500,
                      child: ColorFiltered(
                        colorFilter: isDark
                            ? const ColorFilter.matrix([-1, 0, 0, 0, 255, 0, -1, 0, 0, 255, 0, 0, -1, 0, 255, 0, 0, 0, 1, 0])
                            : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                        child: Lottie.asset(
                          'assets/loadingg.json',
                          width: 500,
                          height: 500,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Finding location...',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_hasLocationPermission) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkScaffold : Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ColorFiltered(
                    colorFilter: isDark
                        ? const ColorFilter.matrix([-1, 0, 0, 0, 255, 0, -1, 0, 0, 255, 0, 0, -1, 0, 255, 0, 0, 0, 1, 0])
                        : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                    child: Lottie.asset(
                      'assets/location.json',
                      width: 250,
                      height: 250,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Location Access Required',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We need your location to show you the best properties around you in ascending order of distance. Please allow location access to continue.',
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextSecondary : Colors.black54,
                      fontSize: 15,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  BouncingButton(
                    onTap: () {
                      Geolocator.openAppSettings();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.primaryYellow : Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Iconsax.setting_2,
                            color: isDark ? Colors.black : Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Open Settings',
                            style: TextStyle(
                              color: isDark ? Colors.black : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      // Double-back-to-exit: press back twice within 2 seconds to exit
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPress != null && now.difference(_lastBackPress!).inSeconds < 2) {
          SystemNavigator.pop();
          return;
        }
        _lastBackPress = now;
        AppSnackbar.error(context, 'Press back again to exit');
      },
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkScaffold : const Color(0xFFFBF7F7),
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Stack(
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 16.0,
                          right: 16.0,
                          top: 16.0, // Added 10px top margin
                          bottom: 8.0,
                        ),
                        child: _buildHeader(context),
                      ),
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: (index) {
                            if (_selectedTypeIndex != index) {
                              setState(() {
                                _selectedTypeIndex = index;
                              });
                              AnalyticsService.instance.logCategoryClick(index == 0 ? 'Hostel' : (index == 2 ? 'Buy' : 'Rental'));
                              HapticFeedback.selectionClick();
                            }
                          },
                          children: [
                            _buildTabContent('PG'),
                            _buildTabContent('Rental'),
                            _buildTabContent('Buy'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Pinned floating bottom toggle, always sitting 20px above
                  // the system navigation bar (works for gesture, 2-btn & 3-btn nav)
                  Builder(
                    builder: (ctx) {
                      final navBarHeight = MediaQuery.of(ctx).padding.bottom;
                      return Positioned(
                        left: 0,
                        right: 0,
                        bottom: navBarHeight + 20,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: _buildBottomToggle(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(String typeStr) {
    final properties = _getSortedPropertiesForType(typeStr);
    String emptyLabel;
    if (typeStr == 'PG') {
      emptyLabel = 'Hostels / PGs';
    } else if (typeStr == 'Buy') {
      emptyLabel = 'Buy properties';
    } else {
      emptyLabel = 'Rentals';
    }

    final scrollCtrl = _controllerForType(typeStr);

    return RefreshIndicator(
      color: Colors.black,
      backgroundColor: const Color(0xFFFFEB3A),
      displacement: 32,
      edgeOffset: 8,
      triggerMode: RefreshIndicatorTriggerMode.anywhere,
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        // Force-clear cache freshness so full refresh happens
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('cached_properties_ts');
        final refreshFuture = Future.wait([
          _refreshLocationFast(updateFeed: true),
          _fetchProperties(),
        ]);
        // Keep the pull-to-refresh spinner spinning for 2 seconds
        await Future.wait([
          refreshFuture,
          Future.delayed(const Duration(seconds: 2)),
        ]);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            controller: scrollCtrl, // Scroll position memory per tab
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 16.0,
              bottom: 120.0, // Space to float above bottom toggle
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight > 140 ? constraints.maxHeight - 140 : 300,
              ),
              child: properties.isEmpty
                  ? Center(
                      child: _buildEmptyState(emptyLabel),
                    )
                  : _buildPropertyList(properties),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        _TopLocationLogoSwitcher(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _currentCity = 'Finding location...';
              _currentArea = 'Detecting your area...';
              _manualLocationOverride = null;
              _manualLocationName = null;
            });
            _refreshLocationFast(updateFeed: true);
          },
          // Double-tap scrolls active tab back to top
          onDoubleTap: () {
            HapticFeedback.mediumImpact();
            final typeStr = _selectedTypeIndex == 0 ? 'PG' : (_selectedTypeIndex == 2 ? 'Buy' : 'Rental');
            final ctrl = _controllerForType(typeStr);
            if (ctrl.hasClients) {
              ctrl.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
            }
          },
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: _showLocationOptionsSheet,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _currentCity,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black,
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDark ? Colors.white70 : Colors.black54,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _currentArea,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade500,
                    fontWeight: FontWeight.w400,
                    height: 1.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        // Dark / Light Mode Toggle Button (Hidden for now, available for later activation)
        if (false) ...[
          BouncingButton(
            onTap: () {
              HapticFeedback.selectionClick();
              ThemeController.instance.toggleTheme();
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : Colors.black.withValues(alpha: 0.06),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                isDark ? Iconsax.sun_1 : Iconsax.moon,
                color: isDark ? const Color(0xFFFFEB3A) : const Color(0xFF141416),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        // Search Icon Button before Post
        BouncingButton(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SearchScreen(
                  properties: _allProperties,
                  currentPosition: _currentPosition,
                  initialCategory: 'All',
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Iconsax.search_normal_1,
              color: isDark ? Colors.white : Colors.black87,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 10),
        BouncingButton(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: isDark ? AppTheme.darkScaffold : const Color(0xFFFBF7F7),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => PostBottomSheet(
                currentLocation: _currentPosition,
                onPropertyCreated: (newProp) {
                  // Property is pending admin review - do not inject into live feed
                  _fetchProperties();
                },
              ),
            ).then((_) {
              _fetchProperties();
            });
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEB3A),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Iconsax.add,
                    color: isDark ? const Color(0xFFFFEB3A) : Colors.black,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Post',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomToggle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tabItems = [
      (label: 'Hostel', activeIcon: Iconsax.buildings5, inactiveIcon: Iconsax.buildings),
      (label: 'Rental', activeIcon: Iconsax.house5, inactiveIcon: Iconsax.house),
      (label: 'Buy', activeIcon: Iconsax.key5, inactiveIcon: Iconsax.key),
    ];

    return Container(
      height: 60, // Slightly increased height
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.black.withValues(alpha: 0.08),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(tabItems.length, (index) {
          final isSelected = _selectedTypeIndex == index;
          final item = tabItems[index];

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: BouncingButton(
              onTap: () {
                if (_selectedTypeIndex != index) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedTypeIndex = index;
                  });
                  AnalyticsService.instance.logCategoryClick(item.label);
                  if (_pageController.hasClients) {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOutCubic,
                    );
                  }
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOutCubic,
                padding: isSelected
                    ? const EdgeInsets.only(left: 24, right: 24, top: 10, bottom: 10) // Extra padding for active state
                    : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFFEB3A) : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected ? item.activeIcon : item.inactiveIcon, // Use filled icon if selected
                      size: 20, // Slightly increased icon size
                      color: isSelected ? Colors.black : (isDark ? Colors.white54 : Colors.black54),
                    ),
                    const SizedBox(width: 5), // Reduced padding between icon and text
                    Text(
                      item.label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: isSelected ? Colors.black : (isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                        fontWeight: FontWeight.w600, // Keep constant to prevent layout shifting
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState(String typeStr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            ColorFiltered(
              colorFilter: isDark
                  ? const ColorFilter.matrix([-1, 0, 0, 0, 255, 0, -1, 0, 0, 255, 0, 0, -1, 0, 255, 0, 0, 0, 1, 0])
                  : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
              child: Lottie.asset(
                'assets/Nothing founded.json',
                width: 250,
                height: 250,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No $typeStr found within ${_currentSearchRadiusKm}km radius.',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 19,
                fontWeight: FontWeight.bold,
                height: 1.25,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            BouncingButton(
              onTap: () {
                _showLocationOptionsSheet();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.primaryYellow : Colors.black,
                  borderRadius: BorderRadius.circular(50), // Fully rounded
                ),
                alignment: Alignment.center,
                child: Text(
                  'Use another location',
                  style: TextStyle(
                    color: isDark ? Colors.black : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationOptionsSheet() async {
    final currentPos = _effectivePosition ?? Position(
      latitude: 17.3850, longitude: 78.4867, // Default to Hyderabad
      timestamp: DateTime.now(), accuracy: 1, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0,
    );

    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LocationPickerSheet(
        initialLatitude: currentPos.latitude,
        initialLongitude: currentPos.longitude,
        properties: _allProperties,
      ),
    );

    if (result != null && mounted) {
      final pos = result['position'] as Position;
      final address = result['address'] as String;
      _saveManualLocation(pos, address);
    }
  }

  Widget _buildPropertyList(List<PropertyModel> properties) {
    return Column(
      children: properties.map((prop) {
        double? distance;
        final currentPos = _effectivePosition;
        if (currentPos != null) {
          distance = Geolocator.distanceBetween(
            currentPos.latitude,
            currentPos.longitude,
            prop.latitude,
            prop.longitude,
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: PropertyCard(
            property: prop,
            distanceInMeters: distance,
            onTap: () {
              // Pre-fetch transport data the moment user taps — before navigation
              final transportFuture = TransportService.getNearby(
                prop.latitude,
                prop.longitude,
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PropertyDetailsScreen(
                    property: prop,
                    preloadedTransportFuture: transportFuture,
                  ),
                ),
              ).then((_) {
                setState(() {});
              });
            },
          ),
        );
      }).toList(),
    );
  }
}

class PropertyCard extends StatelessWidget {
  final PropertyModel property;
  final double? distanceInMeters;
  final VoidCallback onTap;

  const PropertyCard({
    super.key,
    required this.property,
    this.distanceInMeters,
    required this.onTap,
  });

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m away';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km away';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BouncingButton(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : Colors.transparent,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: property.imageUrls.isNotEmpty
                        ? property.imageUrls.first
                        : '',
                    height: 230,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    memCacheWidth: 800,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholder: (context, url) => Container(
                      height: 230,
                      color: isDark ? AppTheme.darkCardElevated : Colors.grey.shade100,
                      child: Center(
                        child: Icon(Iconsax.image, color: Colors.grey.shade400, size: 28),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 230,
                      color: isDark ? AppTheme.darkCardElevated : Colors.grey[200],
                      child: const Center(
                        child: Icon(Iconsax.image, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                // Top Left: Real Ratings Only (shown only when reviewCount > 0)
                if (property.reviewCount > 0)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkCard.withValues(alpha: 0.92)
                            : Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? AppTheme.darkBorder : Colors.black.withValues(alpha: 0.06),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Iconsax.star1, color: Colors.amber, size: 15),
                          const SizedBox(width: 4),
                          Text(
                            property.averageRating.toStringAsFixed(1),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            ' (${property.reviewCount})',
                            style: TextStyle(
                              color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Top Right: Availability Status (PhonePe payment success green at 100% solid opacity, clean text without dot)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5.5),
                    decoration: BoxDecoration(
                      color: property.isAvailable
                          ? const Color(0xFF1A9E5B) // PhonePe Payment Success Green (100% solid)
                          : Colors.redAccent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      property.isAvailable ? 'Available' : 'Not Available',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                // Bottom Strip: Alternates every 4s between info & scrolling Admin Approved banner
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _CardBottomStrip(
                    property: property,
                    distanceInMeters: distanceInMeters,
                    formatDistance: _formatDistance,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: '${property.title} '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Icon(
                                  Iconsax.verify5,
                                  size: 16,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        property.price,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.primaryYellow : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Location with Location Icon and Distance
                  Row(
                    children: [
                      const Icon(
                        Iconsax.location5,
                        color: Color(0xFFF59E0B),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          distanceInMeters != null
                              ? '${property.locationStr} • ${_formatDistance(distanceInMeters!)}'
                              : property.locationStr,
                          style: TextStyle(
                            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Tags - Single horizontal row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: property.tags.map((tag) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: _buildTag(context, tag),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Divider(
                    height: 1,
                    color: isDark ? AppTheme.darkBorder : const Color(0xFFEEEEEE),
                  ),
                  const SizedBox(height: 14),
                  // Bottom Row (Beds, Baths, Area)
                  if (property.type == 'PG')
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildBottomInfo(context, Iconsax.moon5, property.beds),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14.0),
                            child: Container(
                              height: 16,
                              width: 1,
                              color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                            ),
                          ),
                          _buildBottomInfo(context, Iconsax.drop, property.baths),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14.0),
                            child: Container(
                              height: 16,
                              width: 1,
                              color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                            ),
                          ),
                          _buildBottomInfo(context, Iconsax.maximize4, property.area),
                        ],
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildBottomInfo(context, Iconsax.moon5, property.beds),
                        Container(
                          height: 16,
                          width: 1,
                          color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                        ),
                        _buildBottomInfo(context, Iconsax.drop, property.baths),
                        Container(
                          height: 16,
                          width: 1,
                          color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                        ),
                        _buildBottomInfo(context, Iconsax.maximize4, property.area),
                      ],
                    ),
                  if (property.type == 'PG' && 
                     ((property.perDayWithFood != null && property.perDayWithFood!.isNotEmpty) || 
                      (property.perDayWithoutFood != null && property.perDayWithoutFood!.isNotEmpty)))
                    Column(
                      children: [
                        const SizedBox(height: 14),
                        Divider(
                          height: 1,
                          color: isDark ? AppTheme.darkBorder : const Color(0xFFEEEEEE),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (property.perDayWithFood != null && property.perDayWithFood!.isNotEmpty)
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(Iconsax.calendar5, color: Colors.grey.shade500, size: 16),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        '₹${property.perDayWithFood}/day with food',
                                        style: TextStyle(
                                          color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if ((property.perDayWithFood != null && property.perDayWithFood!.isNotEmpty) &&
                                (property.perDayWithoutFood != null && property.perDayWithoutFood!.isNotEmpty))
                              Container(
                                height: 16,
                                width: 1,
                                color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                              ),
                            if (property.perDayWithoutFood != null && property.perDayWithoutFood!.isNotEmpty)
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(Iconsax.calendar_15, color: Colors.grey.shade500, size: 16),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        '₹${property.perDayWithoutFood}/day without food',
                                        style: TextStyle(
                                          color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardElevated : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildBottomInfo(BuildContext context, IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ==========================================
// SKELETON LOADING WIDGETS
// ==========================================

class SkeletonPropertyCard extends StatelessWidget {
  const SkeletonPropertyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.transparent,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ShimmerEffect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area shimmer
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: const SkeletonBox(
                    width: double.infinity,
                    height: 200,
                    borderRadius: 0,
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 56,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkCardElevated.withValues(alpha: 0.8)
                          : Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Price row
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonBox(width: 140, height: 18, borderRadius: 6),
                      SkeletonBox(width: 75, height: 18, borderRadius: 6),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Location row
                  Row(
                    children: [
                      const SkeletonBox(width: 16, height: 16, borderRadius: 8),
                      const SizedBox(width: 6),
                      SkeletonBox(
                        width: MediaQuery.of(context).size.width * 0.45,
                        height: 13,
                        borderRadius: 4,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Single row tags
                  const Row(
                    children: [
                      SkeletonBox(width: 65, height: 26, borderRadius: 30),
                      SizedBox(width: 8),
                      SkeletonBox(width: 95, height: 26, borderRadius: 30),
                      SizedBox(width: 8),
                      SkeletonBox(width: 80, height: 26, borderRadius: 30),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(
                    height: 1,
                    color: isDark ? AppTheme.darkBorder : const Color(0xFFEEEEEE),
                  ),
                  const SizedBox(height: 14),
                  // Bottom stats row
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SkeletonBox(width: 60, height: 14, borderRadius: 4),
                      SkeletonBox(width: 60, height: 14, borderRadius: 4),
                      SkeletonBox(width: 65, height: 14, borderRadius: 4),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardBottomStrip extends StatefulWidget {
  final PropertyModel property;
  final double? distanceInMeters;
  final String Function(double) formatDistance;

  const _CardBottomStrip({
    required this.property,
    required this.distanceInMeters,
    required this.formatDistance,
  });

  @override
  State<_CardBottomStrip> createState() => _CardBottomStripState();
}

class _CardBottomStripState extends State<_CardBottomStrip>
    with SingleTickerProviderStateMixin {
  Timer? _stateTimer;
  bool _showAdminVerified = false;
  late AnimationController _scrollAnimController;

  @override
  void initState() {
    super.initState();
    _scrollAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 11),
    );
    _scheduleNextState();
  }

  void _scheduleNextState() {
    _stateTimer?.cancel();
    // 6 seconds for info frame, 11 seconds for scrolling text frame
    final nextDuration = _showAdminVerified
        ? const Duration(seconds: 11)
        : const Duration(seconds: 6);

    _stateTimer = Timer(nextDuration, () {
      if (!mounted) return;
      setState(() {
        _showAdminVerified = !_showAdminVerified;
      });
      if (_showAdminVerified) {
        _scrollAnimController.forward(from: 0.0);
      } else {
        _scrollAnimController.stop();
      }
      _scheduleNextState();
    });
  }

  @override
  void dispose() {
    _stateTimer?.cancel();
    _scrollAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: const BoxDecoration(
        color: Color(0xFFFFEB3A),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.25),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        // Admin approved banner text hidden for now as requested (can be re-enabled later)
        child: _buildStandardInfoView(),
      ),
    );
  }

  Widget _buildStandardInfoView() {
    return Row(
      key: const ValueKey('standard_info'),
      children: [
        // Column 1: Location / Distance
        Expanded(
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Iconsax.location5, color: Colors.black, size: 14.5),
                const SizedBox(width: 4),
                Text(
                  widget.distanceInMeters != null
                      ? widget.formatDistance(widget.distanceInMeters!)
                      : 'Nearby',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.black,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),

        // Divider 1
        Container(
          width: 1.2,
          height: 16,
          color: Colors.black.withValues(alpha: 0.25),
        ),

        // Column 2: Category / Property Type
        Expanded(
          child: Center(
            child: Text(
              widget.property.type == 'PG'
                  ? 'PG / Hostel'
                  : (widget.property.type == 'Buy' ? 'Buy / Sale' : widget.property.type),
              style: const TextStyle(
                fontFamily: 'Inter',
                color: Colors.black,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ),

        // Divider 2
        Container(
          width: 1.2,
          height: 16,
          color: Colors.black.withValues(alpha: 0.25),
        ),

        // Column 3: Rental App Brand
        Expanded(
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const RentalAppIcon(size: 14.5, color: Colors.black),
                const SizedBox(width: 4.5),
                const Text(
                  'Rental App',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.black,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminApprovedView() {
    return ClipRect(
      key: const ValueKey('admin_approved'),
      child: AnimatedBuilder(
        animation: _scrollAnimController,
        builder: (context, child) {
          // Starts at center (dx = 0.40) and glides steadily at 1x speed towards the left
          final double dx = (1.0 - _scrollAnimController.value) * 0.40 +
              (_scrollAnimController.value * -1.25);
          return FractionalTranslation(
            translation: Offset(dx, 0.0),
            child: child,
          );
        },
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          maxWidth: double.infinity,
          child: const Text(
            '100% Genuine Owner Listing   •   This property has been approved & verified by Admin   •   100% Trusted & Verified   •   Direct Owner Contact   •   You can trust and contact directly   •   ',
            style: TextStyle(
              fontFamily: 'Inter',
              color: Colors.black,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              wordSpacing: 1.5,
            ),
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ),
    );
  }
}

class ShimmerEffect extends StatefulWidget {
  final Widget child;
  const ShimmerEffect({super.key, required this.child});

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              colors: isDark
                  ? const [
                      Color(0xFF1E1E28),
                      Color(0xFF2B2B38),
                      Color(0xFF1E1E28),
                    ]
                  : const [
                      Color(0xFFEBEBF2),
                      Color(0xFFF7F7FC),
                      Color(0xFFEBEBF2),
                    ],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value.clamp(0.0, 1.0),
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E28) : const Color(0xFFEBEBF2),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class _TopLocationLogoSwitcher extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  const _TopLocationLogoSwitcher({required this.onTap, this.onDoubleTap});

  @override
  State<_TopLocationLogoSwitcher> createState() => _TopLocationLogoSwitcherState();
}

class _TopLocationLogoSwitcherState extends State<_TopLocationLogoSwitcher> {
  bool _showLogo = false;
  Timer? _switchTimer;

  @override
  void initState() {
    super.initState();
    // Alternates between Location Icon and App Logo smoothly every 3.5 seconds
    _switchTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
      if (mounted) {
        setState(() {
          _showLogo = !_showLogo;
        });
      }
    });
  }

  @override
  void dispose() {
    _switchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onDoubleTap: widget.onDoubleTap,
      child: BouncingButton(
        onTap: widget.onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : Colors.black.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
                  child: child,
                ),
              );
            },
            child: _showLogo
                ? ClipRRect(
                    key: const ValueKey('app_logo'),
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 38,
                      height: 38,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Iconsax.location5,
                        color: isDark ? Colors.white : Colors.black,
                        size: 24,
                      ),
                    ),
                  )
                : Icon(
                    Iconsax.location5,
                    key: const ValueKey('location_icon'),
                    color: isDark ? Colors.white : Colors.black,
                    size: 24,
                  ),
          ),
        ),
      ),
    );
  }
}




