import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

/// Service that monitors device connectivity and notifies listeners of online/offline status.
class NetworkStatusService with ChangeNotifier, WidgetsBindingObserver {
  NetworkStatusService._() {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  static final NetworkStatusService instance = NetworkStatusService._();

  bool _isOnline = true;
  bool _justReconnected = false;
  Timer? _pollingTimer;
  Timer? _reconnectedTimer;

  bool get isOnline => _isOnline;
  bool get justReconnected => _justReconnected;

  void _init() {
    checkNow();
    _scheduleNextCheck();
  }

  void _scheduleNextCheck() {
    _pollingTimer?.cancel();
    final interval = _isOnline ? const Duration(seconds: 5) : const Duration(seconds: 3);
    _pollingTimer = Timer(interval, () async {
      await checkNow();
      _scheduleNextCheck();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkNow();
    }
  }

  /// Explicitly reports a network failure from anywhere in the app
  void reportFailure() {
    _updateStatus(false);
  }

  /// Explicitly reports a network success from anywhere in the app
  void reportSuccess() {
    _updateStatus(true);
  }

  /// Check connectivity by attempting a fast lightweight ping
  Future<bool> checkConnectivity() async {
    if (kIsWeb) {
      try {
        final res = await http.head(Uri.parse('https://dns.google')).timeout(const Duration(seconds: 3));
        return res.statusCode > 0;
      } catch (_) {
        return false;
      }
    } else {
      try {
        final socket = await Socket.connect('8.8.8.8', 53, timeout: const Duration(seconds: 2));
        socket.destroy();
        return true;
      } catch (_) {
        try {
          final socket2 = await Socket.connect('1.1.1.1', 53, timeout: const Duration(seconds: 2));
          socket2.destroy();
          return true;
        } catch (_) {
          return false;
        }
      }
    }
  }

  Future<void> checkNow() async {
    final online = await checkConnectivity();
    _updateStatus(online);
  }

  void _updateStatus(bool online) {
    if (_isOnline == online) return;

    if (!online) {
      _isOnline = false;
      _justReconnected = false;
      _reconnectedTimer?.cancel();
      notifyListeners();
    } else {
      _isOnline = true;
      _justReconnected = true;
      notifyListeners();

      _reconnectedTimer?.cancel();
      _reconnectedTimer = Timer(const Duration(milliseconds: 2600), () {
        _justReconnected = false;
        notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    _reconnectedTimer?.cancel();
    super.dispose();
  }
}
