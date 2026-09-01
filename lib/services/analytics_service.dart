import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._internal();
  AnalyticsService._internal();

  final _supabase = Supabase.instance.client;
  String? _deviceId;
  String? _fcmToken;
  String? _ipAddress;

  Future<void> init() async {
    try {
      if (Firebase.apps.isEmpty) {
        if (kIsWeb) {
          await Firebase.initializeApp(
            options: const FirebaseOptions(
              apiKey: 'AIzaSyBxP9pherG9E44m0Nzqm-eQmA066kvUG28',
              appId: '1:1045370324281:android:55dc0aca49e69a1bcdd4e8',
              messagingSenderId: '1045370324281',
              projectId: 'rental-67032',
              storageBucket: 'rental-67032.firebasestorage.app',
            ),
          );
        } else {
          await Firebase.initializeApp();
        }
      }
      
      // Request permission for push notifications
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      _deviceId = await _getDeviceId();
      _fcmToken = await messaging.getToken();
      _ipAddress = await _getIpAddress();

      // Listen for token refreshes
      messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _registerDevice();
      });

      if (_deviceId != null && _fcmToken != null) {
        await _registerDevice();
      }
    } catch (e) {
      print('AnalyticsService init error: $e');
    }
  }

  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('device_id');
    if (id != null && id.isNotEmpty && !id.startsWith('TP1A') && !id.startsWith('UP1A') && !id.startsWith('SP1A')) {
      return id;
    }

    final deviceInfo = DeviceInfoPlugin();
    String uniqueKey = '';

    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        uniqueKey = (webInfo.vendor ?? '') + (webInfo.userAgent ?? '');
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Use fingerprint + id or fallback to random UUID
        uniqueKey = androidInfo.fingerprint;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        uniqueKey = iosInfo.identifierForVendor ?? '';
      }
    } catch (_) {}

    // Combine with timestamp & random token to guarantee absolute uniqueness across all devices
    id = 'dev_${DateTime.now().millisecondsSinceEpoch}_${uniqueKey.hashCode.abs()}';
    await prefs.setString('device_id', id);
    return id;
  }

  Future<String?> _getIpAddress() async {
    try {
      final response = await http.get(Uri.parse('https://api.ipify.org?format=json')).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['ip'];
      }
    } catch (_) {}
    return null;
  }

  Future<void> _registerDevice() async {
    if (_deviceId == null || _fcmToken == null) return;
    
    try {
      await _supabase.from('devices').upsert({
        'device_id': _deviceId,
        'fcm_token': _fcmToken,
        'ip_address': _ipAddress,
        'last_active': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Register device error: $e');
    }
  }

  Future<void> logPropertyView(String propertyId, String? category) async {
    await _logEvent('view', category: category, itemId: propertyId);
  }

  Future<void> logSearch(String query, {String? category}) async {
    await _logEvent('search', category: category, itemId: query); // Using itemId to store the query temporarily
  }
  
  Future<void> logCategoryClick(String category) async {
    await _logEvent('category_click', category: category);
  }

  Future<void> _logEvent(String eventType, {String? category, String? itemId}) async {
    if (_deviceId == null) return;

    try {
      // Update last active
      _supabase.from('devices').update({
        'last_active': DateTime.now().toIso8601String()
      }).eq('device_id', _deviceId as Object);

      await _supabase.from('analytics_events').insert({
        'device_id': _deviceId,
        'event_type': eventType,
        'category': category,
        'item_id': itemId,
      });
    } catch (e) {
      print('Log event error: $e');
    }
  }
}
