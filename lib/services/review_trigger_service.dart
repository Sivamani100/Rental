import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Background Tracking Service that manages Google Play In-App Reviews with progressive retries.
///
/// Multi-Tier Escalation Schedule:
/// - Stage 0: 5 minutes (300 seconds)
/// - Stage 1: 15 minutes (900 seconds)
/// - Stage 2: 30 minutes (1800 seconds)
/// - Stage 3: 60 minutes (3600 seconds)
/// - Stage 4+: Every additional 30 minutes
///
/// Features:
/// 1. Continuous Active Usage Tracker: Accurately accumulates active usage time across app sessions.
/// 2. Progressive Escalation: Automatically advances to next time milestone if review wasn't submitted yet.
/// 3. Lifecycle Security: Pauses timer when app is backgrounded (`paused`, `inactive`).
/// 4. Error Resiliency: Gracefully handles unsupported environments without crashing.
class ReviewTriggerService with WidgetsBindingObserver {
  ReviewTriggerService._();
  static final ReviewTriggerService instance = ReviewTriggerService._();

  static const String _keyAccumulatedSeconds = 'accumulated_usage_seconds_v2';
  static const String _keyStage = 'review_prompt_stage_v2';

  Timer? _timer;
  int _accumulatedSeconds = 0;
  int _stage = 0;
  bool _isInitialized = false;

  int get accumulatedSeconds => _accumulatedSeconds;
  int get stage => _stage;
  int get currentTargetSeconds => getTargetSecondsForStage(_stage);

  /// Calculates target active usage seconds for the given escalation stage
  static int getTargetSecondsForStage(int stageIndex) {
    switch (stageIndex) {
      case 0:
        return 300; // 5 minutes
      case 1:
        return 900; // 15 minutes
      case 2:
        return 1800; // 30 minutes
      case 3:
        return 3600; // 60 minutes
      default:
        return 3600 + (stageIndex - 3) * 1800; // Every +30 minutes
    }
  }

  /// Initializes usage tracking and starts lifecycle monitoring.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _accumulatedSeconds = prefs.getInt(_keyAccumulatedSeconds) ?? 0;
      _stage = prefs.getInt(_keyStage) ?? 0;

      final target = getTargetSecondsForStage(_stage);
      debugPrint('⭐️ [ReviewTriggerService] Loaded state — Usage: ${_accumulatedSeconds}s / ${target}s (${(target / 60).round()}m target), Stage: $_stage');

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
    if (state == AppLifecycleState.resumed) {
      debugPrint('▶️ [ReviewTriggerService] App Resumed — Restarting progressive usage tracker timer.');
      _startActiveTimer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      debugPrint('⏸️ [ReviewTriggerService] App Backgrounded — Pausing progressive usage tracker timer.');
      _stopActiveTimer();
    }
  }

  /// Starts the 10-second tick timer while app is active in foreground
  void _startActiveTimer() {
    if (_timer != null) return;

    _timer = Timer.periodic(const Duration(seconds: 10), (_) async {
      _accumulatedSeconds += 10;
      final target = getTargetSecondsForStage(_stage);
      debugPrint('⏱️ [ReviewTriggerService] Active usage: ${_accumulatedSeconds}s / ${target}s (Stage $_stage)');

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_keyAccumulatedSeconds, _accumulatedSeconds);
      } catch (e) {
        debugPrint('Error saving usage seconds: $e');
      }

      if (_accumulatedSeconds >= target) {
        debugPrint('🎉 [ReviewTriggerService] Reached milestone of ${target}s! Triggering review dialog for Stage $_stage...');
        
        // Advance stage immediately to prepare for next milestone (15m, 30m, 60m...)
        _stage += 1;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(_keyStage, _stage);
        } catch (e) {
          debugPrint('Error saving review stage: $e');
        }

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
    try {
      final InAppReview inAppReview = InAppReview.instance;
      final isAvailable = await inAppReview.isAvailable();

      debugPrint('🔍 [ReviewTriggerService] Is InAppReview Available: $isAvailable');

      if (isAvailable) {
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
    _stage = 0;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAccumulatedSeconds);
      await prefs.remove(_keyStage);
      debugPrint('🔄 [ReviewTriggerService] State reset for testing! Stage reset to 0 (5-min target).');
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
