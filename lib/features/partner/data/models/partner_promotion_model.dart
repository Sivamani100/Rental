class PartnerPromotionModel {
  final String id;
  final String propertyId;
  final String propertyTitle;
  final String? propertyLocation;
  final String? propertyImage;
  final String type; // 'in_app' or 'external'
  final String packageName;
  final int durationDays;
  final String price;
  final DateTime startDate;
  final DateTime endDate;
  final int impressions;
  final int clicks;
  final int inquiries;
  final String status; // 'pending', 'approved', 'active', 'rejected', 'completed'
  final int priorityPosition; // 1, 2, 3...
  final double radiusKm;
  final List<String> channels;

  PartnerPromotionModel({
    required this.id,
    required this.propertyId,
    required this.propertyTitle,
    this.propertyLocation,
    this.propertyImage,
    required this.type,
    required this.packageName,
    required this.durationDays,
    required this.price,
    required this.startDate,
    required this.endDate,
    this.impressions = 0,
    this.clicks = 0,
    this.inquiries = 0,
    this.status = 'pending',
    this.priorityPosition = 1,
    this.radiusKm = 5.0,
    this.channels = const [],
  });

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isRejected => status.toLowerCase() == 'rejected';
  bool get isApproved => status.toLowerCase() == 'approved' || status.toLowerCase() == 'active';

  bool get isActive {
    if (!isApproved) return false;
    final nowUtc = DateTime.now().toUtc();
    final endUtc = endDate.toUtc();
    return nowUtc.isBefore(endUtc.add(const Duration(hours: 1)));
  }

  int get daysRemaining {
    final now = DateTime.now();
    if (now.isAfter(endDate)) return 0;
    return endDate.difference(now).inDays + 1;
  }

  double get progressPercent {
    final total = endDate.difference(startDate).inSeconds;
    if (total <= 0) return 1.0;
    final elapsed = DateTime.now().difference(startDate).inSeconds;
    if (elapsed <= 0) return 0.0;
    if (elapsed >= total) return 1.0;
    return elapsed / total;
  }

  factory PartnerPromotionModel.fromJson(Map<String, dynamic> json) {
    return PartnerPromotionModel(
      id: json['id']?.toString() ?? '',
      propertyId: json['property_id']?.toString() ?? '',
      propertyTitle: json['property_title']?.toString() ?? '',
      propertyLocation: json['property_location']?.toString(),
      propertyImage: json['property_image']?.toString(),
      type: json['promotion_type']?.toString() ?? json['type']?.toString() ?? 'in_app',
      packageName: json['package_name']?.toString() ?? 'Spotlight',
      durationDays: json['duration_days'] != null
          ? int.tryParse(json['duration_days'].toString()) ?? 7
          : 7,
      price: json['price']?.toString() ?? 'Free',
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'].toString()) ?? DateTime.now().add(const Duration(days: 7))
          : DateTime.now().add(const Duration(days: 7)),
      impressions: json['impressions_count'] != null
          ? int.tryParse(json['impressions_count'].toString()) ?? 0
          : (json['impressions'] != null ? int.tryParse(json['impressions'].toString()) ?? 0 : 0),
      clicks: json['clicks_count'] != null
          ? int.tryParse(json['clicks_count'].toString()) ?? 0
          : (json['clicks'] != null ? int.tryParse(json['clicks'].toString()) ?? 0 : 0),
      inquiries: json['inquiries_count'] != null
          ? int.tryParse(json['inquiries_count'].toString()) ?? 0
          : (json['inquiries'] != null ? int.tryParse(json['inquiries'].toString()) ?? 0 : 0),
      status: json['status']?.toString() ?? 'pending',
      priorityPosition: json['priority_position'] != null
          ? int.tryParse(json['priority_position'].toString()) ?? 1
          : 1,
      radiusKm: json['radius_km'] != null
          ? double.tryParse(json['radius_km'].toString()) ?? 5.0
          : 5.0,
      channels: json['channels'] != null
          ? List<String>.from(json['channels'])
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'property_id': propertyId,
      'property_title': propertyTitle,
      'property_location': propertyLocation,
      'property_image': propertyImage,
      'promotion_type': type,
      'package_name': packageName,
      'duration_days': durationDays,
      'price': price,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'impressions_count': impressions,
      'clicks_count': clicks,
      'inquiries_count': inquiries,
      'status': status,
      'priority_position': priorityPosition,
      'radius_km': radiusKm,
      'channels': channels,
    };
  }
}
