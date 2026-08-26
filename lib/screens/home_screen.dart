import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_snackbar.dart';
import 'posting_screen.dart';
import 'property_details_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lottie/lottie.dart';

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
  final String? verificationPolicy; // Police & ID Verification Mandatory
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
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedTypeIndex = 0; // 0 for Rental, 1 for PG

  Position? _currentPosition;
  String _currentCity = 'Fetching location...';
  String _currentArea = 'Please wait';
  bool _isLoadingLocation = true;
  bool _hasLocationPermission = true;
  bool _isInitialLoading = true;

  List<PropertyModel> _allProperties = [];
  List<PropertyModel> _filteredProperties = [];
  int _currentSearchRadiusKm = 5;

  final _supabase = Supabase.instance.client;
  int _locationTapCount = 0;
  DateTime? _lastLocationTapTime;
  Timer? _autoLocationTimer;
  Timer? _emptyStateTimer;
  bool _isRefreshingLocation = false;
  bool _canShowEmptyState = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentPosition = Position(
      latitude: 17.6868,
      longitude: 83.2185,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
    _currentCity = 'Not found';
    _currentArea = 'Location unknown';
    _fetchProperties();
    _refreshLocationFast(updateFeed: true);
    _startAutoLocationRefresh();

    // Ensure loading displays for at least 30s before revealing empty state
    _emptyStateTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) {
        setState(() {
          _canShowEmptyState = true;
        });
      }
    });
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
    _emptyStateTimer?.cancel();
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
      
      // Load cached properties first
      final String? cachedData = prefs.getString('cached_properties');
      if (cachedData != null && mounted) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        setState(() {
          _allProperties = decoded.map((e) => PropertyModel.fromJson(e)).toList();
          _filterProperties();
          _isLoadingLocation = false;
          _isInitialLoading = false;
        });
      }

      // Fetch fresh data from network
      final data = await _supabase
          .from('properties')
          .select()
          .eq('status', 'approved');

      // Update cache
      await prefs.setString('cached_properties', jsonEncode(data));

      if (mounted) {
        setState(() {
          _allProperties = (data as List)
              .map((e) => PropertyModel.fromJson(e))
              .toList();
          _filterProperties();
          _isLoadingLocation = false;
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // If we have cached properties, just log or ignore the error to allow offline mode
        if (_allProperties.isNotEmpty) {
           AppSnackbar.error(context, 'Offline mode: Showing cached properties.');
        } else {
           AppSnackbar.error(context, 'Failed to fetch properties: $e');
        }
        setState(() {
          _isLoadingLocation = false;
          _isInitialLoading = false;
        });
      }
    }
  }

  Future<void> _refreshLocationFast({bool updateFeed = false}) async {
    if (_isRefreshingLocation) return;
    _isRefreshingLocation = true;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() { _hasLocationPermission = false; _isLoadingLocation = false; });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (mounted) setState(() { _hasLocationPermission = false; _isLoadingLocation = false; });
          return;
        }
      }

      if (mounted) setState(() { _hasLocationPermission = true; });

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 3),
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
            .timeout(const Duration(seconds: 2));
        if (placemarks.isNotEmpty && mounted) {
          final place = placemarks.first;
          setState(() {
            _currentCity =
                place.locality ?? place.subLocality ?? 'Current City';
            _currentArea =
                '${place.administrativeArea ?? ''}, ${place.country ?? ''}'
                    .replaceAll(RegExp(r'^,\s*'), '');
          });
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          if (updateFeed || _filteredProperties.isEmpty) {
            _filterProperties();
          }
          _isLoadingLocation = false;
        });
      }
    } catch (_) {
      // Fallback already pre-rendered
    } finally {
      _isRefreshingLocation = false;
    }
  }

  void _filterProperties() {
    if (_currentPosition == null) return;

    final selectedTypeStr = _selectedTypeIndex == 0 ? 'PG' : 'Rental';
    int searchRadiusKm = 5;
    List<PropertyModel> tempFiltered = [];

    // Increment radius by 5km until we find properties or hit 50km limit
    while (searchRadiusKm <= 50) {
      tempFiltered = _allProperties.where((property) {
        // 1. Filter by Type (Rental / House vs PG)
        if (selectedTypeStr == 'Rental') {
          if (property.type != 'Rental' && property.type != 'House') return false;
        } else {
          if (property.type != 'PG') return false;
        }

        // 2. Filter by distance
        double distanceInMeters = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          property.latitude,
          property.longitude,
        );

        return distanceInMeters <= (searchRadiusKm * 1000);
      }).toList();

      if (tempFiltered.isNotEmpty) {
        break; // Found properties!
      }
      searchRadiusKm += 5; // Expand search by 5km
    }

    _filteredProperties = tempFiltered;
    _currentSearchRadiusKm = searchRadiusKm > 50 ? 50 : searchRadiusKm;
  }

  @override
  Widget build(BuildContext context) {
    if ((_isInitialLoading || _filteredProperties.isEmpty) && !_canShowEmptyState) {
      return Scaffold(
        backgroundColor: const Color(0xFFFBF7F7),
        body: SizedBox.expand(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: 2.8,
                    child: Lottie.asset(
                      'assets/loadingg.json',
                      width: 170,
                      height: 170,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Loading...',
                    style: TextStyle(
                      color: Colors.black87,
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
        backgroundColor: Colors.white,
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
                  const Text(
                    'Location Access Required',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'We need your location to show you the best properties around you. Please allow location access in your device settings to continue.',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 15,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      Geolocator.openAppSettings();
                    },
                    icon: const Icon(Iconsax.setting_2, size: 20),
                    label: const Text('Open Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 20.0,
                bottom: 8.0,
              ),
              child: _buildHeader(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  bottom: 8.0,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    _buildPropertyList(),
                    const SizedBox(
                      height: 100,
                    ), // padding for floating bottom bar
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [_buildBottomToggle()],
          ),
        ),
      ),
    );
  }

  void _handleAdminTap() {
    final now = DateTime.now();
    if (_lastLocationTapTime == null ||
        now.difference(_lastLocationTapTime!) > const Duration(seconds: 1)) {
      _locationTapCount = 1;
    } else {
      _locationTapCount++;
    }
    _lastLocationTapTime = now;

    if (_locationTapCount >= 3) {
      _locationTapCount = 0;
      _showAdminLoginScreen();
    }
  }

  void _showAdminLoginScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
    ).then((_) => _fetchProperties());
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: _handleAdminTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Iconsax.location, color: Colors.black, size: 24),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentCity,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _currentArea,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: const Color(0xFFFBF7F7),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => PostBottomSheet(
                currentLocation: _currentPosition,
                onPropertyCreated: (newProp) {
                  // Instant local update while backend syncs
                  setState(() {
                    _allProperties.insert(0, newProp);
                    _filterProperties();
                  });
                },
              ),
            ).then((_) {
              // Refresh fully from database to get IDs and fresh data
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
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Iconsax.add, color: Colors.black, size: 19),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Post',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTypeIndex = 0;
                  _filterProperties();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _selectedTypeIndex == 0
                      ? const Color(0xFFFFEB3A)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(26),
                ),
                alignment: Alignment.center,
                child: Text(
                  'PG / Hostel',
                  style: TextStyle(
                    color: _selectedTypeIndex == 0
                        ? Colors.black
                        : Colors.grey.shade500,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTypeIndex = 1;
                  _filterProperties();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _selectedTypeIndex == 1
                      ? const Color(0xFFFFEB3A)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(26),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Rental',
                  style: TextStyle(
                    color: _selectedTypeIndex == 1
                        ? Colors.black
                        : Colors.grey.shade500,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyList() {
    if (_filteredProperties.isEmpty) {
      if (!_canShowEmptyState) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: 2.8,
                    child: Lottie.asset(
                      'assets/loadingg.json',
                      width: 170,
                      height: 170,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Loading...',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/Nothing founded.json',
                  width: 300,
                  height: 300,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 4),
                Text(
                  'No properties found within ${_currentSearchRadiusKm}km radius.',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: _filteredProperties.map((prop) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: PropertyCard(
            property: prop,
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
  final VoidCallback onTap;

  const PropertyCard({super.key, required this.property, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Iconsax.image, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                if (property.reviewCount > 0)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Iconsax.star1, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            property.averageRating.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            ' (${property.reviewCount})',
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      property.type,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                if (!property.isAvailable)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        'Not Available',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
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
                  // Title and Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          property.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        property.price,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Location
                  Row(
                    children: [
                      const Icon(
                        Iconsax.location5,
                        color: Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          property.locationStr,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
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
                          child: _buildTag(tag),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  const SizedBox(height: 14),
                  // Bottom Row (Beds, Baths, Area)
                  if (property.type == 'PG')
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildBottomInfo(Iconsax.moon5, property.beds),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14.0),
                            child: Container(
                              height: 16,
                              width: 1,
                              color: Colors.grey.shade300,
                            ),
                          ),
                          _buildBottomInfo(Iconsax.drop, property.baths),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14.0),
                            child: Container(
                              height: 16,
                              width: 1,
                              color: Colors.grey.shade300,
                            ),
                          ),
                          _buildBottomInfo(Iconsax.maximize4, property.area),
                        ],
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildBottomInfo(Iconsax.moon5, property.beds),
                        Container(
                          height: 16,
                          width: 1,
                          color: Colors.grey.shade300,
                        ),
                        _buildBottomInfo(Iconsax.drop, property.baths),
                        Container(
                          height: 16,
                          width: 1,
                          color: Colors.grey.shade300,
                        ),
                        _buildBottomInfo(Iconsax.maximize4, property.area),
                      ],
                    ),
                  if (property.type == 'PG' && 
                     ((property.perDayWithFood != null && property.perDayWithFood!.isNotEmpty) || 
                      (property.perDayWithoutFood != null && property.perDayWithoutFood!.isNotEmpty)))
                    Column(
                      children: [
                        const SizedBox(height: 14),
                        const Divider(height: 1, color: Color(0xFFEEEEEE)),
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
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
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
                                color: Colors.grey.shade300,
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
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
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

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildBottomInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: Colors.grey.shade600,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                      color: Colors.white.withValues(alpha: 0.8),
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
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              colors: const [
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
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEBEBF2),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
