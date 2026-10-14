class PartnerHandoverRequest {
  final String id;
  final String partnerId;
  final String partnerName;
  final String partnerEmail;
  final String partnerPhone;
  final String propertyId;
  final String propertyTitle;
  final String? propertyLocation;
  final String? propertyImage;
  final String role; // 'Direct Property Owner' or 'Dealer / Property Manager'
  final String note;
  String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;
  DateTime? reviewedAt;
  String? reviewedBy;

  PartnerHandoverRequest({
    required this.id,
    required this.partnerId,
    required this.partnerName,
    required this.partnerEmail,
    required this.partnerPhone,
    required this.propertyId,
    required this.propertyTitle,
    this.propertyLocation,
    this.propertyImage,
    required this.role,
    required this.note,
    this.status = 'pending',
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
  });

  factory PartnerHandoverRequest.fromJson(Map<String, dynamic> json) {
    return PartnerHandoverRequest(
      id: json['id']?.toString() ?? '',
      partnerId: json['partner_id']?.toString() ?? '',
      partnerName: json['partner_name']?.toString() ?? 'Partner',
      partnerEmail: json['partner_email']?.toString() ?? '',
      partnerPhone: json['partner_phone']?.toString() ?? '',
      propertyId: json['property_id']?.toString() ?? '',
      propertyTitle: json['property_title']?.toString() ?? 'Property',
      propertyLocation: json['property_location']?.toString(),
      propertyImage: json['property_image']?.toString(),
      role: json['role']?.toString() ?? 'Direct Property Owner',
      note: json['note']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() 
          : DateTime.now(),
      reviewedAt: json['reviewed_at'] != null 
          ? DateTime.tryParse(json['reviewed_at'].toString()) 
          : null,
      reviewedBy: json['reviewed_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'partner_id': partnerId,
      'partner_name': partnerName,
      'partner_email': partnerEmail,
      'partner_phone': partnerPhone,
      'property_id': propertyId,
      'property_title': propertyTitle,
      'property_location': propertyLocation,
      'property_image': propertyImage,
      'role': role,
      'note': note,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      if (reviewedAt != null) 'reviewed_at': reviewedAt!.toIso8601String(),
      if (reviewedBy != null) 'reviewed_by': reviewedBy,
    };
  }
}

class PartnerProfile {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role; // 'Direct Property Owner' or 'Dealer / Property Manager'
  final DateTime createdAt;

  PartnerProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.createdAt,
  });

  factory PartnerProfile.fromJson(Map<String, dynamic> json) {
    return PartnerProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: json['role']?.toString() ?? 'Direct Property Owner',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
