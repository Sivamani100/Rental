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
  final Map<String, dynamic>? foodMenu;
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

  // Partner & Owner Management
  final String? partnerId;
  final String? partnerEmail;
  final String? partnerRole;
  final int viewsCount;

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
    this.foodMenu,
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
    this.partnerId,
    this.partnerEmail,
    this.partnerRole,
    this.viewsCount = 0,
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

  static String? _sanitize(dynamic value) {
    if (value == null) return null;
    if (value is! String) return value.toString();
    return value
        .replaceAll('â‚¹', '₹')
        .replaceAll('â€¢', '•')
        .replaceAll('â€”', '—')
        .replaceAll('â”€', '─');
  }

  factory PropertyModel.fromJson(Map<String, dynamic> json) {
    String? pEmail = json['partner_email']?.toString();
    String? pId = json['partner_id']?.toString();
    String? pRole = json['partner_role']?.toString();

    final tagsList = List<String>.from((json['tags'] ?? []).map((t) => _sanitize(t)));
    if (pEmail == null || pEmail.isEmpty) {
      for (var t in tagsList) {
        if (t.toLowerCase().startsWith('partner:')) {
          pEmail = t.substring('partner:'.length).trim();
          pId ??= pEmail;
        } else if (t.toLowerCase().startsWith('partner_role:')) {
          pRole ??= t.substring('partner_role:'.length).trim();
        }
      }
    }

    return PropertyModel(
      id: json['id']?.toString(),
      title: _sanitize(json['title']) ?? '',
      price: _sanitize(json['price']) ?? '',
      locationStr: _sanitize(json['location_str']) ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? double.tryParse(json['latitude']?.toString() ?? '') ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? double.tryParse(json['longitude']?.toString() ?? '') ?? 0.0,
      imageUrls: (json['image_urls'] as List?)?.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList() ?? [],
      tags: tagsList,
      beds: _sanitize(json['beds']) ?? '',
      baths: _sanitize(json['baths']) ?? '',
      area: _sanitize(json['area']) ?? '',
      type: _sanitize(json['type']) ?? 'Rental',
      ownerPhone: _sanitize(json['owner_phone']) ?? '',
      ownerWhatsapp: _sanitize(json['owner_whatsapp']) ?? '',
      features: (json['features'] as List?)?.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList() ?? [],
      isAvailable: json['is_available'] ?? true,
      status: json['status']?.toString() ?? 'pending',
      securityDeposit: _sanitize(json['security_deposit']),
      maintenanceCharges: _sanitize(json['maintenance_charges']),
      reviews: json['reviews'] != null ? List<dynamic>.from(json['reviews']) : [],
      suggestedPhotos: json['suggested_photos'] != null ? List<dynamic>.from(json['suggested_photos']) : [],
      noticePeriod: _sanitize(json['notice_period']),
      agreementDuration: _sanitize(json['agreement_duration']),
      description: _sanitize(json['description']) ?? '',
      perDayWithFood: _sanitize(json['per_day_with_food']),
      perDayWithoutFood: _sanitize(json['per_day_without_food']),
      foodMenu: json['food_menu'] != null ? Map<String, dynamic>.from(json['food_menu']) : null,
      genderPreference: _sanitize(json['gender_preference']),
      sharingType: _sanitize(json['sharing_type']),
      foodDetails: _sanitize(json['food_details']),
      foodQuality: _sanitize(json['food_quality']),
      drinkingWater: _sanitize(json['drinking_water']),
      waterSupply: _sanitize(json['water_supply']),
      powerBackup: _sanitize(json['power_backup']),
      acType: _sanitize(json['ac_type']),
      bathroomType: _sanitize(json['bathroom_type']),
      cleanlinessInfo: _sanitize(json['cleanliness_info']),
      securityInfo: _sanitize(json['security_info']),
      verificationPolicy: _sanitize(json['verification_policy']),
      managementInfo: _sanitize(json['management_info']),
      gateRules: _sanitize(json['gate_rules']),
      bhkType: _sanitize(json['bhk_type']),
      furnishingStatus: _sanitize(json['furnishing_status']),
      plumbingStatus: _sanitize(json['plumbing_status']),
      seepageStatus: _sanitize(json['seepage_status']),
      electricalStatus: _sanitize(json['electrical_status']),
      meterStatus: _sanitize(json['meter_status']),
      billsInfo: _sanitize(json['bills_info']),
      tenantPreference: _sanitize(json['tenant_preference']),
      petPolicy: _sanitize(json['pet_policy']),
      parkingInfo: _sanitize(json['parking_info']),
      partnerId: pId,
      partnerEmail: pEmail,
      partnerRole: pRole,
      viewsCount: (json['views_count'] as num?)?.toInt() ?? (json['views'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    // If partner details are attached, ensure partner tag is in tags array
    final outTags = List<String>.from(tags);
    if (partnerEmail != null && partnerEmail!.isNotEmpty) {
      final tagVal = 'partner:${partnerEmail!.toLowerCase().trim()}';
      if (!outTags.any((t) => t.toLowerCase() == tagVal)) {
        outTags.add(tagVal);
      }
      if (partnerRole != null && partnerRole!.isNotEmpty) {
        final roleVal = 'partner_role:$partnerRole';
        if (!outTags.any((t) => t.toLowerCase() == roleVal)) {
          outTags.add(roleVal);
        }
      }
    }

    return {
      'title': title,
      'price': price,
      'location_str': locationStr,
      'latitude': latitude,
      'longitude': longitude,
      'image_urls': imageUrls,
      'tags': outTags,
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
      'food_menu': foodMenu,
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
      'views_count': viewsCount,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PropertyModel) return false;
    if (id != null && other.id != null) {
      return id == other.id;
    }
    return title == other.title && price == other.price && locationStr == other.locationStr;
  }

  @override
  int get hashCode => (id != null) ? id.hashCode : Object.hash(title, price, locationStr);
}
