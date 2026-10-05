import 'package:rental/features/home/presentation/widgets/yellow_splash_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rental/features/home/presentation/widgets/filter_bottom_sheet.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rental/features/settings/presentation/pages/settings_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:iconsax/iconsax.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental/core/widgets/app_snackbar.dart';
import 'package:rental/core/widgets/bouncing_button.dart';
import 'package:rental/core/widgets/rental_app_icon.dart';
import 'package:rental/features/property_posting/presentation/pages/posting_screen.dart';
import 'package:rental/features/property_details/presentation/pages/property_details_screen.dart';
import 'package:rental/features/search/presentation/widgets/location_picker_sheet.dart';
import 'package:rental/features/search/presentation/pages/search_screen.dart';
import 'package:rental/features/search/presentation/pages/unified_search_screen.dart';
import 'package:rental/features/ai_chat/presentation/pages/ai_chat_screen.dart';
import 'package:rental/features/saved_properties/presentation/pages/saved_properties_screen.dart';
import 'package:rental/features/saved_properties/data/datasources/saved_properties_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/app/theme/theme_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rental/core/services/analytics_service.dart';
import 'package:rental/features/transport/data/datasources/transport_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:rental/core/models/property_model.dart';
import 'package:rental/features/home/presentation/widgets/yellow_splash_screen.dart';
import 'package:rental/features/home/presentation/widgets/grid_property_card.dart';
import 'package:rental/features/home/presentation/widgets/yellow_splash_screen.dart';
import 'package:rental/features/home/presentation/widgets/property_card.dart';
import 'package:rental/features/home/presentation/widgets/yellow_splash_screen.dart';
import 'package:rental/features/home/presentation/widgets/skeleton_property_card.dart';
import 'package:rental/features/home/presentation/widgets/yellow_splash_screen.dart';
import 'package:rental/features/home/presentation/widgets/card_bottom_strip.dart';
import 'package:rental/features/home/presentation/widgets/yellow_splash_screen.dart';
import 'package:rental/features/home/presentation/widgets/shimmer_effect.dart';
import 'package:rental/features/home/presentation/widgets/yellow_splash_screen.dart';
import 'package:rental/features/home/presentation/widgets/skeleton_box.dart';
import 'package:rental/features/home/presentation/widgets/yellow_splash_screen.dart';
import 'package:rental/features/home/presentation/widgets/top_location_logo_switcher.dart';
import 'package:rental/features/home/presentation/widgets/yellow_splash_screen.dart';
import 'package:rental/features/home/presentation/widgets/yellow_splash_screen.dart';
import 'package:rental/features/home/presentation/widgets/yellow_splash_screen.dart';
import 'package:rental/features/search/presentation/pages/voice_search_screen.dart';

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
  return decoded
      .map((e) => PropertyModel.fromJson(e as Map<String, dynamic>))
      .toList();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedTypeIndex = 0; // 0 for PG / Hostel, 1 for Rental
  int _bottomNavIndex = 0; // 0 for Home, 1 for Saved, etc.
  PropertyModel? _selectedMapProperty;
  final MapController _mapController = MapController();
  late final PageController _pageController;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  FilterState _filterState = const FilterState();
  
  Timer? _searchDebounce;
  List<dynamic> _locationSuggestions = [];
  bool _isSearchingLocations = false;

  // Scroll position memory: one controller per tab
  final ScrollController _homeScrollController = ScrollController();
  final ScrollController _pgScrollController = ScrollController();
  final ScrollController _rentalScrollController = ScrollController();
  final ScrollController _buyScrollController = ScrollController();

  Position? _currentPosition;
  late String _currentCity =
      widget.initialLocationCity ?? 'Finding location...';
  late String _currentArea =
      widget.initialLocationSubtext ?? 'Detecting your area...';
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

  Position? get _effectivePosition =>
      _manualLocationOverride ?? _currentPosition;
  String _mapFilter = 'All';
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
    _searchFocusNode.addListener(() { if (mounted) setState(() {}); });

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
      targetId =
          Uri.base.queryParameters['propertyId'] ??
          Uri.base.queryParameters['id'];
    }

    if (targetId != null && targetId.isNotEmpty) {
      _hasOpenedInitialProperty = true;
      try {
        PropertyModel? found;
        try {
          found = _allProperties.firstWhere((p) => p.id == targetId);
        } catch (_) {}

        if (found == null) {
          final res = await _supabase
              .from('properties')
              .select()
              .eq('id', targetId)
              .maybeSingle();
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
          _currentArea = '';
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
      _currentArea = '';
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
              Icon(
                CupertinoIcons.location_solid,
                size: 48,
                color: isDark ? AppTheme.primaryYellow : Colors.black,
              ),
              SizedBox(height: 16),
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
                  SizedBox(width: 16),
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
    _locationStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            distanceFilter: 15, // metres — only fires on real movement
          ),
        ).listen(
          (position) {
            if (!mounted) return;
            _currentPosition = position;
            if (_manualLocationOverride == null) {
              _updateGeocodingIfNeeded(position);
              if (mounted) setState(() {}); // Re-sort feed
            }
          },
          onError: (_) {
            // Stream errors are non-fatal — fall back to single fetch
            _refreshLocationFast(updateFeed: false);
          },
        );

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
      final isCacheFresh =
          cachedTs != null &&
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
      await prefs.setInt(
        'cached_properties_ts',
        DateTime.now().millisecondsSinceEpoch,
      );
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
          AppSnackbar.error(
            context,
            'Offline mode: Showing cached properties.',
          );
        } else {
          AppSnackbar.error(
            context,
            'Failed to load properties. Check connection.',
          );
        }
      }
    }
  }

  void _precachePropertyImages(List<PropertyModel> properties) {
    if (!mounted) return;
    for (final prop in properties.take(5)) {
      if (prop.imageUrls.isNotEmpty) {
        final firstUrl = prop.imageUrls.first;
        if (firstUrl.startsWith('http')) {
          try {
            precacheImage(
              CachedNetworkImageProvider(firstUrl),
              context,
            );
          } catch (_) {}
        }
      }
    }
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
        if (mounted)
          setState(() {
            _hasLocationPermission = false;
            _isRefreshingLocation = false;
          });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (mounted)
            setState(() {
              _hasLocationPermission = false;
              _isRefreshingLocation = false;
            });
          return;
        }
      }

      if (mounted)
        setState(() {
          _hasLocationPermission = true;
        });

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
        setState(() {
          _isRefreshingLocation = false;
        });
      } else {
        _isRefreshingLocation = false;
      }
    }
  }



  /// Geocoding throttle: only call the network geocoding API when user moves
  /// more than 500 meters from the last geocoded position, unless forced.
  Future<void> _updateGeocodingIfNeeded(
    Position position, {
    bool force = false,
  }) async {
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
              place.locality ??
              place.subLocality ??
              place.name ??
              'Finding location...';
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

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val;
    });
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (val.trim().isNotEmpty) {
        _fetchLocationSuggestions(val);
      } else {
        if (mounted) setState(() { _locationSuggestions = []; });
      }
    });
  }

  Future<void> _fetchLocationSuggestions(String query) async {
    setState(() { _isSearchingLocations = true; });
    try {
      final url = Uri.parse('https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&limit=5');
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'RentalApp/1.0.0 (contact@rental.arkio.in)',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'] != null) {
          if (mounted) setState(() { _locationSuggestions = List.from(data['features']); });
        }
      }
    } catch (_) {}
    if (mounted) setState(() { _isSearchingLocations = false; });
  }

  List<PropertyModel> _getSortedPropertiesForType(String selectedTypeStr) {
    bool matchesType(PropertyModel property) {
      if (selectedTypeStr == 'Home') return true;
      if (selectedTypeStr == 'Rental') {
        return property.type == 'Rental' || property.type == 'House';
      } else if (selectedTypeStr == 'Buy') {
        return property.type == 'Buy' ||
            property.type == 'Sale' ||
            property.type == 'Plot' ||
            property.type == 'Land';
      } else {
        return property.type == 'PG' || property.type == 'Hostel';
      }
    }

    bool matchesSearch(PropertyModel p) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return p.title.toLowerCase().contains(q) ||
          p.locationStr.toLowerCase().contains(q) ||
          (p.description != null && p.description!.toLowerCase().contains(q)) ||
          p.type.toLowerCase().contains(q) ||
          p.tags.join(' ').toLowerCase().contains(q) ||
          p.features.join(' ').toLowerCase().contains(q);
    }

    bool matchesFilters(PropertyModel p) {
      double parsedPrice = double.tryParse(p.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      if (parsedPrice < _filterState.minBudget || parsedPrice > _filterState.maxBudget) return false;
      if (_filterState.propertyTypes.isNotEmpty) {
        if (!_filterState.propertyTypes.contains(p.type)) return false;
      }
      if (_filterState.furnishing.isNotEmpty) {
        bool match = false;
        String pFurnish = p.furnishingStatus ?? '';
        for (final f in _filterState.furnishing) {
          if (pFurnish.toLowerCase().contains(f.toLowerCase())) match = true;
        }
        if (!match) return false;
      }
      if (_filterState.occupancy.isNotEmpty) {
        bool match = false;
        for (final o in _filterState.occupancy) {
          if (p.tags.any((tag) => tag.toLowerCase().contains(o.toLowerCase()))) match = true;
        }
        if (!match) return false;
      }
      return true;
    }

    final currentPos = _effectivePosition;
    if (currentPos == null) {
      return _allProperties
          .where((p) => matchesType(p) && matchesSearch(p) && matchesFilters(p))
          .toList();
    }

    int searchRadiusKm = 5;
    List<PropertyModel> tempFiltered = [];

    // Increment radius by 5km until we find properties or hit 50km limit
    while (searchRadiusKm <= 50) {
      tempFiltered = _allProperties.where((property) {
        if (!matchesType(property) || !matchesSearch(property) || !matchesFilters(property)) return false;

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
      if (_filterState.sortBy == 'distance') {
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
      } else if (_filterState.sortBy == 'price_asc' || _filterState.sortBy == 'price_desc') {
        double priceA = double.tryParse(a.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        double priceB = double.tryParse(b.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        if (_filterState.sortBy == 'price_asc') {
          return priceA.compareTo(priceB);
        } else {
          return priceB.compareTo(priceA);
        }
      }
      return 0; // relevance or fallback
    });

    _currentSearchRadiusKm = searchRadiusKm > 50 ? 50 : searchRadiusKm;
    return tempFiltered;
  }

  /// Get the scroll controller for the active tab
  ScrollController _controllerForType(String typeStr) {
    switch (typeStr) {
      case 'Home':
        return _homeScrollController;
      case 'PG':
        return _pgScrollController;
      case 'Buy':
        return _buyScrollController;
      default:
        return _rentalScrollController;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Yellow loading splash with centered location text
    if (_showSplash && _allProperties.isEmpty) {
      return Scaffold(
        body: YellowSplashScreen(
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
                        ? const ColorFilter.matrix([
                            -1,
                            0,
                            0,
                            0,
                            255,
                            0,
                            -1,
                            0,
                            0,
                            255,
                            0,
                            0,
                            -1,
                            0,
                            255,
                            0,
                            0,
                            0,
                            1,
                            0,
                          ])
                        : const ColorFilter.mode(
                            Colors.transparent,
                            BlendMode.dst,
                          ),
                    child: Lottie.asset(
                      'assets/animations/location.json',
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
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : Colors.black54,
                      fontSize: 15,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 32),
                  BouncingButton(
                    onTap: () {
                      Geolocator.openAppSettings();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
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
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // If search overlay is active, close it
        if (_searchFocusNode.hasFocus || _searchQuery.isNotEmpty) {
          _searchFocusNode.unfocus();
          setState(() {
            _searchQuery = '';
            _searchController.clear();
          });
          return;
        }

        // If on another tab, return to home tab
        if (_bottomNavIndex != 0) {
          setState(() {
            _bottomNavIndex = 0;
          });
          return;
        }

        // Double-back-to-exit
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!).inSeconds < 2) {
          SystemNavigator.pop();
          return;
        }
        _lastBackPress = now;
        AppSnackbar.error(context, 'Press back again to exit');
      },
      child: Scaffold(
        backgroundColor: isDark
            ? AppTheme.darkScaffold
            : const Color(0xFFF2F2F7),
        extendBody: true,
        bottomNavigationBar: AnimatedSlide(
          duration: const Duration(milliseconds: 300),
          offset: (_isScrollUIVisible && !(_searchFocusNode.hasFocus || _searchQuery.isNotEmpty)) ? Offset.zero : const Offset(0, 1),
          child: _buildBottomNav(isDark),
        ),
        body: IndexedStack(
          index: _bottomNavIndex == 4 ? 0 : _bottomNavIndex,
          children: [
            Column(
                children: [
                  // ── Swiggy-style dark navy header ──
                  _buildSwiggyHeader(context),
                  // ── Content ──
                  if (_searchFocusNode.hasFocus || _searchQuery.isNotEmpty)
                    Expanded(
                      child: _buildSearchResults(),
                    )
                  else
                    Expanded(
                      child: NotificationListener<UserScrollNotification>(
                      onNotification: (notification) {
                        // Only listen to vertical scrolling (ignore PageView horizontal swipes)
                        if (notification.metrics.axis != Axis.vertical)
                          return false;

                        if (notification.direction == ScrollDirection.reverse) {
                          // scrolling down
                          if (_isScrollUIVisible)
                            setState(() => _isScrollUIVisible = false);
                        } else if (notification.direction ==
                            ScrollDirection.forward) {
                          // scrolling up
                          if (!_isScrollUIVisible)
                            setState(() => _isScrollUIVisible = true);
                        }
                        return false;
                      },
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) {
                          if (_selectedTypeIndex != index) {
                            setState(() {
                              _selectedTypeIndex = index;
                            });
                            AnalyticsService.instance.logCategoryClick(
                              index == 0
                                  ? 'Home'
                                  : index == 1
                                  ? 'Hostel'
                                  : (index == 3 ? 'Buy' : 'Rental'),
                            );
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
            _buildExploreMarketplaceView(context, isDark),
            PostingScreen(
              allProperties: _allProperties,
              currentLocation: _currentPosition,
              onPropertyCreated: (newProp) {
                _fetchProperties();
                setState(() {
                  _bottomNavIndex = 0;
                });
              },
            ),
            _buildFullMapView(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildExploreMarketplaceView(BuildContext context, bool isDark) {
    final headerBgColor = _isScrollUIVisible ? AppTheme.primaryAccent : (isDark ? AppTheme.darkScaffold : Colors.white);
    final isBgDark = ThemeData.estimateBrightnessForColor(headerBgColor) == Brightness.dark;
    final headerTextColor = isBgDark ? Colors.white : Colors.black87;

    final query = _searchQuery.trim().toLowerCase();
    final displayedProperties = query.isEmpty
        ? _allProperties
        : _allProperties.where((p) {
            final titleMatch = p.title.toLowerCase().contains(query);
            final locMatch = p.locationStr.toLowerCase().contains(query);
            final typeMatch = p.type.toLowerCase().contains(query);
            return titleMatch || locMatch || typeMatch;
          }).toList();

    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical) return false;
        if (notification.direction == ScrollDirection.reverse) {
          if (_isScrollUIVisible) setState(() => _isScrollUIVisible = false);
        } else if (notification.direction == ScrollDirection.forward) {
          if (!_isScrollUIVisible) setState(() => _isScrollUIVisible = true);
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: headerBgColor,
            floating: true,
            pinned: true,
            elevation: 0,
            centerTitle: false,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
            ),
          titleSpacing: 24,
          title: Text(
            'Explore',
            style: TextStyle(
              fontFamily: 'ProximaNova',
              color: headerTextColor,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          actions: [
            BouncingButton(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      backgroundColor: isDark ? AppTheme.darkScaffold : const Color(0xFFF2F2F7),
                      body: _buildSavedPropertiesView(context, isDark, showBackButton: true),
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2.0, 8.0, 14.0, 8.0),
                child: Icon(
                  CupertinoIcons.heart,
                  color: headerTextColor,
                  size: 24,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: BouncingButton(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 8.0),
                  child: Icon(
                    Iconsax.setting_2,
                    color: headerTextColor,
                    size: 24,
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
                        borderRadius: BorderRadius.circular(
                          _searchFocusNode.hasFocus || _searchQuery.isNotEmpty ? 30 : 12,
                        ),
                        border: _isScrollUIVisible ? null : Border.all(color: Colors.grey.shade300),
                        boxShadow: _searchFocusNode.hasFocus || _searchQuery.isNotEmpty
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryYellow.withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: TextField(
                        controller: _searchController,
                        readOnly: true,
                        textAlignVertical: TextAlignVertical.center,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => const UnifiedSearchScreen(),
                            ),
                          );
                        },
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 14.5,
                          color: Colors.grey.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: "Search for '${_searchHints[_hintIndex]}'",
                          hintStyle: TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 14.0,
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
                              size: 20,
                            ),
                          ),
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: IconButton(
                              icon: Icon(
                                _searchQuery.isNotEmpty
                                    ? CupertinoIcons.clear
                                    : CupertinoIcons.mic_fill,
                                color: Colors.black87,
                                size: 20,
                              ),
                              onPressed: _searchQuery.isNotEmpty
                                  ? () {
                                      HapticFeedback.selectionClick();
                                      _searchController.clear();
                                      _searchFocusNode.unfocus();
                                      setState(() {
                                        _searchQuery = '';
                                        _locationSuggestions = [];
                                      });
                                    }
                                  : () async {
                                      HapticFeedback.selectionClick();
                                      final result = await Navigator.push<String>(
                                        context,
                                        PageRouteBuilder(
                                          pageBuilder: (context, animation, secondaryAnimation) =>
                                              const VoiceSearchScreen(),
                                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                            const begin = Offset(0.0, 1.0);
                                            const end = Offset.zero;
                                            final tween = Tween(begin: begin, end: end)
                                                .chain(CurveTween(curve: Curves.ease));
                                            return SlideTransition(
                                                position: animation.drive(tween), child: child);
                                          },
                                        ),
                                      );
                                      if (result != null && result.isNotEmpty) {
                                        _searchController.text = result;
                                        _onSearchChanged(result);
                                      }
                                    },
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
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
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: _isScrollUIVisible ? null : Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('SORT',
                                style: TextStyle(
                                  fontFamily: 'ProximaNova',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Icon(CupertinoIcons.sort_down,
                                size: 14,
                                color: Colors.black87,
                              ),
                            ],
                          ),
                        ),
                        if (_filterState.activeFilterCount > 0)
                          Positioned(
                            top: -8,
                            right: -8,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Text(
                                '${_filterState.activeFilterCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 16,
                    bottom: 4,
                  ),
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
                  child: _buildPropertyList(displayedProperties, 'Explore'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildSavedPropertiesView(BuildContext context, bool isDark, {bool showBackButton = false}) {
    final isAppBarDark = ThemeData.estimateBrightnessForColor(_isScrollUIVisible ? AppTheme.primaryAccent : (isDark ? AppTheme.darkScaffold : Colors.white)) == Brightness.dark;
    final appBarTextColor = isAppBarDark ? Colors.white : Colors.black87;
    final savedProps = _allProperties
        .where((p) => SavedPropertiesService.instance.isSaved(p.id ?? ''))
        .toList();

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          decoration: BoxDecoration(
            color: _isScrollUIVisible ? AppTheme.primaryAccent : (isDark ? AppTheme.darkScaffold : Colors.white),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(36),
              bottomRight: Radius.circular(36),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (showBackButton)
                        BouncingButton(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.pop(context);
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: Icon(
                              CupertinoIcons.back,
                              color: appBarTextColor,
                            ),
                          ),
                        ),
                      Text(
                        'Saved Properties',
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          color: appBarTextColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axis != Axis.vertical) return false;
              if (notification.direction == ScrollDirection.reverse) {
                if (_isScrollUIVisible) setState(() => _isScrollUIVisible = false);
              } else if (notification.direction == ScrollDirection.forward) {
                if (!_isScrollUIVisible) setState(() => _isScrollUIVisible = true);
              }
              return false;
            },
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
                        child: Icon(
                          CupertinoIcons.heart,
                          size: 50,
                          color: AppTheme.swiggyOrange,
                        ),
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
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 100,
                  ),
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
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isSearchingLocations) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryYellow),
      );
    }

    if (_searchQuery.trim().isEmpty) {
      return Center(
        child: Text(
          'Type to search for locations or properties...',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
        ),
      );
    }

    final localMatches = _allProperties.where((p) {
      final q = _searchQuery.toLowerCase();
      return p.title.toLowerCase().contains(q) ||
          p.locationStr.toLowerCase().contains(q) ||
          (p.description?.toLowerCase().contains(q) ?? false) ||
          p.type.toLowerCase().contains(q) ||
          p.tags.join(' ').toLowerCase().contains(q) ||
          p.features.join(' ').toLowerCase().contains(q);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_locationSuggestions.isNotEmpty) ...[
          Text('Places / Villages', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 8),
          ..._locationSuggestions.map((feature) {
            final props = feature['properties'];
            final name = props['name'] ?? 'Unknown location';
            final state = props['state'] ?? '';
            final country = props['country'] ?? '';
            final subtitle = [state, country].where((e) => e.toString().isNotEmpty).join(', ');

            return ListTile(
              leading: Icon(Iconsax.location),
              title: Text(name, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              subtitle: subtitle.isNotEmpty ? Text(subtitle, style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)) : null,
              onTap: () async {
                _searchFocusNode.unfocus();
                
                final coords = feature['geometry']['coordinates'];
                final lon = (coords[0] as num).toDouble();
                final lat = (coords[1] as num).toDouble();
                final newPos = Position(
                  latitude: lat,
                  longitude: lon,
                  timestamp: DateTime.now(),
                  accuracy: 1,
                  altitude: 0,
                  heading: 0,
                  speed: 0,
                  speedAccuracy: 0,
                  altitudeAccuracy: 0,
                  headingAccuracy: 0,
                );

                _manualLocationOverride = newPos;
                _searchQuery = '';
                _searchController.clear();
                
                setState(() {});
                await _updateGeocodingIfNeeded(newPos, force: true);
                _fetchProperties();

                if (_bottomNavIndex == 3) {
                  _mapController.move(LatLng(lat, lon), 14.0);
                }
              },
            );
          }),
          const SizedBox(height: 8),
        ],

        if (localMatches.isNotEmpty) ...[
          Text('Properties', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 12),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: localMatches.length,
            itemBuilder: (context, index) {
              final prop = localMatches[index];
              return GridPropertyCard(
                property: prop,
                distanceInMeters: null,
                onTap: () {
                  _searchFocusNode.unfocus();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PropertyDetailsScreen(property: prop),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),
        ],

        if (localMatches.isEmpty && _locationSuggestions.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40.0),
              child: Text(
                'No results found for "$_searchQuery"',
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
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
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 0.0,
              bottom: 24.0,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight > 140
                    ? constraints.maxHeight - 140
                    : 300,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSearchActive = _searchFocusNode.hasFocus || _searchQuery.isNotEmpty;
    
    final headerBgColor = (_isScrollUIVisible && !isSearchActive) ? AppTheme.primaryAccent : (isDark ? AppTheme.darkScaffold : Colors.white);
    final isBgDark = ThemeData.estimateBrightnessForColor(headerBgColor) == Brightness.dark;
    final headerTextColor = isBgDark ? Colors.white : Colors.black87;
    final headerSubTextColor = isBgDark ? Colors.white70 : Colors.black54;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: headerBgColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(isSearchActive ? 0 : 36),
          bottomRight: Radius.circular(isSearchActive ? 0 : 36),
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
              child: (!_isScrollUIVisible || isSearchActive)
                  ? const SizedBox(width: double.infinity, height: 0)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 16, 20),
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
                                    'assets/icons/logowhite.png',
                                    width: 22,
                                    height: 22,color: headerTextColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                _currentCity.split(',').first,
                                                style: TextStyle(
                                                  fontFamily: 'ProximaNova',
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                  color: headerTextColor,
                                                  height: 1.1,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              CupertinoIcons.chevron_right,color: headerSubTextColor,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                        if (_currentArea.isNotEmpty)
                                          Text(
                                            _currentArea,
                                            style: TextStyle(
                                              fontFamily: 'ProximaNova',
                                              fontSize: 12,
                                              color: headerSubTextColor,
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

                          // ── Saved Properties button ─────────────────────────────
                          BouncingButton(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => Scaffold(
                                    backgroundColor: isDark ? AppTheme.darkScaffold : const Color(0xFFF2F2F7),
                                    body: _buildSavedPropertiesView(context, isDark, showBackButton: true),
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(2.0, 8.0, 14.0, 8.0),
                              child: Icon(
                                CupertinoIcons.heart,
                                color: headerTextColor,
                                size: 24,
                              ),
                            ),
                          ),
                          // ── Settings button ─────────────────────────────
                          BouncingButton(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SettingsScreen(),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 8.0),
                              child: Icon(
                                Iconsax.setting_2,
                                color: headerTextColor,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // ── Swiggy-style search bar row ──────────────────────────────────
            Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 25),
                  child: Row(
                    children: [
                      if (isSearchActive)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: IconButton(
                            icon: Icon(
                              CupertinoIcons.back, // iOS style back button
                              color: headerTextColor,
                              size: 24,
                            ),
                            onPressed: () {
                              _searchFocusNode.unfocus();
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _locationSuggestions = [];
                              });
                            },
                          ),
                        ),
                      // Search bar
                  Expanded(
                    key: const ValueKey('home_search_expanded'),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(isSearchActive ? 30 : 12),
                        border: (_isScrollUIVisible && !isSearchActive) ? null : Border.all(color: Colors.grey.shade300),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: TextField(
                        controller: _searchController,
                        readOnly: true,
                        textAlignVertical: TextAlignVertical.center,
                        cursorColor: Colors.black87,
                        cursorWidth: 2.0,
                        cursorHeight: 20.0,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => const UnifiedSearchScreen(),
                            ),
                          );
                        },
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 15.5,
                          color: Colors.grey.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: "Search for '${_searchHints[_hintIndex]}'",
                          hintStyle: TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 15.0,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: isSearchActive 
                              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
                              : const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          prefixIcon: isSearchActive ? null : Padding(
                            padding: const EdgeInsets.only(left: 8, right: 4),
                            child: Icon(
                              CupertinoIcons.search,
                              color: Colors.grey.shade600,
                              size: 20, // Decreased size
                            ),
                          ),
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: IconButton(
                              icon: Icon(
                                _searchQuery.isNotEmpty
                                    ? CupertinoIcons.clear
                                    : CupertinoIcons.mic_fill,
                                color: Colors.black87,
                                size: 20, // Decreased size
                              ),
                              onPressed: _searchQuery.isNotEmpty 
                                  ? () {
                                      HapticFeedback.selectionClick();
                                      _searchController.clear();
                                      _searchFocusNode.unfocus(); // Close overlay when clearing
                                      setState(() {
                                        _searchQuery = '';
                                        _locationSuggestions = [];
                                      });
                                    } 
                                  : () async {
                                      HapticFeedback.selectionClick();
                                      final result = await Navigator.push<String>(
                                        context,
                                        PageRouteBuilder(
                                          pageBuilder: (context, animation, secondaryAnimation) => const VoiceSearchScreen(),
                                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                            const begin = Offset(0.0, 1.0);
                                            const end = Offset.zero;
                                            const curve = Curves.ease;
                                            final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                            return SlideTransition(position: animation.drive(tween), child: child);
                                          },
                                        ),
                                      );
                                      if (result != null && result.isNotEmpty) {
                                        setState(() {
                                          _searchController.text = result;
                                          _searchQuery = result;
                                        });
                                      }
                                    },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (!isSearchActive) ...[
                    const SizedBox(width: 10),

                    // ── SORT button ──────────────────────────────
                    BouncingButton(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _showSortBottomSheet();
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            height: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: (_isScrollUIVisible && !isSearchActive) ? null : Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'SORT',
                                  style: TextStyle(
                                    fontFamily: 'ProximaNova',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Icon(
                                  CupertinoIcons.sort_down,
                                  size: 12, // Decreased size
                                  color: Colors.black87,
                                ),
                              ],
                            ),
                          ),
                          if (_filterState.activeFilterCount > 0)
                            Positioned(
                              top: -8,
                              right: -8,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: Text(
                                  '${_filterState.activeFilterCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),

        // ── Integrated Tabs inside Header ─────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: (!_isScrollUIVisible || isSearchActive)
                  ? const SizedBox(width: double.infinity, height: 0)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeaderTabBar(headerTextColor, headerSubTextColor),
                        const SizedBox(
                          height: 8,
                        ), // added padding before the curve ends
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderTabBar(Color textColor, Color subTextColor) {
    final tabs = [
      (label: 'ALL', index: 0, icon: CupertinoIcons.square_grid_2x2),
      (label: 'HOSTELS', index: 1, icon: Iconsax.building),
      (label: 'RENTALS', index: 2, icon: CupertinoIcons.house),
      (label: 'BUY', index: 3, icon: CupertinoIcons.bag),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 4),
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
                color: subTextColor.withValues(alpha: 0.3),
                margin: const EdgeInsets.only(
                  left: 14,
                  right: 14,
                  bottom: 6,
                ),
              );
            }
            final tabIndex = i ~/ 2;
            final tab = tabs[tabIndex];
            final isSelected = tab.index == _selectedTypeIndex;
            return GestureDetector(
              onTap: () {
                if (_selectedTypeIndex != tab.index) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedTypeIndex = tab.index;
                  });
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
                        Icon(
                          tab.icon,
                          color: textColor,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontFamily: 'ProximaNova',
                            color: textColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Indicator
                    Container(
                      height: 3.5,
                      width: 50,
                      decoration: BoxDecoration(
                        color: isSelected ? textColor : Colors.transparent,
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
  Widget _buildMapLegendItem(String label, Color color, bool isPg, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardElevated : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: isPg ? Colors.black : Colors.white, width: 1.5),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullMapView(BuildContext context, bool isDark) {
    final isAppBarDark = ThemeData.estimateBrightnessForColor(AppTheme.primaryAccent) == Brightness.dark;
    final appBarTextColor = isAppBarDark ? Colors.white : Colors.black87;
    if (_allProperties.isEmpty) {
      return Center(child: Text("No properties to map", style: TextStyle(color: isDark ? Colors.white : Colors.black)));
    }
    final mapProperties = _allProperties.where((prop) {
      if (_mapFilter == 'All') return true;
      final lowerType = prop.type.toLowerCase();
      final isPg = lowerType.contains('pg') || lowerType.contains('hostel');
      final isBuy = lowerType.contains('buy') || lowerType.contains('sale') || lowerType.contains('plot') || lowerType.contains('land');
      if (_mapFilter == 'PG') return isPg;
      if (_mapFilter == 'Buy') return isBuy;
      if (_mapFilter == 'Rental') return !isPg && !isBuy;
      return true;
    }).toList();
    final centerLat = _effectivePosition != null ? _effectivePosition!.latitude : (mapProperties.isNotEmpty ? mapProperties.first.latitude : 0.0);
    final centerLng = _effectivePosition != null ? _effectivePosition!.longitude : (mapProperties.isNotEmpty ? mapProperties.first.longitude : 0.0);

    final isSearchActive = _searchFocusNode.hasFocus || _searchQuery.isNotEmpty;
    final appBar = Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryAccent,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row with Title and Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 16, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Find in Map',
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      color: appBarTextColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  Row(
                    children: [
                      BouncingButton(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Scaffold(
                                backgroundColor: isDark ? AppTheme.darkScaffold : const Color(0xFFF2F2F7),
                                body: _buildSavedPropertiesView(context, isDark, showBackButton: true),
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(2.0, 8.0, 14.0, 8.0),
                          child: Icon(
                            CupertinoIcons.heart,
                            color: appBarTextColor,
                            size: 24,
                          ),
                        ),
                      ),
                      BouncingButton(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsScreen(),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 8.0),
                          child: Icon(
                            Iconsax.setting_2,
                            color: appBarTextColor,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 25),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: TextField(
                  controller: _searchController,
                  readOnly: true,
                  textAlignVertical: TextAlignVertical.center,
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    final result = await Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => const UnifiedSearchScreen(),
                      ),
                    );

                    if (result != null && result is Position) {
                      _manualLocationOverride = result;
                      _searchQuery = '';
                      _searchController.clear();
                      
                      setState(() {});
                      await _updateGeocodingIfNeeded(result, force: true);
                      _fetchProperties();

                      if (_bottomNavIndex == 3) {
                        _mapController.move(LatLng(result.latitude, result.longitude), 14.0);
                      }
                    }
                  },
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 14.5,
                    color: Colors.grey.shade900,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: "Search for '${_searchHints[_hintIndex]}'",
                    hintStyle: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 14.0,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        icon: Icon(
                          _searchQuery.isNotEmpty
                              ? CupertinoIcons.clear
                              : CupertinoIcons.mic_fill,
                          color: Colors.black87,
                          size: 20,
                        ),
                        onPressed: _searchQuery.isNotEmpty
                            ? () {
                                HapticFeedback.selectionClick();
                                _searchController.clear();
                                _searchFocusNode.unfocus();
                                setState(() {
                                  _searchQuery = '';
                                  _locationSuggestions = [];
                                });
                              }
                            : () async {
                                HapticFeedback.selectionClick();
                                final result = await Navigator.push<String>(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation, secondaryAnimation) =>
                                        const VoiceSearchScreen(),
                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                      const begin = Offset(0.0, 1.0);
                                      const end = Offset.zero;
                                      final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.ease));
                                      return SlideTransition(position: animation.drive(tween), child: child);
                                    },
                                  ),
                                );
                                if (result != null && result.isNotEmpty) {
                                  _searchController.text = result;
                                  _onSearchChanged(result);
                                }
                              },
                      ),
                    ),

                  ),
                ),
              ),
            ),
            
            // Map Filters inside AppBar
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    if (i.isOdd) {
                      return Container(
                        height: 14,
                        width: 1,
                        color: appBarTextColor.withOpacity(0.3),
                        margin: const EdgeInsets.only(
                          left: 14,
                          right: 14,
                          bottom: 6,
                        ),
                      );
                    }
                    final index = i ~/ 2;
                    final filters = ['All', 'PG', 'Rental', 'Buy'];
                    final filter = filters[index];
                    final isSelected = _mapFilter == filter;
                    final textColor = appBarTextColor;
                    final subTextColor = appBarTextColor.withOpacity(0.6);
                    
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _mapFilter = filter;
                          _selectedMapProperty = null; // hide detail card on filter change
                        });
                      },
                      child: Container(
                        color: Colors.transparent,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (filter == 'All')
                                  Icon(
                                    CupertinoIcons.square_grid_2x2,
                                    size: 16,
                                    color: isSelected ? textColor : subTextColor,
                                  )
                                else
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.rectangle,
                                      borderRadius: BorderRadius.circular(2),
                                      color: filter == 'PG' 
                                        ? const Color(0xFFFFD600) 
                                        : (filter == 'Buy' ? const Color(0xFF4CAF50) : const Color(0xFF42A5F5)),
                                      border: Border.all(
                                        color: isDark ? Colors.black87 : Colors.black87, 
                                        width: 1.2,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 6),
                                Text(
                                  filter == 'All' ? 'ALL' : (filter == 'PG' ? 'HOSTELS' : (filter == 'Rental' ? 'RENTALS' : 'BUY')),
                                  style: TextStyle(
                                    fontFamily: 'ProximaNova',
                                    fontSize: 12.5,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? textColor : subTextColor,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 3.5,
                              width: 50,
                              decoration: BoxDecoration(
                                color: isSelected ? textColor : Colors.transparent,
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
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    return Stack(
      children: [
        // Map
        Positioned.fill(
          child: Stack(
            children: [

              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(centerLat, centerLng),
                  initialZoom: 13.0,
                  onTap: (pos, latlng) {
                    setState(() {
                      _selectedMapProperty = null;
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                    userAgentPackageName: 'com.arkiolabs.rental',
                    maxNativeZoom: 21,
                    maxZoom: 22.0,
                  ),
                  MarkerLayer(
                    markers: [
                      ...mapProperties.map((prop) {
                      final isSelected = _selectedMapProperty?.id == prop.id;
                      final String lowerType = prop.type.toLowerCase();
                      final bool isPg = lowerType.contains('pg') || lowerType.contains('hostel');
                      
                      Color baseColor = AppTheme.primaryYellow;
                      if (isPg) {
                        baseColor = const Color(0xFFFFD600); // Primary color for PGs
                      } else if (lowerType.contains('buy') || lowerType.contains('sale') || lowerType.contains('plot') || lowerType.contains('land')) {
                        baseColor = const Color(0xFF4CAF50); // Green for Buy/Sell
                      } else {
                        baseColor = const Color(0xFF42A5F5); // Blue for Rental/House
                      }
                      
                      Color unselectedAccent = isPg ? Colors.black : Colors.white;

                      return Marker(
                        point: LatLng(prop.latitude, prop.longitude),
                        width: isSelected ? 48 : 40,
                        height: isSelected ? 48 : 40,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedMapProperty = prop;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.black : baseColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: isSelected ? baseColor : unselectedAccent, width: isSelected ? 3 : 2),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                )
                              ] : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                )
                              ],
                            ),
                            child: Icon(
                              CupertinoIcons.house_fill,
                              color: isSelected ? baseColor : unselectedAccent,
                              size: isSelected ? 24 : 20,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    if (_currentPosition != null)
                      Marker(
                        point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(color: Colors.blue.withOpacity(0.5), blurRadius: 10, spreadRadius: 4),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),

              Positioned(
                right: 16,
                bottom: _selectedMapProperty != null ? 300 : 120, // Sit above bottom nav bar or card
                child: BouncingButton(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (_currentPosition != null) {
                      _mapController.move(
                        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                        14.0,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCard : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.my_location,
                      color: isDark ? Colors.white : Colors.black87,
                      size: 24,
                    ),
                  ),
                ),
              ),
              if (_selectedMapProperty != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 120, // Sit above bottom nav bar
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Image with badges
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: SizedBox(
                                height: 160,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl: _selectedMapProperty!.imageUrls.isNotEmpty ? _selectedMapProperty!.imageUrls.first : 'https://via.placeholder.com/400',
                                      fit: BoxFit.cover,
                                    ),
                                    Positioned(
                                      top: 12,
                                      left: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.75),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          _selectedMapProperty!.type,
                                          style: TextStyle(
                                            color: AppTheme.primaryYellow,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 12,
                                      right: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryYellow,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '₹${_selectedMapProperty!.price}/m',
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Details
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _selectedMapProperty!.title,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? Colors.white : Colors.black,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.verified, color: Colors.black, size: 20),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on, color: Colors.grey.shade600, size: 16),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          _selectedMapProperty!.locationStr,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  BouncingButton(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PropertyDetailsScreen(property: _selectedMapProperty!),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryYellow,
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          Icon(Icons.visibility, color: Colors.black, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            'View Details',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Close Button
                      Positioned(
                        top: -12,
                        right: -12,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedMapProperty = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.close, size: 20, color: Colors.black),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: appBar,
        ),
      ],
    );
  }

  Widget _buildBottomNav(bool isDark) {
    final activeBgColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);
    final activeTextColor = isDark ? Colors.white : Colors.black87;
    final inactiveIconColor = isDark
        ? Colors.grey.shade500
        : Colors.grey.shade400;
    final bgColor = isDark ? AppTheme.darkScaffold : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : Colors.grey.shade200;

    final tabItems = [
      (
        label: 'Home',
        activeIcon: CupertinoIcons.house_fill,
        inactiveIcon: CupertinoIcons.house,
      ),
      (
        label: 'Explore',
        activeIcon: CupertinoIcons.search,
        inactiveIcon: CupertinoIcons.search,
      ),
      (
        label: 'Post',
        activeIcon: CupertinoIcons.add_circled_solid,
        inactiveIcon: CupertinoIcons.add_circled,
      ),
      (
        label: 'Map',
        activeIcon: CupertinoIcons.map_fill,
        inactiveIcon: CupertinoIcons.map,
      ),
      (
        label: 'AI',
        activeIcon: CupertinoIcons.chat_bubble_text_fill,
        inactiveIcon: CupertinoIcons.chat_bubble_text,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
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
                  isSelected =
                      _selectedTypeIndex == 0 ||
                      _selectedTypeIndex == 1 ||
                      _selectedTypeIndex == 2;
                } else if (index == 1) {
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
                    setState(() {
                      _bottomNavIndex = 0;
                    });
                    if (_selectedTypeIndex != 0) {
                      setState(() {
                        _selectedTypeIndex = 0;
                      });
                      if (_pageController.hasClients) {
                        _pageController.animateToPage(
                          0,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOutCubic,
                        );
                      }
                    }
                  } else if (index == 1) {
                    setState(() {
                      _bottomNavIndex = 1;
                    });
                  } else if (index == 2) {
                    setState(() {
                      _bottomNavIndex = 2;
                    });
                  } else if (index == 3) {
                    setState(() {
                      _bottomNavIndex = 3;
                    });
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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
                          color: isSelected
                              ? activeTextColor
                              : inactiveIconColor,
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
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
              'assets/animations/not_found.json',
              width: 280,
              height: 280,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                CupertinoIcons.house,
                size: 60,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Uh Oh! No $typeStr found',
              style: TextStyle(
                fontFamily: 'ProximaNova',
                color: isDark ? Colors.white : AppTheme.lightTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty 
                  ? "We couldn't find anything for '$_searchQuery' in this area."
                  : 'No properties within ${_currentSearchRadiusKm}km. Try a different location!',
              style: TextStyle(
                fontFamily: 'ProximaNova',
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            BouncingButton(
              onTap: _searchQuery.isNotEmpty 
                  ? () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    }
                  : _showLocationOptionsSheet,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.swiggyOrange
                      : AppTheme.lightTextPrimary,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  _searchQuery.isNotEmpty ? 'Clear Search' : 'Use another location',
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    color: isDark 
                        ? (ThemeData.estimateBrightnessForColor(AppTheme.swiggyOrange) == Brightness.dark ? Colors.white : Colors.black87) 
                        : Colors.white,
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
    final currentPos =
        _effectivePosition ??
        Position(
          latitude: 17.3850,
          longitude: 78.4867, // Default to Hyderabad
          timestamp: DateTime.now(),
          accuracy: 1,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterBottomSheet(
        initialState: _filterState,
        onApply: (newState) {
          setState(() {
            _filterState = newState;
          });
        },
      ),
    );
  }
}

// ==========================================
// SKELETON LOADING WIDGETS
// ==========================================

// ─────────────────────────────────────────────────────────────────────────────
// Yellow Splash Screen — shown while location is being fetched
// ─────────────────────────────────────────────────────────────────────────────
