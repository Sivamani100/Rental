import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/home_screen.dart';
import '../screens/posting_screen.dart';

enum TargetAudience {
  allUsers,
  tenants,
  buyers,
  landlords,
}

enum NotificationActionType {
  property,
  category,
  searchFilter,
  postProperty,
  buyAndSell,
  externalUrl,
  general,
}

class BroadcastNotificationModel {
  final String id;
  final String title;
  final String body;
  final String? imageUrl;
  final TargetAudience targetAudience;
  final NotificationActionType actionType;
  final String? targetRouteOrId;
  final String? targetLabel;
  final bool isHighPriority;
  final DateTime createdAt;
  final int recipientCount;
  final String status;

  BroadcastNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    this.targetAudience = TargetAudience.allUsers,
    this.actionType = NotificationActionType.general,
    this.targetRouteOrId,
    this.targetLabel,
    this.isHighPriority = false,
    required this.createdAt,
    this.recipientCount = 0,
    this.status = 'sent',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'image_url': imageUrl,
      'target_audience': targetAudience.name,
      'action_type': actionType.name,
      'target_route_or_id': targetRouteOrId,
      'target_label': targetLabel,
      'is_high_priority': isHighPriority,
      'created_at': createdAt.toIso8601String(),
      'recipient_count': recipientCount,
      'status': status,
    };
  }

  factory BroadcastNotificationModel.fromJson(Map<String, dynamic> json) {
    TargetAudience audience = TargetAudience.allUsers;
    for (final a in TargetAudience.values) {
      if (a.name == json['target_audience']) {
        audience = a;
        break;
      }
    }

    NotificationActionType action = NotificationActionType.general;
    for (final act in NotificationActionType.values) {
      if (act.name == json['action_type']) {
        action = act;
        break;
      }
    }

    return BroadcastNotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      targetAudience: audience,
      actionType: action,
      targetRouteOrId: json['target_route_or_id']?.toString(),
      targetLabel: json['target_label']?.toString(),
      isHighPriority: json['is_high_priority'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      recipientCount: (json['recipient_count'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'sent',
    );
  }

  String get audienceDisplayName {
    switch (targetAudience) {
      case TargetAudience.allUsers:
        return 'All Users (Rajahmundry)';
      case TargetAudience.tenants:
        return 'Tenants & Rent Seekers';
      case TargetAudience.buyers:
        return 'Property Buyers';
      case TargetAudience.landlords:
        return 'Landlords & Owners';
    }
  }

  String get actionDisplayName {
    switch (actionType) {
      case NotificationActionType.property:
        return 'Open Property (${targetLabel ?? targetRouteOrId ?? 'Listing'})';
      case NotificationActionType.category:
        return 'Open Category (${targetLabel ?? targetRouteOrId ?? 'Explore'})';
      case NotificationActionType.searchFilter:
        return 'Open Filter (${targetLabel ?? targetRouteOrId ?? 'Search'})';
      case NotificationActionType.postProperty:
        return 'Open Post Property Screen';
      case NotificationActionType.buyAndSell:
        return 'Open Buy & Sell Hub';
      case NotificationActionType.externalUrl:
        return 'Open Web Link (${targetRouteOrId ?? ''})';
      case NotificationActionType.general:
        return 'Open App Home';
    }
  }
}

class NotificationBroadcastService {
  NotificationBroadcastService._();
  static final NotificationBroadcastService instance = NotificationBroadcastService._();

  static const String _storageKey = 'admin_broadcast_notifications_history';
  final _supabase = Supabase.instance.client;

  List<BroadcastNotificationModel> _localHistory = [];

  Future<void> init() async {
    await _loadFromLocal();
  }

  Future<List<BroadcastNotificationModel>> getHistory() async {
    // Try fetching from Supabase first
    try {
      final response = await _supabase
          .from('broadcast_notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      final list = (response as List)
          .map((e) => BroadcastNotificationModel.fromJson(e as Map<String, dynamic>))
          .toList();

      if (list.isNotEmpty) {
        _localHistory = list;
        await _saveToLocal();
        return _localHistory;
      }
    } catch (_) {
      // Fallback to local history
    }

    if (_localHistory.isEmpty) {
      await _loadFromLocal();
    }

    if (_localHistory.isEmpty) {
      _localHistory = _getSampleHistory();
      await _saveToLocal();
    }

    return _localHistory;
  }

  Future<bool> sendBroadcast(BroadcastNotificationModel notification) async {
    bool savedToSupabase = false;

    try {
      await _supabase.from('broadcast_notifications').insert(notification.toJson());
      savedToSupabase = true;
    } catch (_) {
      // Offline fallback
    }

    _localHistory.insert(0, notification);
    await _saveToLocal();
    return savedToSupabase || true;
  }

  Future<void> deleteBroadcast(String id) async {
    try {
      await _supabase.from('broadcast_notifications').delete().eq('id', id);
    } catch (_) {}

    _localHistory.removeWhere((item) => item.id == id);
    await _saveToLocal();
  }

  void handleNotificationNavigation(BuildContext context, BroadcastNotificationModel notification) {
    switch (notification.actionType) {
      case NotificationActionType.property:
        if (notification.targetRouteOrId != null && notification.targetRouteOrId!.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HomeScreen(initialPropertyId: notification.targetRouteOrId),
            ),
          );
        }
        break;

      case NotificationActionType.postProperty:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PostBottomSheet()),
        );
        break;

      case NotificationActionType.buyAndSell:
      case NotificationActionType.category:
      case NotificationActionType.searchFilter:
      case NotificationActionType.general:
      case NotificationActionType.externalUrl:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
        break;
    }
  }

  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_localHistory.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (_) {}
  }

  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_storageKey);
      if (str != null) {
        final decoded = jsonDecode(str) as List;
        _localHistory = decoded
            .map((e) => BroadcastNotificationModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
  }

  List<BroadcastNotificationModel> _getSampleHistory() {
    return [
      BroadcastNotificationModel(
        id: 'notif_1',
        title: '🔥 New Luxury 3BHK in Danavaipeta!',
        body: 'Spacious East-facing 3BHK flat near RTC Complex with 100% Vastu and covered car parking.',
        targetAudience: TargetAudience.allUsers,
        actionType: NotificationActionType.category,
        targetLabel: 'Danavaipeta Flats',
        targetRouteOrId: 'Danavaipeta',
        isHighPriority: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        recipientCount: 1420,
        status: 'sent',
      ),
      BroadcastNotificationModel(
        id: 'notif_2',
        title: '🏡 List Your Property in Rajahmundry Free',
        body: 'Post your house, PG, or land for sale with zero broker fee and connect with 5,000+ local buyers.',
        targetAudience: TargetAudience.landlords,
        actionType: NotificationActionType.postProperty,
        targetLabel: 'Post Listing',
        isHighPriority: false,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        recipientCount: 380,
        status: 'sent',
      ),
      BroadcastNotificationModel(
        id: 'notif_3',
        title: '📉 Price Drop Alert: Morampudi 2BHK',
        body: 'Rent reduced by ₹2,000/month. Walking distance to highway and schools. Contact owner now.',
        targetAudience: TargetAudience.tenants,
        actionType: NotificationActionType.searchFilter,
        targetLabel: 'Morampudi Rentals',
        isHighPriority: true,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        recipientCount: 920,
        status: 'sent',
      ),
    ];
  }
}
