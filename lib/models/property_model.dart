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
  final String? furnishingStatus; // Unfurnished, Semi-Furnished, Fully-Furnished
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
