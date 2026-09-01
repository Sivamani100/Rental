import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'notification_broadcast_service.dart';

class PushNotificationService {
  static final PushNotificationService instance = PushNotificationService._internal();
  PushNotificationService._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<void> init() async {
    try {
      if (Firebase.apps.isEmpty) return;

      // Enable foreground notification presentation options
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Handle when the user taps on a notification and the app is in background but opened
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleMessage(message);
      });

      // Handle when the user taps on a notification and the app was completely terminated
      final RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleMessage(initialMessage);
        });
      }
    } catch (e) {
      // Ignore init errors
    }
  }

  void _handleMessage(RemoteMessage message) {
    if (message.data.isNotEmpty) {
      try {
        final notifModel = BroadcastNotificationModel.fromJson(message.data);
        _navigateWithModel(notifModel);
      } catch (e) {
        // Ignore parse errors
      }
    }
  }

  void _navigateWithModel(BroadcastNotificationModel notifModel, {int retries = 10}) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      NotificationBroadcastService.instance.handleNotificationNavigation(context, notifModel);
    } else if (retries > 0) {
      Future.delayed(const Duration(milliseconds: 200), () {
        _navigateWithModel(notifModel, retries: retries - 1);
      });
    }
  }
}
