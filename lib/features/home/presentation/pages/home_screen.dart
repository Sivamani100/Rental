import 'package:rental/features/home/presentation/widgets/yellow_splash_screen.dart';
import 'package:rental/core/services/deep_link_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rental/features/home/presentation/widgets/filter_bottom_sheet.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rental/core/ads/in_feed_ad_card.dart';
import 'package:rental/core/ads/ad_config.dart';
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
import 'package:rental/features/amenities/data/datasources/amenity_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:rental/core/models/property_model.dart';
import 'package:rental/features/partner/data/models/partner_promotion_model.dart';
import 'package:rental/features/home/presentation/widgets/yellow_splash_screen.dart';
import 'package:rental/features/home/presentation/widgets/grid_property_card.dart';
import 'package:rental/features/home/presentation/widgets/yellow_splash_screen.dart';
import 'package:rental/features/home/presentation/widgets/property_card.dart';
import 'package:rental/core/services/network_status_service.dart';
import 'package:rental/features/home/presentation/widgets/yellow_splash_screen.dart';
import 'package:rental/features/home/presentation/widgets/skeleton_property_card.dart';
import 'package:rental/features/home/presentation/widgets/yellow_splash_screen.dart';
import 'package:rental/features/home/presentation/widgets/card_bottom_strip.dart';
import 'package:rental/features/home/presentation/widgets/yellow_splash_screen.dart';
import 'package:rental/features/home/presentation/widgets/shimmer_effect.dart';
import 'package:rental/features/home/presentation/widgets/skeleton_box.dart';
import 'package:rental/features/home/presentation/widgets/top_location_logo_switcher.dart';
import 'package:rental/features/search/presentation/pages/voice_search_screen.dart';
import 'package:rental/core/services/location_helper.dart';
import 'package:rental/features/search/presentation/widgets/new_search_bar.dart';
import 'package:rental/features/search/presentation/pages/new_search_screen.dart';

class HomeScreen extends StatefulWidget {
  final String? initialPropertyId;

  final String? initialLocationCity;
  final String? initialLocationSubtext;
  final Position? initialPosition;

  const HomeScreen({
    super.key,
    this.initialPropertyId,
    this.initialLocationCity,
    this.initialLocationSubtext,
    this.initialPosition,
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
  DateTime? _lastExploreTabTap;
  DateTime? _lastSearchOpenTime;
  PropertyModel? _selectedMapProperty;
  final MapController _mapController = MapController();
  late final PageController _pageController;
  int _exploreCategoryIndex = 0;
  late final PageController _explorePageController;

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

  final ScrollController _exploreHomeScrollController = ScrollController();
  final ScrollController _explorePgScrollController = ScrollController();
  final ScrollController _exploreRentalScrollController = ScrollController();
  final ScrollController _exploreBuyScrollController = ScrollController();

  static final Position _defaultFallbackPosition = Position(
    latitude: 17.0440,
    longitude: 81.8430,
    timestamp: DateTime.now(),
    accuracy: 10,
    altitude: 0,
    heading: 0,
    speed: 0,
    speedAccuracy: 0,
    altitudeAccuracy: 0,
    headingAccuracy: 0,
  );
  static const String _defaultCity = 'Diwancheruvu';
  static const String _defaultArea = 'Rajahmundry, India';

  Position? _currentPosition;
  late String _currentCity =
      widget.initialLocationCity ?? _defaultCity;
  late String _currentArea =
      widget.initialLocationSubtext ?? _defaultArea;
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

  Position get _effectivePosition =>
      _manualLocationOverride ?? _currentPosition ?? _defaultFallbackPosition;
  String _mapFilter = 'All';
  List<PropertyModel> _allProperties = [];
  Map<String, PartnerPromotionModel> _activePromotions = {};
  int _currentSearchRadiusKm = 0;

  final _supabase = Supabase.instance.client;
  // Replaced 1-second Timer with distance-filtered position stream
  StreamSubscription<Position>? _locationStream;
  RealtimeChannel? _propertiesChannel;
  bool _isRefreshingLocation = false;

  // Geocoding throttle — only re-geocode when user moves >500m
  Position? _lastGeocodedPosition;

  // Cache version guard — bump this whenever PropertyModel.fromJson schema changes
  static const int _cacheVersion = 3;

  // Double-back-to-exit support
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _currentPosition = widget.initialPosition;
    }
    _pageController = PageController(initialPage: _selectedTypeIndex);
    _explorePageController = PageController(initialPage: _exploreCategoryIndex);
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

    // Deep link handling is now done by onGenerateRoute in main.dart
    // No need to handle it here to avoid duplicate navigation and blank screen
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

      if (_currentPosition == null) {
        final cachedLat = prefs.getDouble('cached_lat');
        final cachedLng = prefs.getDouble('cached_lng');
        if (cachedLat != null && cachedLng != null) {
          _currentPosition = Position(
            latitude: cachedLat,
            longitude: cachedLng,
            timestamp: DateTime.now(),
            accuracy: 10,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
        }
      }

      final cachedCity = prefs.getString('cached_city');
      final cachedArea = prefs.getString('cached_area');
      if (mounted) {
        if (cachedCity != null && cachedCity.isNotEmpty && widget.initialLocationCity == null) {
          _currentCity = cachedCity;
        }
        if (cachedArea != null && cachedArea.isNotEmpty && widget.initialLocationSubtext == null) {
          _currentArea = cachedArea;
        }
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
        }
      } else if (mounted) {
        // No cache — keep loading spinner until first network result arrives
        // (will be dismissed in _fetchProperties)
      }
    } catch (_) {}
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

  /// Supabase realtime: auto-refresh feed and promotions when admin approves promotions or properties.
  void _subscribeToRealtimeUpdates() {
    try {
      _propertiesChannel = _supabase
          .channel('home-properties-feed')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'properties',
            callback: (payload) {
              _fetchProperties(forceRefresh: true);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'property_promotions',
            callback: (payload) {
              _fetchActivePromotions();
              _fetchProperties(forceRefresh: true);
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
    _explorePageController.dispose();
    _homeScrollController.dispose();
    _pgScrollController.dispose();
    _rentalScrollController.dispose();
    _buyScrollController.dispose();
    _exploreHomeScrollController.dispose();
    _explorePgScrollController.dispose();
    _exploreRentalScrollController.dispose();
    _exploreBuyScrollController.dispose();
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
      _fetchActivePromotions();
      _fetchProperties();
    } else if (state == AppLifecycleState.paused) {
      _locationStream?.cancel();
    }
  }

  /// Fetches active approved in-app promotions independently from cache
  Future<void> _fetchActivePromotions() async {
    try {
      final promoRows = await _supabase
          .from('property_promotions')
          .select()
          .or('status.eq.approved,status.eq.active');
      final Map<String, PartnerPromotionModel> promoMap = {};
      for (var row in (promoRows as List)) {
        final promo = PartnerPromotionModel.fromJson(Map<String, dynamic>.from(row));
        if (promo.isActive && promo.propertyId.isNotEmpty) {
          promoMap[promo.propertyId] = promo;
        }
      }
      if (mounted) {
        setState(() {
          _activePromotions = promoMap;
        });
      }
    } catch (pe) {
      debugPrint('Note fetching promotions in home: $pe');
    }
  }

  Future<void> _fetchProperties({bool forceRefresh = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Always fetch latest promotions independently so active promotions are immediately updated
      _fetchActivePromotions();

      // Cache freshness check — skip network if cache is <5 minutes old and not forceRefresh
      final cachedTs = prefs.getInt('cached_properties_ts');
      final isCacheFresh =
          cachedTs != null &&
          (DateTime.now().millisecondsSinceEpoch - cachedTs) < 5 * 60 * 1000;

      if (!forceRefresh && isCacheFresh && _allProperties.isNotEmpty) {
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
        NetworkStatusService.instance.reportSuccess();
        _precachePropertyImages(freshList);
      }
    } catch (e) {
      NetworkStatusService.instance.reportFailure();
      if (mounted) {
        // Dismiss loading spinner even on failure so UI doesn't stay stuck
        if (_isInitialLoading) setState(() => _isInitialLoading = false);
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
        if (mounted) {
          setState(() {
            _hasLocationPermission = false;
            _isRefreshingLocation = false;
            if (_manualLocationOverride == null && _currentPosition == null) {
              _currentPosition = _defaultFallbackPosition;
              if (_currentCity.isEmpty) _currentCity = _defaultCity;
              if (_currentArea.isEmpty) _currentArea = _defaultArea;
            }
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _hasLocationPermission = false;
            _isRefreshingLocation = false;
            if (_manualLocationOverride == null && _currentPosition == null) {
              _currentPosition = _defaultFallbackPosition;
              if (_currentCity.isEmpty) _currentCity = _defaultCity;
              if (_currentArea.isEmpty) _currentArea = _defaultArea;
            }
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _hasLocationPermission = true;
        });
      }

      Position? position;
      try {
        final cachedLastPos = await Geolocator.getLastKnownPosition();
        if (cachedLastPos != null && mounted) {
          _currentPosition = cachedLastPos;
          if (_manualLocationOverride == null) {
            _updateGeocodingIfNeeded(cachedLastPos);
            setState(() {});
          }
        }
      } catch (_) {}

      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 4),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        if (mounted && _manualLocationOverride == null && _currentPosition == null) {
          setState(() {
            _currentPosition = _defaultFallbackPosition;
            if (_currentCity.isEmpty) _currentCity = _defaultCity;
            if (_currentArea.isEmpty) _currentArea = _defaultArea;
          });
        }
        return;
      }

      if (!mounted) return;
      _currentPosition = position;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('cached_lat', position.latitude);
        await prefs.setDouble('cached_lng', position.longitude);
      } catch (_) {}

      if (_manualLocationOverride == null) {
        if (mounted) setState(() {});
        await _updateGeocodingIfNeeded(position, force: true);
      }
    } catch (_) {
      if (mounted && _manualLocationOverride == null && _currentPosition == null) {
        setState(() {
          _currentPosition = _defaultFallbackPosition;
          if (_currentCity.isEmpty) _currentCity = _defaultCity;
          if (_currentArea.isEmpty) _currentArea = _defaultArea;
        });
      }
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
      final geo = await LocationHelper.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        setState(() {
          _currentCity = geo['city'] ?? _currentCity;
          _currentArea = geo['area'] ?? _currentArea;
        });

        // Persist for instant display on next app open
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_city', _currentCity);
          await prefs.setString('cached_area', _currentArea);
        } catch (_) {}
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

  Future<void> _openUnifiedSearch({String? initialQuery}) async {
    final now = DateTime.now();
    if (_lastSearchOpenTime != null &&
        now.difference(_lastSearchOpenTime!).inMilliseconds < 250) {
      return;
    }
    _lastSearchOpenTime = now;
    HapticFeedback.selectionClick();
    try {
      final result = await Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          barrierDismissible: true,
          barrierColor: Colors.black.withValues(alpha: 0.42),
          pageBuilder: (context, anim, secAnim) => NewSearchScreen(
            initialProperties: _allProperties,
            initialQuery: initialQuery,
            currentPosition: _effectivePosition,
          ),
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 240),
          transitionsBuilder: (context, anim, secAnim, child) {
            final curved = CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -1.0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            );
          },
        ),
      );

      if (!mounted) return;

      if (result != null) {
        Position? selectedPos;
        String? cityName;
        String? areaName;

        if (result is Position) {
          selectedPos = result;
        } else if (result is Map) {
          selectedPos = result['position'] as Position?;
          cityName = result['city'] as String?;
          areaName = result['area'] as String?;
        }

        if (selectedPos != null || (cityName != null && cityName.isNotEmpty)) {
          if (selectedPos != null) {
            _manualLocationOverride = selectedPos;
          }
          if (cityName != null && cityName.isNotEmpty) {
            _currentCity = cityName;
            _currentArea = areaName ?? 'Andhra Pradesh, India';
          }
          _searchQuery = '';
          _searchController.clear();
          _bottomNavIndex = 0; // Directly reach the Home page of the app
          setState(() {});

          if (selectedPos != null) {
            if (cityName == null) {
              await _updateGeocodingIfNeeded(selectedPos, force: true);
            }
            if (_bottomNavIndex == 3) {
              _mapController.move(
                LatLng(selectedPos.latitude, selectedPos.longitude),
                14.0,
              );
            }
          }
          _fetchProperties(forceRefresh: true);
        }
      }
    } catch (e) {
      debugPrint('Error navigating to UnifiedSearchScreen: $e');
    }
  }

  Future<void> _openVoiceSearch() async {
    HapticFeedback.selectionClick();
    final result = await VoiceSearchScreen.open(
      context,
      properties: _allProperties,
    );
    if (result != null && result.trim().isNotEmpty) {
      _lastSearchOpenTime = null;
      _openUnifiedSearch(initialQuery: result.trim());
    }
  }

  List<PropertyModel> _getSortedPropertiesForType(String selectedTypeStr) {
    bool matchesType(PropertyModel property) {
      final t = property.type.toLowerCase().trim();
      final title = property.title.toLowerCase();
      final tagsStr = property.tags.join(' ').toLowerCase();

      final bool isPgOrHostel = t == 'pg' ||
          t == 'hostel' ||
          t == 'hostels' ||
          t.contains('pg') ||
          t.contains('hostel') ||
          t.contains('paying guest') ||
          t.contains('coliving') ||
          t.contains('co-living') ||
          title.contains('hostel') ||
          title.contains(' pg') ||
          title.startsWith('pg ') ||
          title.contains('pg/') ||
          title.contains('/pg') ||
          title.contains('co living') ||
          title.contains('coliving') ||
          title.contains('guest house') ||
          title.contains('dormitory') ||
          tagsStr.contains('hostel') ||
          tagsStr.contains('pg ') ||
          tagsStr.contains('boys only') ||
          tagsStr.contains('girls only') ||
          (property.sharingType != null && property.sharingType!.isNotEmpty);

      if (selectedTypeStr == 'Home') return true;

      if (selectedTypeStr == 'PG') {
        return isPgOrHostel;
      }

      if (selectedTypeStr == 'Rental') {
        if (isPgOrHostel) return false;
        return t == 'rental' ||
            t == 'house' ||
            t.contains('rent') ||
            t.contains('apartment') ||
            t.contains('flat') ||
            title.contains('rent') ||
            title.contains('flat') ||
            title.contains('bhk');
      }

      if (selectedTypeStr == 'Buy') {
        if (isPgOrHostel) return false;
        return t == 'buy' ||
            t == 'sale' ||
            t == 'plot' ||
            t == 'land' ||
            t.contains('buy') ||
            t.contains('sale') ||
            title.contains('buy') ||
            title.contains('sale') ||
            title.contains('plot') ||
            title.contains('land');
      }

      return true;
    }

    bool matchesSearch(PropertyModel p) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase().trim();

      // If user typed/selected a category term corresponding to this tab, match all properties of this tab
      if (q == 'hostel' || q == 'hostels' || q == 'pg' || q == 'hostel & pg' || q == 'hostels & pg') {
        if (selectedTypeStr == 'PG') return true;
        final t = p.type.toLowerCase();
        final title = p.title.toLowerCase();
        return t.contains('pg') || t.contains('hostel') || title.contains('pg') || title.contains('hostel');
      }

      if (q == 'rent' || q == 'rentals' || q == 'rental') {
        if (selectedTypeStr == 'Rental') return true;
      }

      if (q == 'buy' || q == 'sale' || q == 'plots') {
        if (selectedTypeStr == 'Buy') return true;
      }

      final title = p.title.toLowerCase();
      final loc = p.locationStr.toLowerCase();
      final desc = (p.description ?? '').toLowerCase();
      final type = p.type.toLowerCase();
      final tags = p.tags.join(' ').toLowerCase();
      final feat = p.features.join(' ').toLowerCase();
      final combined = '$title $loc $desc $type $tags $feat';

      if (combined.contains(q)) return true;

      // Handle multi-word searches (e.g. "hostels in Diwancheruvu")
      final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty && w != 'in' && w != 'near' && w != '&').toList();
      if (words.isNotEmpty) {
        return words.every((w) {
          if (w == 'hostels' || w == 'hostel' || w == 'pg') {
            return type.contains('pg') || type.contains('hostel') || title.contains('pg') || title.contains('hostel') || tags.contains('hostel') || tags.contains('pg');
          }
          return combined.contains(w);
        });
      }

      return false;
    }

    bool matchesFilters(PropertyModel p) {
      double parsedPrice = double.tryParse(p.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      // Only filter by budget if the property has a price > 0, so "To be updated" listings are preserved
      if (parsedPrice > 0) {
        if (parsedPrice < _filterState.minBudget || parsedPrice > _filterState.maxBudget) return false;
      }

      // 1. Category / Property Type match:
      // When the user has already navigated to a specific tab (PG, Rental, Buy),
      // that tab takes precedence over any stale propertyTypes filter from another tab.
      if (selectedTypeStr == 'Home' && _filterState.propertyTypes.isNotEmpty) {
        bool typeMatch = false;
        final pType = p.type.toLowerCase();
        for (final t in _filterState.propertyTypes) {
          final tLower = t.toLowerCase();
          if (tLower == 'rental') {
            if (pType == 'rental' || pType == 'house') typeMatch = true;
          } else if (tLower == 'pg') {
            if (pType == 'pg' || pType == 'hostel') typeMatch = true;
          } else if (tLower == 'buy') {
            if (pType == 'buy' || pType == 'sale' || pType == 'plot' || pType == 'land') typeMatch = true;
          } else {
            if (pType == tLower) typeMatch = true;
          }
        }
        if (!typeMatch) return false;
      }

      // 2. Buy Property Sub-type match (Only applicable to Buy properties)
      if (selectedTypeStr == 'Buy' || selectedTypeStr == 'Home') {
        if (_filterState.buyPropertyTypes.isNotEmpty) {
          bool match = false;
          final pType = p.type.toLowerCase();
          final text = '${p.title} ${p.description ?? ''} ${p.tags.join(' ')}'.toLowerCase();
          for (final bpt in _filterState.buyPropertyTypes) {
            final bptLower = bpt.toLowerCase();
            if (bptLower.contains('plot') || bptLower.contains('land')) {
              if (pType.contains('plot') || pType.contains('land') || text.contains('plot') || text.contains('land')) match = true;
            } else if (bptLower.contains('flat') || bptLower.contains('apartment')) {
              if (text.contains('flat') || text.contains('apartment') || text.contains('bhk')) match = true;
            } else if (bptLower.contains('villa') || bptLower.contains('house')) {
              if (pType.contains('house') || text.contains('villa') || text.contains('independent')) match = true;
            } else if (bptLower.contains('commercial')) {
              if (text.contains('commercial') || text.contains('shop') || text.contains('office')) match = true;
            }
          }
          if (!match) return false;
        }

        // 3. Construction Status match
        if (_filterState.constructionStatus.isNotEmpty) {
          bool match = false;
          final desc = '${p.description ?? ''} ${p.tags.join(' ')}'.toLowerCase();
          for (final cs in _filterState.constructionStatus) {
            if (desc.contains(cs.toLowerCase())) match = true;
          }
          if (!match) return false;
        }
      }

      // 4. Furnishing & BHK Type match (Only applicable to Rental properties)
      if (selectedTypeStr == 'Rental' || selectedTypeStr == 'Home') {
        if (_filterState.furnishing.isNotEmpty) {
          bool match = false;
          String pFurnish = (p.furnishingStatus ?? '').toLowerCase();
          for (final f in _filterState.furnishing) {
            if (pFurnish.contains(f.toLowerCase())) match = true;
          }
          if (!match) return false;
        }

        if (_filterState.bhkTypes.isNotEmpty) {
          if (p.bhkType != null) {
            bool match = false;
            String bhk = p.bhkType!.toLowerCase();
            for (final b in _filterState.bhkTypes) {
              final bClean = b.toLowerCase().split('/').first.trim();
              if (bhk.contains(bClean) || p.tags.any((t) => t.toLowerCase().contains(bClean))) match = true;
            }
            if (!match) return false;
          } else {
            return false;
          }
        }
      }

      // 8. Gender preference match
      if (_filterState.genderPreference.isNotEmpty) {
        String gender = (p.genderPreference ?? '').toLowerCase();
        String tagsStr = p.tags.join(' ').toLowerCase();
        bool match = false;
        for (final g in _filterState.genderPreference) {
          final gLower = g.toLowerCase().replaceAll('only', '').trim();
          if (gender.contains(gLower) || tagsStr.contains(gLower) || gender.contains('unisex') || gender.contains('co-living')) match = true;
        }
        if (!match) return false;
      }

      // 9. Tenant preference match
      if (_filterState.tenants.isNotEmpty) {
        String tenant = (p.tenantPreference ?? '').toLowerCase();
        bool match = false;
        for (final t in _filterState.tenants) {
          final tLower = t.toLowerCase().split('/').first.trim();
          if (tenant.contains(tLower) || tenant.contains('anyone') || tenant.contains('all')) match = true;
        }
        if (!match) return false;
      }

      // 10. Food preference match
      if (_filterState.foodPreferences.isNotEmpty) {
        final foodInfo = '${p.foodDetails ?? ''} ${p.foodQuality ?? ''} ${p.tags.join(' ')} ${p.features.join(' ')} ${p.description ?? ''}'.toLowerCase();
        bool match = false;
        for (final fp in _filterState.foodPreferences) {
          final fpLower = fp.toLowerCase();
          if (fpLower.contains('with food')) {
            if (foodInfo.contains('food') || foodInfo.contains('meals') || (p.perDayWithFood != null && p.perDayWithFood!.isNotEmpty)) match = true;
          } else if (fpLower.contains('without food') || fpLower.contains('self cooking')) {
            if (foodInfo.contains('without food') || foodInfo.contains('self cooking') || foodInfo.contains('self-cooking') || (p.perDayWithoutFood != null && p.perDayWithoutFood!.isNotEmpty)) match = true;
          } else if (foodInfo.contains(fpLower.replaceAll('included', '').replaceAll('allowed', '').trim())) {
            match = true;
          }
        }
        if (!match) return false;
      }

      // 11. Room / AC / Facilities match
      if (_filterState.roomTypes.isNotEmpty) {
        final roomInfo = '${p.acType ?? ''} ${p.bathroomType ?? ''} ${p.tags.join(' ')} ${p.features.join(' ')} ${p.description ?? ''}'.toLowerCase();
        bool match = false;
        for (final rt in _filterState.roomTypes) {
          final rtLower = rt.toLowerCase();
          if (rtLower.contains('ac room') || rtLower == 'ac') {
            if (roomInfo.contains('ac') && !roomInfo.contains('non-ac')) match = true;
          } else if (rtLower.contains('non-ac')) {
            if (roomInfo.contains('non-ac') || !roomInfo.contains('ac')) match = true;
          } else if (rtLower.contains('attached')) {
            if (roomInfo.contains('attached')) match = true;
          } else if (rtLower.contains('common')) {
            if (roomInfo.contains('common')) match = true;
          }
        }
        if (!match) return false;
      }

      // 12. Parking match
      if (_filterState.parking.isNotEmpty) {
        final parkInfo = '${p.parkingInfo ?? ''} ${p.features.join(' ')} ${p.description ?? ''}'.toLowerCase();
        bool match = false;
        for (final pk in _filterState.parking) {
          final pkLower = pk.toLowerCase();
          if (pkLower.contains('car') && parkInfo.contains('car')) match = true;
          else if (pkLower.contains('bike') && (parkInfo.contains('bike') || parkInfo.contains('two wheeler'))) match = true;
          else if (pkLower.contains('covered') && parkInfo.contains('covered')) match = true;
          else if (parkInfo.contains('parking')) match = true;
        }
        if (!match) return false;
      }

      // 13. Curfew / Rules match
      if (_filterState.rules.isNotEmpty) {
        final rulesInfo = '${p.gateRules ?? ''} ${p.description ?? ''}'.toLowerCase();
        bool match = false;
        for (final r in _filterState.rules) {
          final rLower = r.toLowerCase();
          if (rLower.contains('curfew') && (rulesInfo.contains('curfew') || rulesInfo.contains('24/7') || rulesInfo.contains('24x7') || rulesInfo.contains('no timing'))) match = true;
          else if (rulesInfo.contains(rLower.replaceAll('allowed', '').replaceAll('entry', '').trim())) match = true;
        }
        if (!match) return false;
      }

      // 14. Amenities match
      if (_filterState.amenities.isNotEmpty) {
        bool match = false;
        String feat = p.features.join(' ').toLowerCase();
        String desc = (p.description ?? '').toLowerCase();
        for (final a in _filterState.amenities) {
          final aClean = a.toLowerCase().split('/').first.trim();
          if (feat.contains(aClean) || desc.contains(aClean)) match = true;
        }
        if (!match) return false;
      }

      return true;
    }

    final currentPos = _effectivePosition;

    // Retrieve all platform properties matching type, search query, and filters
    // Without any artificial 50km radius cutoff, ensuring properties across all
    // cities, states, and different countries worldwide are included.
    final matchingProperties = _allProperties
        .where((p) => matchesType(p) && matchesSearch(p) && matchesFilters(p))
        .toList();

    matchingProperties.sort((a, b) {
      // 1. Explicit user price sort
      if (_filterState.sortBy == 'price_asc' || _filterState.sortBy == 'price_desc') {
        double priceA = double.tryParse(a.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        double priceB = double.tryParse(b.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        if (_filterState.sortBy == 'price_asc') {
          return priceA.compareTo(priceB);
        } else {
          return priceB.compareTo(priceA);
        }
      }

      // 2. Promotion boosts
      final promoA = a.id != null ? _activePromotions[a.id] : null;
      final promoB = b.id != null ? _activePromotions[b.id] : null;

      double distA = double.infinity;
      double distB = double.infinity;

      if (currentPos != null) {
        distA = Geolocator.distanceBetween(
          currentPos.latitude,
          currentPos.longitude,
          a.latitude,
          a.longitude,
        );
        distB = Geolocator.distanceBetween(
          currentPos.latitude,
          currentPos.longitude,
          b.latitude,
          b.longitude,
        );
      }

      final bool isLocMatchA = _searchQuery.isNotEmpty && (a.locationStr.toLowerCase().contains(_searchQuery.toLowerCase()) || a.title.toLowerCase().contains(_searchQuery.toLowerCase()));
      final bool isLocMatchB = _searchQuery.isNotEmpty && (b.locationStr.toLowerCase().contains(_searchQuery.toLowerCase()) || b.title.toLowerCase().contains(_searchQuery.toLowerCase()));

      final bool isBoostedA = promoA != null && (distA <= (promoA.radiusKm * 1000) || isLocMatchA);
      final bool isBoostedB = promoB != null && (distB <= (promoB.radiusKm * 1000) || isLocMatchB);

      if (isBoostedA && !isBoostedB) {
        return -1; // Promoted within promo radius goes first (#1)
      } else if (!isBoostedA && isBoostedB) {
        return 1;
      } else if (isBoostedA && isBoostedB) {
        final posComp = promoA.priorityPosition.compareTo(promoB.priorityPosition);
        if (posComp != 0) return posComp;
        return distA.compareTo(distB);
      }

      // 3. Location-Wise Ordering (Proximity):
      // Nearby properties (e.g. within 50km) show at the top,
      // followed seamlessly by properties in other cities, states, and different countries worldwide.
      if (currentPos != null) {
        return distA.compareTo(distB);
      }

      return 0; // relevance or fallback
    });

    _currentSearchRadiusKm = 0; // Worldwide / overall
    return matchingProperties;
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

  /// Get the scroll controller for Explore active tab
  ScrollController _exploreControllerForType(String typeStr) {
    switch (typeStr) {
      case 'Home':
        return _exploreHomeScrollController;
      case 'PG':
        return _explorePgScrollController;
      case 'Buy':
        return _exploreBuyScrollController;
      default:
        return _exploreRentalScrollController;
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

    // ── Build the main mobile scaffold (used on both mobile AND desktop) ──
    final mobileScaffold = PopScope(
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
        // Mobile bottom nav
        bottomNavigationBar: AnimatedSlide(
          duration: const Duration(milliseconds: 300),
          offset: (_isScrollUIVisible && !(_searchFocusNode.hasFocus || _searchQuery.isNotEmpty)) ? Offset.zero : const Offset(0, 1),
          child: _buildBottomNav(isDark),
        ),
        body: IndexedStack(
          index: _bottomNavIndex == 4 ? 0 : _bottomNavIndex,
          children: [
            Stack(
              children: [
                Positioned.fill(
                  child: Column(
                    children: [
                      // ── Swiggy-style header ──
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
                ),

                // ── Floating Bottom Center Search Button (appears when scrolling down) ──
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 22,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _buildFloatingBottomSearchButton(isDark),
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

    return mobileScaffold;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXPLORE HEADER (collapsing Swiggy-style header with sticky tabs)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildExploreHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSearchActive = _searchFocusNode.hasFocus || _searchQuery.isNotEmpty;

    final headerBgColor = (!_isScrollUIVisible || isSearchActive)
        ? (isDark ? AppTheme.darkScaffold : Colors.white)
        : AppTheme.primaryAccent;
    final isBgDark = ThemeData.estimateBrightnessForColor(headerBgColor) == Brightness.dark;
    final headerTextColor = isBgDark ? Colors.white : Colors.black87;
    final headerSubTextColor = isBgDark ? Colors.white70 : Colors.black54;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      decoration: BoxDecoration(
        color: headerBgColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(isSearchActive ? 0 : (_isScrollUIVisible ? 36 : 18)),
          bottomRight: Radius.circular(isSearchActive ? 0 : (_isScrollUIVisible ? 36 : 18)),
        ),
        boxShadow: (!_isScrollUIVisible && !isSearchActive)
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                  blurRadius: 12,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: (_isScrollUIVisible && !isSearchActive) ? 10 : 16,
            ),
            // ── Top row: "Explore" title + Saved + Settings buttons (collapses while scrolling down) ──
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
                          Expanded(
                            child: Text(
                              'Explore',
                              style: TextStyle(
                                fontFamily: 'ProximaNova',
                                color: headerTextColor,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                          ),
                          // ── Saved Properties button ──
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
                          // ── Settings button ──
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
                              padding: const EdgeInsets.fromLTRB(2.0, 8.0, 8.0, 8.0),
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

            // ── Search bar row (collapses while scrolling down) ──
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              child: (!_isScrollUIVisible && !isSearchActive)
                  ? const SizedBox(width: double.infinity, height: 0)
                  : Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, (_isScrollUIVisible && !isSearchActive) ? 20 : 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: NewSearchBar(
                              readOnly: true,
                              showShadow: false,
                              onTap: _openUnifiedSearch,
                              onVoiceTap: _openVoiceSearch,
                            ),
                          ),
                          const SizedBox(width: 10),

                          // ── SORT button ──
                          BouncingButton(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _showSortBottomSheet();
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  height: 52,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'SORT',
                                        style: TextStyle(
                                          fontFamily: 'ProximaNova',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : Colors.black87,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Icon(
                                        CupertinoIcons.sort_down,
                                        size: 13,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ],
                                  ),
                                ),
                                if (_filterState.activeFilterCount > 0)
                                  Positioned(
                                    top: -6,
                                    right: -6,
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white : Colors.black,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDark ? Colors.black : Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: Text(
                                        '${_filterState.activeFilterCount}',
                                        style: TextStyle(
                                          color: isDark ? Colors.black : Colors.white,
                                          fontSize: 11,
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

            // ── Sticky Category Tabs inside Header (hidden at top, appears only while scrolling) ──
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              child: (_isScrollUIVisible || isSearchActive)
                  ? const SizedBox(width: double.infinity, height: 0)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeaderTabBar(
                          headerTextColor,
                          headerSubTextColor,
                          selectedIndex: _exploreCategoryIndex,
                          onTabSelected: (index) {
                            setState(() {
                              _exploreCategoryIndex = index;
                              final q = _searchQuery.toLowerCase().trim();
                              if (q == 'hostel' || q == 'hostels' || q == 'pg' || q == 'rentals' || q == 'rental' || q == 'buy') {
                                _searchQuery = '';
                                _searchController.clear();
                              }
                            });
                            if (_explorePageController.hasClients) {
                              _explorePageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeInOutCubic,
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExploreTabContent(String typeStr) {
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

    final scrollCtrl = _exploreControllerForType(typeStr);

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
        await Future.wait([
          _refreshLocationFast(updateFeed: true),
          _fetchProperties(),
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
              bottom: 84.0,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight > 140
                    ? constraints.maxHeight - 140
                    : 300,
              ),
              child: (_isInitialLoading && _allProperties.isEmpty)
                  ? _buildSkeletonGrid()
                  : (properties.isEmpty
                      ? Center(child: _buildEmptyState(emptyLabel))
                      : _buildPropertyList(properties, 'Explore')),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExploreMarketplaceView(BuildContext context, bool isDark) {
    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            children: [
              // ── Swiggy-style Explore header ──
              _buildExploreHeader(context),
              // ── Content ──
              if (_searchFocusNode.hasFocus || _searchQuery.isNotEmpty)
                Expanded(
                  child: _buildSearchResults(),
                )
              else
                Expanded(
                  child: NotificationListener<UserScrollNotification>(
                    onNotification: (notification) {
                      if (notification.metrics.axis != Axis.vertical) {
                        return false;
                      }

                      if (notification.direction == ScrollDirection.reverse) {
                        // scrolling down
                        if (_isScrollUIVisible) {
                          setState(() => _isScrollUIVisible = false);
                        }
                      } else if (notification.direction == ScrollDirection.forward) {
                        // scrolling up
                        if (!_isScrollUIVisible) {
                          setState(() => _isScrollUIVisible = true);
                        }
                      }
                      return false;
                    },
                    child: PageView(
                      controller: _explorePageController,
                      onPageChanged: (index) {
                        if (_exploreCategoryIndex != index) {
                          setState(() {
                            _exploreCategoryIndex = index;
                          });
                          AnalyticsService.instance.logCategoryClick(
                            index == 0
                                ? 'Explore_Home'
                                : index == 1
                                ? 'Explore_Hostel'
                                : (index == 3 ? 'Explore_Buy' : 'Explore_Rental'),
                          );
                          HapticFeedback.selectionClick();
                        }
                      },
                      children: [
                        _buildExploreTabContent('Home'),
                        _buildExploreTabContent('PG'),
                        _buildExploreTabContent('Rental'),
                        _buildExploreTabContent('Buy'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── Floating Bottom Center Search Button (appears when scrolling down) ──
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 22,
          left: 0,
          right: 0,
          child: Center(
            child: _buildFloatingBottomSearchButton(isDark),
          ),
        ),
      ],
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
                        final amenitiesFuture = AmenityService.getNearby(
                          prop.latitude,
                          prop.longitude,
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PropertyDetailsScreen(
                              property: prop,
                              preloadedTransportFuture: transportFuture,
                              preloadedAmenitiesFuture: amenitiesFuture,
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

    final searchPos = _effectivePosition;
    if (searchPos != null) {
      localMatches.sort((a, b) {
        final distA = Geolocator.distanceBetween(
          searchPos.latitude,
          searchPos.longitude,
          a.latitude,
          a.longitude,
        );
        final distB = Geolocator.distanceBetween(
          searchPos.latitude,
          searchPos.longitude,
          b.latitude,
          b.longitude,
        );
        return distA.compareTo(distB);
      });
    }

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
              double? dist;
              if (searchPos != null) {
                dist = Geolocator.distanceBetween(
                  searchPos.latitude,
                  searchPos.longitude,
                  prop.latitude,
                  prop.longitude,
                );
              }
              return GridPropertyCard(
                property: prop,
                distanceInMeters: dist,
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
              bottom: 84.0,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight > 140
                    ? constraints.maxHeight - 140
                    : 300,
              ),
              child: (_isInitialLoading && _allProperties.isEmpty)
                  ? _buildSkeletonGrid()
                  : (properties.isEmpty
                      ? Center(child: _buildEmptyState(emptyLabel))
                      : _buildPropertyList(properties, typeStr)),
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
    
    // When scrolling down (!_isScrollUIVisible) or searching, the header background is white (or dark scaffold in dark mode).
    // When at the top (_isScrollUIVisible && !isSearchActive), it uses the brand yellow (AppTheme.primaryAccent).
    final headerBgColor = (!_isScrollUIVisible || isSearchActive)
        ? (isDark ? AppTheme.darkScaffold : Colors.white)
        : AppTheme.primaryAccent;
    final isBgDark = ThemeData.estimateBrightnessForColor(headerBgColor) == Brightness.dark;
    final headerTextColor = isBgDark ? Colors.white : Colors.black87;
    final headerSubTextColor = isBgDark ? Colors.white70 : Colors.black54;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      decoration: BoxDecoration(
        color: headerBgColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(isSearchActive ? 0 : (_isScrollUIVisible ? 36 : 18)),
          bottomRight: Radius.circular(isSearchActive ? 0 : (_isScrollUIVisible ? 36 : 18)),
        ),
        boxShadow: (!_isScrollUIVisible && !isSearchActive)
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                  blurRadius: 12,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: (_isScrollUIVisible && !isSearchActive) ? 10 : 16,
            ),
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
                              padding: const EdgeInsets.fromLTRB(2.0, 8.0, 8.0, 8.0),
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

            // ── Search bar row (collapses while scrolling down) ──────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              child: (!_isScrollUIVisible && !isSearchActive)
                  ? const SizedBox(width: double.infinity, height: 0)
                  : Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                                child: NewSearchBar(
                                  readOnly: true,
                                  showShadow: false,
                                  onTap: _openUnifiedSearch,
                                  onVoiceTap: _openVoiceSearch,
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
                                        height: 52,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                            width: 1.0,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'SORT',
                                              style: TextStyle(
                                                fontFamily: 'ProximaNova',
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: isDark ? Colors.white : Colors.black87,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Icon(
                                              CupertinoIcons.sort_down,
                                              size: 13,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (_filterState.activeFilterCount > 0)
                                        Positioned(
                                          top: -6,
                                          right: -6,
                                          child: Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.white : Colors.black,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isDark ? Colors.black : Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                            child: Text(
                                              '${_filterState.activeFilterCount}',
                                              style: TextStyle(
                                                color: isDark ? Colors.black : Colors.white,
                                                fontSize: 11,
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
            ),

            // ── Sticky Category Tabs inside Header (remains sticky while scrolling) ──
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              child: isSearchActive
                  ? const SizedBox(width: double.infinity, height: 0)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeaderTabBar(headerTextColor, headerSubTextColor),
                        SizedBox(
                          height: (_isScrollUIVisible && !isSearchActive) ? 8 : 12,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderTabBar(
    Color textColor,
    Color subTextColor, {
    int? selectedIndex,
    ValueChanged<int>? onTabSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHeaderYellow = _isScrollUIVisible && !(_searchFocusNode.hasFocus || _searchQuery.isNotEmpty);

    // Signature brand yellow from AppTheme (the exact yellow color used throughout the app)
    final brandYellow = AppTheme.primaryAccent;

    // When scrolling down (white/dark sticky header), active tab shows in OUR BRAND YELLOW!
    // When at the top (entire header is yellow), active tab shows in black for maximum contrast.
    final activeColor = isHeaderYellow ? Colors.black87 : brandYellow;
    final activeIndicatorColor = isHeaderYellow ? Colors.black87 : brandYellow;
    final inactiveColor = isHeaderYellow
        ? Colors.black.withValues(alpha: 0.55)
        : (isDark ? Colors.white60 : Colors.black45);

    final tabs = [
      (label: 'ALL', index: 0, icon: CupertinoIcons.square_grid_2x2),
      (label: 'HOSTELS', index: 1, icon: Iconsax.building),
      (label: 'RENTALS', index: 2, icon: CupertinoIcons.house),
      (label: 'BUY', index: 3, icon: CupertinoIcons.bag),
    ];

    final currentSelectedIndex = selectedIndex ?? _selectedTypeIndex;

    return Padding(
      padding: EdgeInsets.only(top: isHeaderYellow ? 4 : 10),
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
                color: isHeaderYellow
                    ? Colors.black.withValues(alpha: 0.2)
                    : subTextColor.withValues(alpha: 0.2),
                margin: const EdgeInsets.only(
                  left: 14,
                  right: 14,
                  bottom: 6,
                ),
              );
            }
            final tabIndex = i ~/ 2;
            final tab = tabs[tabIndex];
            final isSelected = tab.index == currentSelectedIndex;
            return GestureDetector(
              onTap: () {
                if (currentSelectedIndex != tab.index) {
                  HapticFeedback.selectionClick();
                  if (onTabSelected != null) {
                    onTabSelected(tab.index);
                  } else {
                    setState(() {
                      _selectedTypeIndex = tab.index;
                      final q = _searchQuery.toLowerCase().trim();
                      if (q == 'hostel' || q == 'hostels' || q == 'pg' || q == 'rentals' || q == 'rental' || q == 'buy') {
                        _searchQuery = '';
                        _searchController.clear();
                      }
                    });
                    if (_pageController.hasClients) {
                      _pageController.animateToPage(
                        tab.index,
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOutCubic,
                      );
                    }
                  }
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
                          color: isSelected ? activeColor : inactiveColor,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontFamily: 'ProximaNova',
                            color: isSelected ? activeColor : inactiveColor,
                            fontSize: 12.5,
                            fontWeight:
                                isSelected ? FontWeight.w800 : FontWeight.w600,
                            letterSpacing: 0.3,
                            shadows: (isSelected && !isHeaderYellow && !isDark)
                                ? [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: 0.18),
                                      blurRadius: 1,
                                      offset: const Offset(0, 0.5),
                                    ),
                                  ]
                                : null,
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
                        color: isSelected ? activeIndicatorColor : Colors.transparent,
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
  // FLOATING BOTTOM CENTER SEARCH BUTTON (appears while scrolling down)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildFloatingBottomSearchButton(bool isDark) {
    final isSearchActive = _searchFocusNode.hasFocus || _searchQuery.isNotEmpty;
    final isVisible = !_isScrollUIVisible && !isSearchActive && (_bottomNavIndex == 0 || _bottomNavIndex == 1);

    return AnimatedSlide(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      offset: isVisible ? Offset.zero : const Offset(0, 1.8),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        opacity: isVisible ? 1.0 : 0.0,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutBack,
          scale: isVisible ? 1.0 : 0.75,
          child: IgnorePointer(
            ignoring: !isVisible,
            child: BouncingButton(
              onTap: () {
                HapticFeedback.mediumImpact();
                _openUnifiedSearch();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.search,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Search',
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
              child: NewSearchBar(
                readOnly: true,
                height: 48,
                onTap: _openUnifiedSearch,
                onVoiceTap: _openVoiceSearch,
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
                    final activeColor = AppTheme.primaryAccent;
                    final textColor = isSelected ? activeColor : appBarTextColor;
                    final subTextColor = isSelected ? activeColor : appBarTextColor.withValues(alpha: 0.6);
                    
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
                                color: isSelected ? activeColor : Colors.transparent,
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
              final isSelected = _bottomNavIndex == index;

              final item = tabItems[index];

              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (index == 0) {
                    _lastExploreTabTap = null;
                    final homeCtrl = _selectedTypeIndex == 0
                        ? _homeScrollController
                        : (_selectedTypeIndex == 1
                            ? _pgScrollController
                            : (_selectedTypeIndex == 3
                                ? _buyScrollController
                                : _rentalScrollController));
                    final isAtTop = !homeCtrl.hasClients || homeCtrl.offset <= 20;
                    setState(() {
                      _bottomNavIndex = 0;
                      if (isAtTop) _isScrollUIVisible = true;
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
                    final now = DateTime.now();
                    final isMultiTap = _lastExploreTabTap != null &&
                        now.difference(_lastExploreTabTap!).inMilliseconds < 1200;
                    _lastExploreTabTap = now;

                    debugPrint('🔍 [Explore Tab] tapped: bottomNavIndex=$_bottomNavIndex, isMultiTap=$isMultiTap');

                    // If already on Explore tab (repeat click) or clicked more than once within 1.2s
                    if (_bottomNavIndex == 1 || isMultiTap) {
                      debugPrint('🚀 [Explore Tab] Opening UnifiedSearchScreen directly!');
                      _openUnifiedSearch();
                    } else {
                      final expCtrl = _exploreControllerForType(
                        _exploreCategoryIndex == 0
                            ? 'Home'
                            : (_exploreCategoryIndex == 1
                                ? 'PG'
                                : (_exploreCategoryIndex == 3
                                    ? 'Buy'
                                    : 'Rental')),
                      );
                      final isAtTop = !expCtrl.hasClients || expCtrl.offset <= 20;
                      setState(() {
                        _bottomNavIndex = 1;
                        if (isAtTop) _isScrollUIVisible = true;
                      });
                    }
                  } else if (index == 2) {
                    _lastExploreTabTap = null;
                    setState(() {
                      _bottomNavIndex = 2;
                    });
                  } else if (index == 3) {
                    _lastExploreTabTap = null;
                    setState(() {
                      _bottomNavIndex = 3;
                    });
                  } else if (index == 4) {
                    _lastExploreTabTap = null;
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
                  : (_currentSearchRadiusKm > 0
                      ? 'No properties within ${_currentSearchRadiusKm}km. Try a different location!'
                      : 'No properties found in this category. Try exploring other areas or clearing filters!'),
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
    final currentPos = _effectivePosition;

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

  Widget _buildSkeletonGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => const SkeletonGridCard(),
    );
  }

  Widget _buildPropertyList(List<PropertyModel> properties, String typeStr) {
    const int crossAxisCount = 2;
    const double aspectRatio = 0.8;
    const int adInterval = 7;
    final bool showAds = adsEnabled && properties.length >= 4;
    final int adCount = showAds ? (properties.length ~/ (adInterval - 1)) : 0;
    final int totalCount = properties.length + adCount;

    return GridView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.only(top: 16),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 14,
        mainAxisSpacing: 16,
        childAspectRatio: aspectRatio,
      ),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        // Render In-Feed Native Ad card seamlessly every 7 items
        if (showAds && (index + 1) % adInterval == 0) {
          final slotIndex = index ~/ adInterval;
          return InFeedGridAdCard(slotIndex: slotIndex);
        }

        final propIndex = showAds ? index - (index ~/ adInterval) : index;
        if (propIndex >= properties.length) return const SizedBox.shrink();

        final prop = properties[propIndex];
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
        final promo = prop.id != null ? _activePromotions[prop.id] : null;
        final bool isPromoted = promo != null && (distance == null || distance <= (promo.radiusKm * 1000));
        return GridPropertyCard(
          property: prop,
          distanceInMeters: distance,
          isPromoted: isPromoted,
          onTap: () {
            final transportFuture = TransportService.getNearby(
              prop.latitude,
              prop.longitude,
            );
            final amenitiesFuture = AmenityService.getNearby(
              prop.latitude,
              prop.longitude,
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PropertyDetailsScreen(
                  property: prop,
                  preloadedTransportFuture: transportFuture,
                  preloadedAmenitiesFuture: amenitiesFuture,
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
    String initialCat = 'Rental';
    if (_selectedTypeIndex == 1) {
      initialCat = 'PG';
    } else if (_selectedTypeIndex == 2) {
      initialCat = 'Rental';
    } else if (_selectedTypeIndex == 3) {
      initialCat = 'Buy';
    } else if (_filterState.propertyTypes.contains('PG')) {
      initialCat = 'PG';
    } else if (_filterState.propertyTypes.contains('Buy') || _filterState.propertyTypes.contains('Sale')) {
      initialCat = 'Buy';
    } else if (_filterState.selectedCategory.isNotEmpty) {
      initialCat = _filterState.selectedCategory;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterBottomSheet(
        initialState: _filterState,
        initialCategory: initialCat,
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
