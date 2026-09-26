import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'settings_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
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
import 'saved_properties_screen.dart';
import '../services/saved_properties_service.dart';
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

  final String? initialLocationCity;
  final String? initialLocationSubtext;

  const HomeScreen({
    super.key, 
    this.initialPropertyId,
    this.initialLocationCity,
    this.initialLocationSubtext,
  });

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
  int _bottomNavIndex = 0; // 0 for Home, 1 for Saved, etc.
  late final PageController _pageController;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'distance';

  // Scroll position memory: one controller per tab
  final ScrollController _homeScrollController = ScrollController();
  final ScrollController _pgScrollController = ScrollController();
  final ScrollController _rentalScrollController = ScrollController();
  final ScrollController _buyScrollController = ScrollController();

  Position? _currentPosition;
  late String _currentCity = widget.initialLocationCity ?? 'Finding location...';
  late String _currentArea = widget.initialLocationSubtext ?? 'Detecting your area...';
  bool _hasLocationPermission = true;
  bool _isInitialLoading = true;
  bool _showSplash = false;
  bool _isSplashLocating = true;

  final List<String> _searchHints = ['Hostels', 'Rental Rooms', 'Buy Houses'];
  int _hintIndex = 0;
  Timer? _hintTimer;
  bool _isScrollUIVisible = true;

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
    SavedPropertiesService.instance.addListener(_onSavedChanged);
    
    _hintTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _hintIndex = (_hintIndex + 1) % _searchHints.length;
        });
      }
    });

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
              Icon(CupertinoIcons.location_solid, size: 48, color: isDark ? AppTheme.primaryYellow : Colors.black),
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
    SavedPropertiesService.instance.removeListener(_onSavedChanged);
    _hintTimer?.cancel();
    _searchController.dispose();
    _pageController.dispose();
    _homeScrollController.dispose();
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

  void _onSavedChanged() {
    if (mounted) setState(() {});
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
      if (selectedTypeStr == 'Home') return true;
      if (selectedTypeStr == 'Rental') {
        return property.type == 'Rental' || property.type == 'House';
      } else if (selectedTypeStr == 'Buy') {
        return property.type == 'Buy' || property.type == 'Sale' || property.type == 'Plot' || property.type == 'Land';
      } else {
        return property.type == 'PG' || property.type == 'Hostel';
      }
    }

    bool matchesSearch(PropertyModel p) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return p.title.toLowerCase().contains(q) || 
             p.locationStr.toLowerCase().contains(q);
    }

    final currentPos = _effectivePosition;
    if (currentPos == null) {
      return _allProperties.where((p) => matchesType(p) && matchesSearch(p)).toList();
    }

    int searchRadiusKm = 5;
    List<PropertyModel> tempFiltered = [];

    // Increment radius by 5km until we find properties or hit 50km limit
    while (searchRadiusKm <= 50) {
      tempFiltered = _allProperties.where((property) {
        if (!matchesType(property) || !matchesSearch(property)) return false;

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

    tempFiltered.sort((a, b) {
      if (_sortBy == 'distance') {
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
      } else if (_sortBy == 'price_asc') {
        return a.price.compareTo(b.price);
      } else if (_sortBy == 'price_desc') {
        return b.price.compareTo(a.price);
      }
      return 0; // relevance or fallback
    });

    _currentSearchRadiusKm = searchRadiusKm > 50 ? 50 : searchRadiusKm;
    return tempFiltered;
  }

  /// Get the scroll controller for the active tab
  ScrollController _controllerForType(String typeStr) {
    switch (typeStr) {
      case 'Home': return _homeScrollController;
      case 'PG': return _pgScrollController;
      case 'Buy': return _buyScrollController;
      default: return _rentalScrollController;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Yellow loading splash with centered location text
    if (_showSplash && _allProperties.isEmpty) {
      return Scaffold(
        body: _YellowSplashScreen(
          isLocating: _isSplashLocating,
          city: _currentCity,
          subtext: _currentArea,
          isDenied: !_hasLocationPermission,
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
                            CupertinoIcons.settings,
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
        backgroundColor: isDark ? AppTheme.darkScaffold : const Color(0xFFF2F2F7),
        extendBody: true,
        bottomNavigationBar: AnimatedSlide(
          duration: const Duration(milliseconds: 300),
          offset: _isScrollUIVisible ? Offset.zero : const Offset(0, 1),
          child: _buildSwiggyBottomNav(isDark),
        ),
        body: _bottomNavIndex == 1 
            ? _buildSavedPropertiesView(context, isDark)
            : _bottomNavIndex == 2
                ? _buildExploreMarketplaceView(context, isDark)
                : _bottomNavIndex == 3
                    ? PostingScreen(
                        currentLocation: _currentPosition,
                        onPropertyCreated: (newProp) {
                          _fetchProperties();
                          setState(() {
                            _bottomNavIndex = 0; // Go back to Home tab after posting
                          });
                        },
                      )
                    : Column(
                children: [
                  // ── Swiggy-style dark navy header ──
                  _buildSwiggyHeader(context),
            // ── Content ──
            Expanded(
              child: NotificationListener<UserScrollNotification>(
                onNotification: (notification) {
                  // Only listen to vertical scrolling (ignore PageView horizontal swipes)
                  if (notification.metrics.axis != Axis.vertical) return false;

                  if (notification.direction == ScrollDirection.reverse) {
                    // scrolling down
                    if (_isScrollUIVisible) setState(() => _isScrollUIVisible = false);
                  } else if (notification.direction == ScrollDirection.forward) {
                    // scrolling up
                    if (!_isScrollUIVisible) setState(() => _isScrollUIVisible = true);
                  }
                  return false;
                },
                child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  if (_selectedTypeIndex != index) {
                    setState(() { _selectedTypeIndex = index; });
                    AnalyticsService.instance.logCategoryClick(index == 0 ? 'Home' : index == 1 ? 'Hostel' : (index == 3 ? 'Buy' : 'Rental'));
                    HapticFeedback.selectionClick();
                  }
                },
                children: [
                  _buildTabContent('Home'),
                  _buildTabContent('PG'),
                  _buildTabContent('Rental'),
                  _buildTabContent('Buy'),
                ],
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExploreMarketplaceView(BuildContext context, bool isDark) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: const Color(0xFF0067FF),
          floating: true,
          pinned: true,
          elevation: 0,
          centerTitle: false,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(36),
            ),
          ),
          titleSpacing: 16,
          title: const Text(
            'Explore',
            style: TextStyle(
              fontFamily: 'DMSans',
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: BouncingButton(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings page coming soon!')),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(
                    Iconsax.setting_2,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(74),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Row(
                children: [
                  // Search bar
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(fontFamily: 'ProximaNova', 
                          fontSize: 14.5,
                          color: Colors.grey.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: "Search for '${_searchHints[_hintIndex]}'",
                          hintStyle: TextStyle(fontFamily: 'ProximaNova', 
                            fontSize: 16.5,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 8, right: 4),
                            child: Icon(
                              CupertinoIcons.search,
                              color: Colors.grey.shade600,
                              size: 24,
                            ),
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                height: 32,
                                width: 1.2,
                                color: Colors.grey.shade300,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: IconButton(
                                  icon: const Icon(
                                    CupertinoIcons.mic_fill,
                                    color: AppTheme.swiggyOrange,
                                    size: 26,
                                  ),
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                  },
                                ),
                              ),
                            ],
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // ── SORT button ──────────────────────────────
                  BouncingButton(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _showSortBottomSheet();
                    },
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'SORT',
                            style: TextStyle(fontFamily: 'ProximaNova', 
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.swiggyOrange,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Icon(
                            CupertinoIcons.sort_down,
                            size: 14,
                            color: AppTheme.swiggyGreen,
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
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 4),
                  child: Text(
                    'All Properties',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildPropertyList(_allProperties, 'Explore'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSavedPropertiesView(BuildContext context, bool isDark) {
    final savedProps = _allProperties.where(
      (p) => SavedPropertiesService.instance.isSaved(p.id ?? '')
    ).toList();

    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF0067FF),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(36),
              bottomRight: Radius.circular(36),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Saved Properties',
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  BouncingButton(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Settings page coming soon!')),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(
                        Iconsax.setting_2,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: savedProps.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.swiggyOrange.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.heart, size: 50, color: AppTheme.swiggyOrange),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No saved properties yet',
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the heart icon on properties\nto save them for later.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: savedProps.length,
                  itemBuilder: (context, index) {
                    final prop = savedProps[index];
                    return GridPropertyCard(
                      property: prop,
                      distanceInMeters: null,
                      onTap: () {
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
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTabContent(String typeStr) {
    final properties = _getSortedPropertiesForType(typeStr);
    String emptyLabel;
    if (typeStr == 'Home') {
      emptyLabel = 'Properties';
    } else if (typeStr == 'PG') {
      emptyLabel = 'Hostels / PGs';
    } else if (typeStr == 'Buy') {
      emptyLabel = 'Buy properties';
    } else {
      emptyLabel = 'Rentals';
    }

    final scrollCtrl = _controllerForType(typeStr);

    return RefreshIndicator(
      color: AppTheme.swiggyOrange,
      backgroundColor: Colors.white,
      displacement: 32,
      edgeOffset: 8,
      triggerMode: RefreshIndicatorTriggerMode.anywhere,
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('cached_properties_ts');
        final refreshFuture = Future.wait([
          _refreshLocationFast(updateFeed: true),
          _fetchProperties(),
        ]);
        await Future.wait([
          refreshFuture,
          Future.delayed(const Duration(seconds: 2)),
        ]);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            controller: scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 0.0,
              bottom: 24.0,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight > 140 ? constraints.maxHeight - 140 : 300,
              ),
              child: properties.isEmpty
                  ? Center(child: _buildEmptyState(emptyLabel))
                  : _buildPropertyList(properties, typeStr),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SWIGGY-STYLE DARK NAVY HEADER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSwiggyHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0067FF),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10), // 10px gap after status bar
            
            // ── Top row: location + settings button ─────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: !_isScrollUIVisible ? const SizedBox(width: double.infinity, height: 0) : Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Location area (tappable)
                  Expanded(
                    child: GestureDetector(
                      onTap: _showLocationOptionsSheet,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/Vector (1).png',
                            width: 24,
                            height: 24,
                            color: AppTheme.swiggyOrange,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _currentCity,
                                        style: TextStyle(fontFamily: 'ProximaNova', 
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          height: 1.1,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      CupertinoIcons.chevron_right,
                                      color: Colors.white70,
                                      size: 18,
                                    ),
                                  ],
                                ),
                                if (_currentArea.isNotEmpty)
                                  Text(
                                    _currentArea,
                                    style: TextStyle(fontFamily: 'ProximaNova', 
                                      fontSize: 12,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w400,
                                      height: 1.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Settings button ─────────────────────────────
                  BouncingButton(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsScreen()),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(
                        Iconsax.setting_2,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ),

            // ── Swiggy-style search bar row ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  // Search bar
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(fontFamily: 'ProximaNova', 
                          fontSize: 14.5,
                          color: Colors.grey.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: "Search for '${_searchHints[_hintIndex]}'",
                          hintStyle: TextStyle(fontFamily: 'ProximaNova', 
                            fontSize: 16.5,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 8, right: 4),
                            child: Icon(
                              CupertinoIcons.search,
                              color: Colors.grey.shade600,
                              size: 24,
                            ),
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                height: 32,
                                width: 1.2,
                                color: Colors.grey.shade300,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: IconButton(
                                  icon: Icon(
                                    CupertinoIcons.mic_fill,
                                    color: AppTheme.swiggyOrange,
                                    size: 26,
                                  ),
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                  },
                                ),
                              ),
                            ],
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // ── SORT button ──────────────────────────────
                  BouncingButton(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _showSortBottomSheet();
                    },
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'SORT',
                            style: TextStyle(fontFamily: 'ProximaNova', 
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.swiggyOrange,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Icon(
                            CupertinoIcons.sort_down,
                            size: 14,
                            color: AppTheme.swiggyGreen,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // ── Integrated Tabs inside Header ─────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: !_isScrollUIVisible 
                  ? const SizedBox(width: double.infinity, height: 0) 
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeaderTabBar(),
                        const SizedBox(height: 8), // added padding before the curve ends
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderTabBar() {
    final tabs = [
      (label: 'ALL', index: 0, icon: CupertinoIcons.square_grid_2x2),
      (label: 'HOSTELS', index: 1, icon: CupertinoIcons.building_2_fill),
      (label: 'RENTALS', index: 2, icon: CupertinoIcons.house_fill),
      (label: 'EXPLORE', index: 3, icon: CupertinoIcons.lock_fill),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(tabs.length * 2 - 1, (i) {
            if (i.isOdd) {
              return Container(
                height: 14,
                width: 1,
                color: Colors.white.withValues(alpha: 0.2),
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              );
            }
            final tabIndex = i ~/ 2;
            final tab = tabs[tabIndex];
            final isSelected = tab.index == _selectedTypeIndex;
            return GestureDetector(
              onTap: () {
                if (_selectedTypeIndex != tab.index) {
                  HapticFeedback.selectionClick();
                  setState(() { _selectedTypeIndex = tab.index; });
                  _pageController.animateToPage(
                    tab.index,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOutCubic,
                  );
                }
              },
              child: Container(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tab.icon, color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          tab.label,
                          style: TextStyle(fontFamily: 'ProximaNova', 
                            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Indicator
                    Container(
                      height: 3.5,
                      width: 50,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.transparent,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SWIGGY-STYLE WHITE BOTTOM NAVIGATION BAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSwiggyBottomNav(bool isDark) {
    final activeBgColor = isDark ? Colors.white.withValues(alpha: 0.1) : AppTheme.swiggyOrange.withValues(alpha: 0.1);
    final activeTextColor = isDark ? Colors.white : AppTheme.swiggyOrange;
    final inactiveIconColor = isDark ? Colors.grey.shade500 : Colors.grey.shade400;
    final bgColor = isDark ? AppTheme.darkScaffold : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : Colors.grey.shade200;

    final tabItems = [
      (label: 'Home', activeIcon: CupertinoIcons.house_fill, inactiveIcon: CupertinoIcons.house),
      (label: 'Saved', activeIcon: CupertinoIcons.heart_fill, inactiveIcon: CupertinoIcons.heart),
      (label: 'Explore', activeIcon: CupertinoIcons.bag_fill, inactiveIcon: CupertinoIcons.bag),
      (label: 'Sell', activeIcon: CupertinoIcons.tag_fill, inactiveIcon: CupertinoIcons.tag),
      (label: 'AI', activeIcon: CupertinoIcons.chat_bubble_text_fill, inactiveIcon: CupertinoIcons.chat_bubble_text),
    ];

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(tabItems.length, (index) {
              bool isSelected = false;
              if (_bottomNavIndex == 0) {
                if (index == 0) {
                  isSelected = _selectedTypeIndex == 0 || _selectedTypeIndex == 1 || _selectedTypeIndex == 2;
                } else if (index == 2) {
                  isSelected = _selectedTypeIndex == 3;
                }
              } else if (_bottomNavIndex == index) {
                isSelected = true;
              }

              final item = tabItems[index];

              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (index == 0) {
                    setState(() { _bottomNavIndex = 0; });
                    if (_selectedTypeIndex != 0) {
                      setState(() { _selectedTypeIndex = 0; });
                      if (_pageController.hasClients) {
                        _pageController.animateToPage(0, duration: const Duration(milliseconds: 280), curve: Curves.easeInOutCubic);
                      }
                    }
                  } else if (index == 1) {
                    setState(() { _bottomNavIndex = 1; });
                  } else if (index == 2) {
                    setState(() { _bottomNavIndex = 2; });
                  } else if (index == 3) {
                    setState(() { _bottomNavIndex = 3; });
                  } else if (index == 4) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AiChatScreen()),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? item.activeIcon : item.inactiveIcon,
                        size: 24,
                        color: isSelected ? activeTextColor : inactiveIconColor,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          color: isSelected ? activeTextColor : inactiveIconColor,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
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
            // Swiggy empty-state style illustration
            Lottie.asset(
              'assets/Nothing founded.json',
              width: 140,
              height: 140,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                CupertinoIcons.house,
                size: 60,
                color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Uh Oh! No $typeStr found',
              style: TextStyle(fontFamily: 'ProximaNova', 
                color: isDark ? Colors.white : AppTheme.lightTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'No properties within ${_currentSearchRadiusKm}km. Try a different location!',
              style: TextStyle(fontFamily: 'ProximaNova', 
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            BouncingButton(
              onTap: _showLocationOptionsSheet,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.swiggyOrange : AppTheme.lightTextPrimary,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Use another location',
                  style: TextStyle(fontFamily: 'ProximaNova', 
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
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

  Widget _buildPropertyList(List<PropertyModel> properties, String typeStr) {
    return GridView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.only(top: 16),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: properties.length,
      itemBuilder: (context, index) {
        final prop = properties[index];
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
        return GridPropertyCard(
          property: prop,
          distanceInMeters: distance,
          onTap: () {
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
              if (mounted) setState(() {});
            });
          },
        );
      },
    );
  }
  void _showSortBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    'Sort Results By',
                    style: TextStyle(fontFamily: 'ProximaNova', 
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSortOption('Relevance (Default)', 'relevance', CupertinoIcons.wand_stars, isDark),
                _buildSortOption('Distance (Closest First)', 'distance', CupertinoIcons.location_solid, isDark),
                _buildSortOption('Price: Low to High', 'price_asc', CupertinoIcons.chevron_up, isDark),
                _buildSortOption('Price: High to Low', 'price_desc', CupertinoIcons.chevron_down, isDark),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String title, String key, IconData icon, bool isDark) {
    final isSelected = _sortBy == key;
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: isSelected
          ? (isDark ? AppTheme.darkCardElevated : const Color(0xFFF1F5F9))
          : Colors.transparent,
      leading: Icon(
        icon,
        size: 18,
        color: isSelected
            ? AppTheme.primaryYellow
            : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
      ),
      title: Text(
        title,
        style: TextStyle(fontFamily: 'ProximaNova', 
          fontSize: 13.5,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected
              ? (isDark ? Colors.white : const Color(0xFF0F172A))
              : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569)),
        ),
      ),
      trailing: isSelected
          ? const Icon(CupertinoIcons.checkmark_alt, color: AppTheme.primaryYellow, size: 18)
          : null,
      onTap: () {
        setState(() => _sortBy = key);
        Navigator.pop(context);
        // Force re-fetch/re-sort of properties
        if (mounted) setState(() {});
      },
    );
  }
}

class GridPropertyCard extends StatelessWidget {
  final PropertyModel property;
  final double? distanceInMeters;
  final VoidCallback onTap;

  const GridPropertyCard({
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
    return BouncingButton(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            CachedNetworkImage(
              imageUrl: property.imageUrls.isNotEmpty ? property.imageUrls.first : '',
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey.shade300),
              errorWidget: (context, url, error) => Container(color: Colors.grey.shade300, child: const Icon(CupertinoIcons.house_fill, color: Colors.grey)),
            ),
            // Gradient Overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.25, 0.6, 1.0],
                    colors: [
                      Colors.black.withValues(alpha: 0.5),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'ProximaNova', 
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.swiggyOrange,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.swiggyOrange.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          property.price,
                          style: TextStyle(fontFamily: 'ProximaNova', 
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: SavedPropertiesService.instance,
                        builder: (context, child) {
                          final isSaved = SavedPropertiesService.instance.isSaved(property.id ?? '');
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              SavedPropertiesService.instance.toggleSave(property.id ?? '');
                            },
                            child: Icon(
                              isSaved ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                              color: isSaved ? AppTheme.swiggyOrange : Colors.white,
                              size: 20,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Top Left Badges (Distance)
            if (distanceInMeters != null)
              Positioned(
                top: 12,
                left: 12,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.location_solid, 
                      color: AppTheme.swiggyOrange, 
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDistance(distanceInMeters!),
                      style: const TextStyle(
                        fontFamily: 'ProximaNova',
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            // Top Right Badges (Type)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  property.type.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'ProximaNova',
                    color: Colors.black87,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : const Color(0xFFEEEEEE),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image with overlays ─────────────────────────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: property.imageUrls.isNotEmpty ? property.imageUrls.first : '',
                    height: 210,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    memCacheWidth: 800,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholder: (context, url) => Container(
                      height: 210,
                      color: isDark ? AppTheme.darkCardElevated : const Color(0xFFF0F0F0),
                      child: Center(
                        child: Icon(CupertinoIcons.photo, color: Colors.grey.shade400, size: 28),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 210,
                      color: isDark ? AppTheme.darkCardElevated : const Color(0xFFF0F0F0),
                      child: Center(
                        child: Icon(CupertinoIcons.photo, color: Colors.grey.shade400, size: 28),
                      ),
                    ),
                  ),
                ),

                // ── Discount / distance badge (bottom-left, Swiggy style) ──
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

                // ── Rating badge (top-left, Swiggy green) ──────────────────
                if (property.reviewCount > 0)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.swiggyGreen,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            property.averageRating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(CupertinoIcons.star_fill, color: Colors.white, size: 12),
                          Text(
                            ' (${property.reviewCount})',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Availability badge (top-right) ─────────────────────────
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: property.isAvailable
                          ? AppTheme.swiggyGreen
                          : AppTheme.swiggyRed,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      property.isAvailable ? 'Available' : 'Unavailable',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Card content (Swiggy restaurant list style) ────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location row (at the top now)
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.location_solid,
                        color: AppTheme.swiggyOrange,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          distanceInMeters != null
                              ? '${property.locationStr} • ${_formatDistance(distanceInMeters!)}'
                              : property.locationStr,
                          style: TextStyle(fontFamily: 'ProximaNova', 
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Title and Price row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: property.title),
                              const WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: SizedBox(width: 5),
                              ),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Icon(
                                  CupertinoIcons.check_mark_circled_solid,
                                  size: 15,
                                  color: AppTheme.swiggyOrange,
                                ),
                              ),
                            ],
                          ),
                          style: TextStyle(fontFamily: 'ProximaNova', 
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: isDark ? Colors.white : AppTheme.lightTextPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.swiggyOrange,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.swiggyOrange.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          property.price,
                          style: TextStyle(fontFamily: 'ProximaNova', 
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Tags row
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

                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    color: isDark ? AppTheme.darkBorder : const Color(0xFFF0F0F0),
                  ),
                  const SizedBox(height: 12),

                  // Bottom info row (Beds, Baths, Area)
                  if (property.type == 'PG')
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildBottomInfo(context, CupertinoIcons.moon_fill, property.beds),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14.0),
                            child: Container(height: 14, width: 1, color: isDark ? AppTheme.darkBorder : const Color(0xFFE0E0E0)),
                          ),
                          _buildBottomInfo(context, CupertinoIcons.drop_fill, property.baths),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14.0),
                            child: Container(height: 14, width: 1, color: isDark ? AppTheme.darkBorder : const Color(0xFFE0E0E0)),
                          ),
                          _buildBottomInfo(context, CupertinoIcons.fullscreen, property.area),
                        ],
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildBottomInfo(context, CupertinoIcons.moon_fill, property.beds),
                        Container(height: 14, width: 1, color: isDark ? AppTheme.darkBorder : const Color(0xFFE0E0E0)),
                        _buildBottomInfo(context, CupertinoIcons.drop_fill, property.baths),
                        Container(height: 14, width: 1, color: isDark ? AppTheme.darkBorder : const Color(0xFFE0E0E0)),
                        _buildBottomInfo(context, CupertinoIcons.fullscreen, property.area),
                      ],
                    ),

                  if (property.type == 'PG' &&
                     ((property.perDayWithFood != null && property.perDayWithFood!.isNotEmpty) ||
                      (property.perDayWithoutFood != null && property.perDayWithoutFood!.isNotEmpty)))
                    Column(
                      children: [
                        const SizedBox(height: 12),
                        Divider(height: 1, color: isDark ? AppTheme.darkBorder : const Color(0xFFF0F0F0)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (property.perDayWithFood != null && property.perDayWithFood!.isNotEmpty)
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(CupertinoIcons.calendar, color: Colors.grey.shade500, size: 15),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        '₹${property.perDayWithFood}/day with food',
                                        style: TextStyle(fontFamily: 'ProximaNova', 
                                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if ((property.perDayWithFood != null && property.perDayWithFood!.isNotEmpty) &&
                                (property.perDayWithoutFood != null && property.perDayWithoutFood!.isNotEmpty))
                              Container(height: 14, width: 1, color: isDark ? AppTheme.darkBorder : const Color(0xFFE0E0E0)),
                            if (property.perDayWithoutFood != null && property.perDayWithoutFood!.isNotEmpty)
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(CupertinoIcons.calendar, color: Colors.grey.shade500, size: 15),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        '₹${property.perDayWithoutFood}/day no food',
                                        style: TextStyle(fontFamily: 'ProximaNova', 
                                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardElevated : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFE8E8E8),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(fontFamily: 'ProximaNova', 
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
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
        Icon(icon, size: 15, color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF9E9E9E)),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(fontFamily: 'ProximaNova', 
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
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
                const Icon(CupertinoIcons.location_solid, color: Colors.black, size: 14.5),
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
                        CupertinoIcons.location_solid,
                        color: isDark ? Colors.white : Colors.black,
                        size: 24,
                      ),
                    ),
                  )
                : Icon(
                    CupertinoIcons.location_solid,
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





// ─────────────────────────────────────────────────────────────────────────────
// Yellow Splash Screen — shown while location is being fetched
// ─────────────────────────────────────────────────────────────────────────────
class _YellowSplashScreen extends StatefulWidget {
  final bool isLocating;
  final String? city;
  final String? subtext;
  final bool isDenied;
  const _YellowSplashScreen({
    super.key,
    required this.isLocating,
    this.city,
    this.subtext,
    this.isDenied = false,
  });

  @override
  State<_YellowSplashScreen> createState() => _YellowSplashScreenState();
}

class _YellowSplashScreenState extends State<_YellowSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _dotsController;
  late final AnimationController _cityFadeController;
  late final Animation<double> _cityFade;

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _cityFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cityFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cityFadeController, curve: Curves.easeIn),
    );

    if (!widget.isLocating) {
      _cityFadeController.forward();
    }
  }

  @override
  void didUpdateWidget(_YellowSplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLocating && !widget.isLocating) {
      _cityFadeController.forward();
    }
  }

  @override
  void dispose() {
    _dotsController.dispose();
    _cityFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFD600),
              Color(0xFFFFCA00),
              Color(0xFFFFB800),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    CupertinoIcons.location_north_fill,
                    color: Color(0xFF1A1A1A),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 24),
                if (widget.isLocating)
                  _buildLocatingText()
                else
                  FadeTransition(
                    opacity: _cityFade,
                    child: Column(
                      children: [
                        Text(
                          widget.isDenied
                              ? 'Location Access'
                              : (widget.city ?? 'Your Location'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.isDenied
                              ? 'Enable location for better results'
                              : (widget.subtext ?? ''),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF1A1A1A).withValues(alpha: 0.65),
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocatingText() {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Locating',
              style: TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 2),
            ...List.generate(3, (i) {
              final delay = i * 0.33;
              final opacity = (((_dotsController.value - delay) % 1.0).abs() < 0.5) ? 1.0 : 0.3;
              return Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Opacity(
                  opacity: opacity.clamp(0.3, 1.0),
                  child: const Text(
                    '.',
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
