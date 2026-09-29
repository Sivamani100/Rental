import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:io' show Platform;

class InstallTracker {
  static const String _storageKey = 'unique_app_install_id';

  static Future<void> initAndTrack() async {
    try {
      // 1. Only track Android app installs (ignore Web, iOS, Windows, etc.)
      if (kIsWeb || !Platform.isAndroid) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString(_storageKey);
      bool isNewInstall = false;

      // 1. Generate ID if it doesn't exist locally
      if (deviceId == null) {
        deviceId = const Uuid().v4();
        await prefs.setString(_storageKey, deviceId);
        isNewInstall = true;
      }

      String platform = 'Android';

      // 3. Sync to Supabase using UPSERT
      // This will insert a new row on first install, and update 'last_opened_at' on subsequent opens.
      await Supabase.instance.client.from('device_installs').upsert(
        {
          'device_id': deviceId,
          'platform': platform,
          'last_opened_at': DateTime.now().toUtc().toIso8601String(),
          if (isNewInstall) 'installed_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'device_id', // Ensures no double-counting if the user opens the app again
      );
    } catch (e) {
      // Silently catch errors so analytics don't crash the user's app experience
      debugPrint('Error tracking install: $e');
    }
  }
}
