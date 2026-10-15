import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SecureLocalStorage extends LocalStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
    ),
  );
  
  const SecureLocalStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async {
    try {
      return await _storage.containsKey(key: supabasePersistSessionKey);
    } catch (e) {
      debugPrint('SecureLocalStorage hasAccessToken error: $e');
      return false;
    }
  }

  @override
  Future<String?> accessToken() async {
    try {
      return await _storage.read(key: supabasePersistSessionKey);
    } catch (e) {
      debugPrint('SecureLocalStorage accessToken error: $e');
      try {
        await _storage.delete(key: supabasePersistSessionKey);
      } catch (_) {}
      return null;
    }
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await _storage.delete(key: supabasePersistSessionKey);
    } catch (e) {
      debugPrint('SecureLocalStorage removePersistedSession error: $e');
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await _storage.write(key: supabasePersistSessionKey, value: persistSessionString);
    } catch (e) {
      debugPrint('SecureLocalStorage persistSession error: $e');
    }
  }
}
