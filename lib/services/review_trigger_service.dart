import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Background Tracking Service that manages Google Play In-App Reviews.
///
/// Features:
/// 1. Cumulative Active Usage Tracker: Counts 300 seconds (5 minutes) of active app usage across sessions.
/// 2. Lifecycle Security: Pauses timer when app goes to background (`paused`, `inactive`).
/// 3. Play Store Quota Safeguard: Flags `has_prompted_review_v1` so review is requested only ONCE per installation.
/// 4. Error Resiliency: Gracefully handles unsupported devices (iOS, Web, Sideloaded APKs) without UI crashes.
class ReviewTriggerService with WidgetsBindingObserver {
  ReviewTriggerService._();
  static final ReviewTriggerService instance = ReviewTriggerService._();

  static const String _keyAccumulatedSeconds = 'accumulated_usage_seconds_v1';
  static const String _keyHasPrompted = 'has_prompted_review_v1';
  static const int targetUsageSeconds = 300; // 5 Minutes = 300 seconds

  Timer? _timer;
  int _accumulatedSeconds = 0;
  bool _hasPrompted = false;
  bool _isInitialized = false;

  int get accumulatedSeconds => _accumulatedSeconds;
  bool get hasPrompted => _hasPrompted;

  /// Initializes usage tracking and starts lifecycle monitoring.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _accumulatedSeconds = prefs.getInt(_keyAccumulatedSeconds) ?? 0;
      _hasPrompted = prefs.getBool(_keyHasPrompted) ?? false;

      debugPrint('⭐️ [ReviewTriggerService] Loaded state — Accumulated: ${_accumulatedSeconds}s / ${targetUsageSeconds}s, Prompted: $_hasPrompted');

      if (_hasPrompted) return;

      WidgetsBinding.instance.removeObserver(this);
      WidgetsBinding.instance.addObserver(this);

      _startActiveTimer();
    } catch (e) {
      debugPrint('⚠️ [ReviewTriggerService] Error during initialization: $e');
    }
  }

  /// Disposes lifecycle listener and cancels active tracking timer.
  void dispose() {
    _stopActiveTimer();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_hasPrompted) return;

    if (state == AppLifecycleState.resumed) {
      debugPrint('▶️ [ReviewTriggerService] App Resumed — Restarting usage tracker timer.');
      _startActiveTimer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      debugPrint('⏸️ [ReviewTriggerService] App Backgrounded — Pausing usage tracker timer.');
      _stopActiveTimer();
    }
  }

  /// Starts the 10-second tick timer while app is active in foreground
  void _startActiveTimer() {
    if (_hasPrompted || _timer != null) return;

    _timer = Timer.periodic(const Duration(seconds: 10), (_) async {
      _accumulatedSeconds += 10;
      debugPrint('⏱️ [ReviewTriggerService] Active usage: ${_accumulatedSeconds}s / ${targetUsageSeconds}s');

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_keyAccumulatedSeconds, _accumulatedSeconds);
      } catch (e) {
        debugPrint('Error saving usage seconds: $e');
      }

      if (_accumulatedSeconds >= targetUsageSeconds) {
        _stopActiveTimer();
        await requestInAppReview();
      }
    });
  }

  /// Stops and cancels the active tick timer
  void _stopActiveTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Triggers Google Play Native In-App Review Bottom Sheet prompt
  Future<void> requestInAppReview({bool isManualTest = false}) async {
    if (_hasPrompted && !isManualTest) return;

    try {
      final InAppReview inAppReview = InAppReview.instance;
      final isAvailable = await inAppReview.isAvailable();

      debugPrint('🔍 [ReviewTriggerService] Is InAppReview Available: $isAvailable');

      if (isAvailable) {
        // Flag prompted immediately to comply with Play Store rate limits
        _hasPrompted = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyHasPrompted, true);

        debugPrint('🚀 [ReviewTriggerService] Invoking InAppReview.requestReview()');
        await inAppReview.requestReview();
      } else {
        debugPrint('⚠️ [ReviewTriggerService] InAppReview not available on current device/environment.');
        if (isManualTest) {
          // Open Play Store listing fallback if manual trigger on unsupported environment
          await inAppReview.openStoreListing(appStoreId: 'com.arkiolabs.rental');
        }
      }
    } catch (e) {
      debugPrint('❌ [ReviewTriggerService] Failed to launch In-App Review dialog: $e');
    }
  }

  /// Resets tracker state for rapid testing & debugging
  Future<void> resetForTesting() async {
    _stopActiveTimer();
    _accumulatedSeconds = 0;
    _hasPrompted = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAccumulatedSeconds);
      await prefs.remove(_keyHasPrompted);
      debugPrint('🔄 [ReviewTriggerService] State reset for testing! Accumulated usage cleared.');
    } catch (e) {
      debugPrint('Error resetting testing state: $e');
    }

    _startActiveTimer();
  }

  /// Triggers instant review overlay for testing & demonstration
  Future<void> triggerInstantReviewForTesting() async {
    debugPrint('⚡ [ReviewTriggerService] Manual test trigger invoked!');
    await requestInAppReview(isManualTest: true);
  }
}

/// Root Wrapper Component that mounts ReviewTriggerService onto your MaterialApp
class ReviewTriggerWrapper extends StatefulWidget {
  final Widget child;
  const ReviewTriggerWrapper({super.key, required this.child});

  @override
  State<ReviewTriggerWrapper> createState() => _ReviewTriggerWrapperState();
}

class _ReviewTriggerWrapperState extends State<ReviewTriggerWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ReviewTriggerService.instance.initialize();
    });
  }

  @override
  void dispose() {
    ReviewTriggerService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
