enum PartnerNotificationType {
  inquiry,
  claimAdmin,
  promotion,
  payment,
  system,
}

class PartnerNotificationModel {
  final String id;
  final String title;
  final String message;
  final PartnerNotificationType type;
  final DateTime createdAt;
  bool isRead;
  final String? propertyId;
  final String? propertyName;
  final String? actionLabel;
  final String? actionRoute;
  final Map<String, dynamic>? metadata;

  PartnerNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.propertyId,
    this.propertyName,
    this.actionLabel,
    this.actionRoute,
    this.metadata,
  });

  PartnerNotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    PartnerNotificationType? type,
    DateTime? createdAt,
    bool? isRead,
    String? propertyId,
    String? propertyName,
    String? actionLabel,
    String? actionRoute,
    Map<String, dynamic>? metadata,
  }) {
    return PartnerNotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      propertyId: propertyId ?? this.propertyId,
      propertyName: propertyName ?? this.propertyName,
      actionLabel: actionLabel ?? this.actionLabel,
      actionRoute: actionRoute ?? this.actionRoute,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.name,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
      'property_id': propertyId,
      'property_name': propertyName,
      'action_label': actionLabel,
      'action_route': actionRoute,
      'metadata': metadata,
    };
  }

  factory PartnerNotificationModel.fromJson(Map<String, dynamic> json) {
    PartnerNotificationType type;
    try {
      type = PartnerNotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PartnerNotificationType.system,
      );
    } catch (_) {
      type = PartnerNotificationType.system;
    }

    return PartnerNotificationModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: type,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isRead: json['is_read'] as bool? ?? false,
      propertyId: json['property_id'] as String?,
      propertyName: json['property_name'] as String?,
      actionLabel: json['action_label'] as String?,
      actionRoute: json['action_route'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
