import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rental/features/partner/data/models/partner_notification_model.dart';

class PartnerNotificationService extends ChangeNotifier {
  static final PartnerNotificationService instance = PartnerNotificationService._internal();
  PartnerNotificationService._internal() {
    _loadNotifications();
  }

  static const String _storageKey = 'partner_notifications_cache_v1';
  final List<PartnerNotificationModel> _notifications = [];

  List<PartnerNotificationModel> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        _notifications.clear();
        for (final item in decoded) {
          _notifications.add(PartnerNotificationModel.fromJson(Map<String, dynamic>.from(item)));
        }
      } else {
        _seedInitialNotifications();
        await _saveNotifications();
      }
    } catch (e) {
      debugPrint('Error loading partner notifications: $e');
      if (_notifications.isEmpty) {
        _seedInitialNotifications();
      }
    } finally {
      notifyListeners();
    }
  }

  void _seedInitialNotifications() {
    final now = DateTime.now();
    _notifications.addAll([
      PartnerNotificationModel(
        id: 'notif_1',
        title: 'New Tenant Inquiry Received',
        message: 'Rahul Sharma sent an inquiry with a visit request for Skyline 2BHK Luxury Apartment.',
        type: PartnerNotificationType.inquiry,
        createdAt: now.subtract(const Duration(minutes: 8)),
        isRead: false,
        propertyName: 'Skyline 2BHK Luxury Apartment',
        actionLabel: 'View Inquiry',
      ),
      PartnerNotificationModel(
        id: 'notif_2',
        title: 'Property Claim Approved! 🎉',
        message: 'Admin team has verified and approved your ownership claim for Green Valley Villa. Full landlord controls enabled.',
        type: PartnerNotificationType.claimAdmin,
        createdAt: now.subtract(const Duration(hours: 2, minutes: 15)),
        isRead: false,
        propertyName: 'Green Valley Villa',
        actionLabel: 'Manage Property',
      ),
      PartnerNotificationModel(
        id: 'notif_3',
        title: 'Promotion Campaign Live 🚀',
        message: 'Your "Locality Push Blast" promotion is now broadcasting to tenants in your area. Now active and pinned in top search ranking.',
        type: PartnerNotificationType.promotion,
        createdAt: now.subtract(const Duration(hours: 5)),
        isRead: false,
        propertyName: 'Sunset View Residence',
        actionLabel: 'Track Performance',
      ),
      PartnerNotificationModel(
        id: 'notif_4',
        title: 'Monthly Rent Payout Processed',
        message: '₹28,500 has been credited to your registered account for Flat 402, Royal Palms.',
        type: PartnerNotificationType.payment,
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
        isRead: true,
        propertyName: 'Royal Palms Unit 402',
        actionLabel: 'View Statement',
      ),
      PartnerNotificationModel(
        id: 'notif_5',
        title: 'High Tenant Search Surge 📈',
        message: 'Tenant search traffic in your locality jumped 42% this week. Ensure your listings are available to get instant leads.',
        type: PartnerNotificationType.system,
        createdAt: now.subtract(const Duration(days: 2)),
        isRead: true,
        actionLabel: 'View Analytics',
      ),
    ]);
  }

  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_notifications.map((n) => n.toJson()).toList());
      await prefs.setString(_storageKey, data);
    } catch (e) {
      debugPrint('Error saving partner notifications: $e');
    }
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index].isRead = true;
      _saveNotifications();
      notifyListeners();
    }
  }

  void markAllAsRead() {
    bool changed = false;
    for (final notif in _notifications) {
      if (!notif.isRead) {
        notif.isRead = true;
        changed = true;
      }
    }
    if (changed) {
      _saveNotifications();
      notifyListeners();
    }
  }

  void deleteNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    _saveNotifications();
    notifyListeners();
  }

  void clearAll() {
    _notifications.clear();
    _saveNotifications();
    notifyListeners();
  }

  void addNotification(PartnerNotificationModel notif) {
    _notifications.insert(0, notif);
    _saveNotifications();
    notifyListeners();
  }

  void simulateNewPushNotification() {
    final now = DateTime.now();
    final newNotif = PartnerNotificationModel(
      id: 'sim_${now.millisecondsSinceEpoch}',
      title: 'New Lead: Direct Phone Inquiry',
      message: 'A prospective tenant just tapped "Call Landlord" on your featured listing.',
      type: PartnerNotificationType.inquiry,
      createdAt: now,
      isRead: false,
      propertyName: 'Skyline 2BHK Luxury Apartment',
      actionLabel: 'Call Back',
    );
    addNotification(newNotif);
  }
}
