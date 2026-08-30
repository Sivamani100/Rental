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
import 'search_screen.dart';
import 'ai_chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class PropertyModel {
  final String? id;
  final String title;
  final String price;
  final String locationStr;
  final double latitude;
  final double longitude;
  final List<String> imageUrls;
  final List<String> tags;
  final String beds;
  final String baths;
  final String area;
  final String type; // 'Rental' or 'PG' or 'House'
  final String ownerPhone;
  final String? ownerWhatsapp;
  final List<String> features;
  bool isAvailable;
  String status;

  // Specific financial & tenure details
  final String? securityDeposit;
  final String? maintenanceCharges;
  final String? noticePeriod;
  final String? agreementDuration;
  final String? description;
  final String? perDayWithFood;
  final String? perDayWithoutFood;
  List<dynamic> reviews;
  List<dynamic> suggestedPhotos;

  // PG Specific details
  final String? genderPreference; // Boys, Girls, Co-Living
  final String? sharingType; // Single, 2 Sharing, 3 Sharing, etc.
  final String? foodDetails; // 3 Meals, 2 Meals, Veg/Non-Veg, Self Cooking
  final String? foodQuality; // Homely & Hygienic, Veg only, etc.
  final String? drinkingWater; // RO Purified, Cool Water Dispenser
  final String? waterSupply; // 24/7 Water Supply, Timed
  final String? powerBackup; // 24/7 Power + Inverter/Generator
  final String? acType; // AC Room, Non-AC, Cooler
  final String? bathroomType; // Attached, Common, Western/Indian
  final String? cleanlinessInfo; // Daily Room & Bath Housekeeping
  final String? securityInfo; // 24/7 CCTV, Guard, Biometric Entry
  final String? verificationPolicy; // ID Verification Mandatory
  final String? managementInfo; // Owner on site, Resident Warden
  final String? gateRules; // No Curfew, 10:30 PM Gate Close, Guests Allowed

  // Rental Specific details
  final String? bhkType; // 1 BHK, 2 BHK, 3 BHK, Villa
  final String?
  furnishingStatus; // Unfurnished, Semi-Furnished, Fully-Furnished
  final String? plumbingStatus; // Taps & Shower Tested - No leaks
  final String? seepageStatus; // Zero Seepage, Freshly Painted
  final String? electricalStatus; // All Switches/Sockets Tested, Inverter Ready
  final String? meterStatus; // Separate EB Sub-Meter / Dedicated Meter
  final String? billsInfo; // EB per meter unit, Water included/separate
  final String? tenantPreference; // Family, Working Bachelors, Anyone
  final String? petPolicy; // Pets Allowed / No Pets
  final String? parkingInfo; // Covered Car & Bike Parking

  PropertyModel({
    this.id,
    required this.title,
    required this.price,
    required this.locationStr,
    required this.latitude,
    required this.longitude,
    required this.imageUrls,
    required this.tags,
    required this.beds,
    required this.baths,
    required this.area,
    required this.type,
    required this.ownerPhone,
    this.ownerWhatsapp,
    required this.features,
    this.isAvailable = true,
    this.status = 'pending',
    this.securityDeposit,
    this.maintenanceCharges,
    this.noticePeriod,
    this.agreementDuration,
    this.description,
    this.perDayWithFood,
    this.perDayWithoutFood,
    this.genderPreference,
    this.sharingType,
    this.foodDetails,
    this.foodQuality,
    this.drinkingWater,
    this.waterSupply,
    this.powerBackup,
    this.acType,
    this.bathroomType,
    this.cleanlinessInfo,
    this.securityInfo,
    this.verificationPolicy,
    this.managementInfo,
    this.gateRules,
    this.bhkType,
    this.furnishingStatus,
    this.plumbingStatus,
    this.seepageStatus,
    this.electricalStatus,
    this.meterStatus,
    this.billsInfo,
    this.tenantPreference,
    this.petPolicy,
    this.parkingInfo,
    List<dynamic>? reviews,
    List<dynamic>? suggestedPhotos,
  }) : reviews = reviews ?? [],
       suggestedPhotos = suggestedPhotos ?? [];
  
  double get averageRating {
    if (reviews.isEmpty) return 0.0;
    double sum = 0;
    for (var r in reviews) {
      sum += (r['rating'] as num?)?.toDouble() ?? 0.0;
    }
    return sum / reviews.length;
  }
  
  int get reviewCount => reviews.length;

  factory PropertyModel.fromJson(Map<String, dynamic> json) {
    return PropertyModel(
      id: json['id'],
      title: json['title'],
      price: json['price'],
      locationStr: json['location_str'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      imageUrls: List<String>.from(json['image_urls'] ?? []),
      tags: List<String>.from(json['tags'] ?? []),
      beds: json['beds'],
      baths: json['baths'],
      area: json['area'],
      type: json['type'],
      ownerPhone: json['owner_phone'],
      ownerWhatsapp: json['owner_whatsapp'],
      features: List<String>.from(json['features'] ?? []),
      isAvailable: json['is_available'] ?? true,
      status: json['status'] ?? 'pending',
      securityDeposit: json['security_deposit'],
      maintenanceCharges: json['maintenance_charges'],
      reviews: json['reviews'] != null ? List<dynamic>.from(json['reviews']) : [],
      suggestedPhotos: json['suggested_photos'] != null ? List<dynamic>.from(json['suggested_photos']) : [],
      noticePeriod: json['notice_period'],
      agreementDuration: json['agreement_duration'],
      description: json['description'],
      perDayWithFood: json['per_day_with_food'],
      perDayWithoutFood: json['per_day_without_food'],
      genderPreference: json['gender_preference'],
      sharingType: json['sharing_type'],
      foodDetails: json['food_details'],
      foodQuality: json['food_quality'],
      drinkingWater: json['drinking_water'],
      waterSupply: json['water_supply'],
      powerBackup: json['power_backup'],
      acType: json['ac_type'],
      bathroomType: json['bathroom_type'],
      cleanlinessInfo: json['cleanliness_info'],
      securityInfo: json['security_info'],
      verificationPolicy: json['verification_policy'],
      managementInfo: json['management_info'],
      gateRules: json['gate_rules'],
      bhkType: json['bhk_type'],
      furnishingStatus: json['furnishing_status'],
      plumbingStatus: json['plumbing_status'],
      seepageStatus: json['seepage_status'],
      electricalStatus: json['electrical_status'],
      meterStatus: json['meter_status'],
      billsInfo: json['bills_info'],
      tenantPreference: json['tenant_preference'],
      petPolicy: json['pet_policy'],
      parkingInfo: json['parking_info'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'price': price,
      'location_str': locationStr,
      'latitude': latitude,
      'longitude': longitude,
      'image_urls': imageUrls,
      'tags': tags,
      'beds': beds,
      'baths': baths,
      'area': area,
      'type': type,
      'owner_phone': ownerPhone,
      'owner_whatsapp': ownerWhatsapp,
      'features': features,
      'is_available': isAvailable,
      'status': status,
      'security_deposit': securityDeposit,
      'maintenance_charges': maintenanceCharges,
      'notice_period': noticePeriod,
      'agreement_duration': agreementDuration,
      'description': description,
      'per_day_with_food': perDayWithFood,
      'per_day_without_food': perDayWithoutFood,
      'gender_preference': genderPreference,
      'sharing_type': sharingType,
      'food_details': foodDetails,
      'food_quality': foodQuality,
      'drinking_water': drinkingWater,
      'water_supply': waterSupply,
      'power_backup': powerBackup,
      'ac_type': acType,
      'bathroom_type': bathroomType,
      'cleanliness_info': cleanlinessInfo,
      'security_info': securityInfo,
      'verification_policy': verificationPolicy,
      'management_info': managementInfo,
      'gate_rules': gateRules,
      'bhk_type': bhkType,
      'furnishing_status': furnishingStatus,
      'plumbing_status': plumbingStatus,
      'seepage_status': seepageStatus,
      'electrical_status': electricalStatus,
      'meter_status': meterStatus,
      'bills_info': billsInfo,
      'tenant_preference': tenantPreference,
      'pet_policy': petPolicy,
      'parking_info': parkingInfo,
      'reviews': reviews,
      'suggested_photos': suggestedPhotos,
    };
  }
}

class HomeScreen extends StatefulWidget {
  final String? initialPropertyId;

  const HomeScreen({super.key, this.initialPropertyId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedTypeIndex = 0; // 0 for PG / Hostel, 1 for Rental
  late final PageController _pageController;

  Position? _currentPosition;
  String _currentCity = 'Finding location...';
  String _currentArea = 'Detecting your area...';
  bool _hasLocationPermission = true;
  bool _isInitialLoading = true;

  List<PropertyModel> _allProperties = [];
  int _currentSearchRadiusKm = 5;

  final _supabase = Supabase.instance.client;
  Timer? _autoLocationTimer;
  bool _isRefreshingLocation = false;
  bool _hasOpenedInitialProperty = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedTypeIndex);
    WidgetsBinding.instance.addObserver(this);
    _currentPosition = null; // Do not mock position, wait for real GPS
    _currentCity = 'Finding location...';
    _currentArea = 'Detecting your area...';
    _isInitialLoading = true;
    _initAppAndLocation();
  }

  Future<void> _initAppAndLocation() async {
    final propFuture = _fetchProperties();
    final locFuture = _refreshLocationFast(updateFeed: true);
    await Future.wait([propFuture, locFuture]);

    if (mounted) {
      setState(() {
        _isInitialLoading = false;
      });
      _startAutoLocationRefresh();
      _checkAndOpenInitialProperty();
    }
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

  void _startAutoLocationRefresh() {
    _autoLocationTimer?.cancel();
    _autoLocationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _refreshLocationFast(updateFeed: false);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _autoLocationTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startAutoLocationRefresh();
      _refreshLocationFast(updateFeed: false);
    } else if (state == AppLifecycleState.paused) {
      _autoLocationTimer?.cancel();
    }
  }

  Future<void> _fetchProperties() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load cached properties first and precache photos immediately
      final String? cachedData = prefs.getString('cached_properties');
      if (cachedData != null && mounted) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        final cachedList = decoded.map((e) => PropertyModel.fromJson(e)).toList();
        setState(() {
          _allProperties = cachedList;
        });
        _precachePropertyImages(cachedList);
        _checkAndOpenInitialProperty();
      }

      // Fetch fresh data from network (only approved properties)
      final data = await _supabase
          .from('properties')
          .select()
          .eq('status', 'approved');

      // Update cache
      await prefs.setString('cached_properties', jsonEncode(data));

      if (mounted) {
        final freshList = (data as List)
            .map((e) => PropertyModel.fromJson(e))
            .toList();
        setState(() {
          _allProperties = freshList;
        });
        _precachePropertyImages(freshList);
        _checkAndOpenInitialProperty();
      }
    } catch (e) {
      if (mounted) {
        if (_allProperties.isNotEmpty) {
           AppSnackbar.error(context, 'Offline mode: Showing cached properties.');
        } else {
           AppSnackbar.error(context, 'Failed to fetch properties: $e');
        }
      }
    }
  }

  void _precachePropertyImages(List<PropertyModel> properties) {
    if (!mounted) return;
    for (final prop in properties.take(20)) {
      if (prop.imageUrls.isNotEmpty) {
        final firstUrl = prop.imageUrls.first;
        if (firstUrl.startsWith('http')) {
          try {
            precacheImage(
              CachedNetworkImageProvider(
                firstUrl,
                maxWidth: 800,
              ),
              context,
            );
          } catch (_) {}
        }
      }
    }
  }

  Future<void> _refreshLocationFast({bool updateFeed = false}) async {
    if (_isRefreshingLocation) return;
    _isRefreshingLocation = true;
    if (mounted) setState(() {});

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() { _hasLocationPermission = false; });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (mounted) setState(() { _hasLocationPermission = false; });
          return;
        }
      }

      if (mounted) setState(() { _hasLocationPermission = true; });

      Position? position;
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

      if (position == null) return;
      if (!mounted) return;
      _currentPosition = position;

      try {
        List<Placemark> placemarks = await Geocoding()
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
        // Keep smooth 'Finding location...' state
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

    if (_currentPosition == null) {
      return _allProperties.where(matchesType).toList();
    }

    int searchRadiusKm = 5;
    List<PropertyModel> tempFiltered = [];

    // Increment radius by 5km until we find properties or hit 50km limit
    while (searchRadiusKm <= 50) {
      tempFiltered = _allProperties.where((property) {
        if (!matchesType(property)) return false;

        double distanceInMeters = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
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
      tempFiltered = _allProperties.where(matchesType).toList();
    }

    // Sort strictly in ascending order by distance (closest first: 20m, 30m, 1.2km, etc.)
    tempFiltered.sort((a, b) {
      double distA = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        a.latitude,
        a.longitude,
      );
      double distB = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        b.latitude,
        b.longitude,
      );
      return distA.compareTo(distB);
    });

    _currentSearchRadiusKm = searchRadiusKm > 50 ? 50 : searchRadiusKm;
    return tempFiltered;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isInitialLoading || (_currentPosition == null && _hasLocationPermission)) {
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
                      child: Lottie.asset(
                        'assets/loadingg.json',
                        width: 500,
                        height: 500,
                        fit: BoxFit.contain,
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
                  Lottie.asset(
                    'assets/location.json',
                    width: 250,
                    height: 250,
                    fit: BoxFit.contain,
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

    return Scaffold(
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
                        top: 6.0,
                        bottom: 8.0,
                      ),
                      child: _buildHeader(context),
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _selectedTypeIndex = index;
                          });
                          HapticFeedback.selectionClick();
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
                // Pinned floating bottom toggle with 20px bottom margin
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 20,
                  child: SafeArea(
                    top: false,
                    child: _buildBottomToggle(),
                  ),
                ),
              ],
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

    return RefreshIndicator(
      color: Colors.black,
      backgroundColor: const Color(0xFFFFEB3A),
      displacement: 32,
      edgeOffset: 8,
      triggerMode: RefreshIndicatorTriggerMode.anywhere,
      onRefresh: () async {
        HapticFeedback.mediumImpact();
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
            });
            _refreshLocationFast(updateFeed: true);
          },
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
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
      (label: 'Hostel', icon: Iconsax.building_4),
      (label: 'Rental', icon: Iconsax.home_2),
      (label: 'Buy', icon: Iconsax.key),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Google Photos Style Segmented Capsule Bar (Autolayout / Hug Content)
        Container(
          height: 56,
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
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedTypeIndex = index;
                    });
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOutCubic,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOutCubic,
                    padding: isSelected
                        ? const EdgeInsets.symmetric(horizontal: 19, vertical: 9.5)
                        : const EdgeInsets.symmetric(horizontal: 14, vertical: 9.5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFFEB3A)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    alignment: Alignment.center,
                    child: isSelected
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.icon,
                                size: 18,
                                color: Colors.black,
                              ),
                              const SizedBox(width: 9.5),
                              Text(
                                item.label,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  color: Colors.black,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            item.label,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                              letterSpacing: -0.2,
                            ),
                          ),
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(width: 10),

        // 2. Google Photos Style Floating Circular AI Button
        BouncingButton(
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AiChatScreen(initialProperties: _allProperties),
              ),
            );
          },
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              shape: BoxShape.circle,
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
            alignment: Alignment.center,
            child: ClipOval(
              child: Transform.scale(
                scale: 1.35,
                child: Lottie.asset(
                  'assets/ai.json',
                  width: 48,
                  height: 48,
                  fit: BoxFit.contain,
                  repeat: true,
                ),
              ),
            ),
          ),
        ),
      ],
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
            Lottie.asset(
              'assets/Nothing founded.json',
              width: 250,
              height: 250,
              fit: BoxFit.contain,
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
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyList(List<PropertyModel> properties) {
    return Column(
      children: properties.map((prop) {
        double? distance;
        if (_currentPosition != null) {
          distance = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PropertyDetailsScreen(property: prop),
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
        child: _showAdminVerified
            ? _buildAdminApprovedView()
            : _buildStandardInfoView(),
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

  const _TopLocationLogoSwitcher({required this.onTap});

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

    return BouncingButton(
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
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
                    width: 34,
                    height: 34,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
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
    );
  }
}




