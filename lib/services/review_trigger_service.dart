import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Production-Grade Custom Incremental In-App Review Engine for Google Play.
///
/// Features:
/// 1. Escalating Stage Scheduler:
///    - Stage 1: 5 minutes (300s) active usage -> Prompts review, advances to Stage 2, resets timer to 0.
///    - Stage 2: 15 minutes (900s) active usage -> Prompts review, advances to Stage 3, resets timer to 0.
///    - Stage 3+: 30 minutes (1800s) active usage -> Prompts review every 30m, advances stage, resets timer to 0.
/// 2. Lifecycle Security: Automatically pauses timer in background (`paused`, `inactive`) and resumes in foreground.
/// 3. Permanent Stop Condition (`markReviewAsGiven()`): Halts all tracking permanently when user completes feedback.
/// 4. Dual-Mode Execution:
///    - Production Play Store Builds: Displays native Google Play In-App Review bottom-sheet overlay.
///    - USB Debug Builds (`kDebugMode` / `isManualTest`): Falls back to Store Listing so testing always works.
class ReviewTriggerService with WidgetsBindingObserver {
  ReviewTriggerService._();
  static final ReviewTriggerService instance = ReviewTriggerService._();

  static const String _keyAccumulatedSeconds = 'accumulated_usage_seconds_v2';
  static const String _keyCurrentStage = 'review_current_stage_v2';
  static const String _keyReviewDone = 'review_completely_done_v2';

  Timer? _timer;
  int _accumulatedSeconds = 0;
  int _currentStage = 1;
  bool _reviewCompletelyDone = false;
  bool _isInitialized = false;

  int get accumulatedSeconds => _accumulatedSeconds;
  int get currentStage => _currentStage;
  bool get reviewCompletelyDone => _reviewCompletelyDone;
  int get currentTargetSeconds => getTargetSecondsForStage(_currentStage);

  /// Calculates target active usage seconds for the given escalation stage index
  static int getTargetSecondsForStage(int stageIndex) {
    switch (stageIndex) {
      case 1:
        return 300; // 5 minutes
      case 2:
        return 900; // 15 minutes
      default:
        return 1800; // 30 minutes for Stage 3+
    }
  }

  /// Initializes usage tracking and starts lifecycle monitoring.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _accumulatedSeconds = prefs.getInt(_keyAccumulatedSeconds) ?? 0;
      _currentStage = prefs.getInt(_keyCurrentStage) ?? 1;
      _reviewCompletelyDone = prefs.getBool(_keyReviewDone) ?? false;

      final target = getTargetSecondsForStage(_currentStage);
      debugPrint('⭐️ [ReviewTriggerService] Loaded state — Usage: ${_accumulatedSeconds}s / ${target}s (${(target / 60).round()}m target), Stage: $_currentStage, Done: $_reviewCompletelyDone');

      if (_reviewCompletelyDone) {
        debugPrint('⭐️ [ReviewTriggerService] User review permanently completed. Tracker halted.');
        return;
      }

      WidgetsBinding.instance.removeObserver(this);
      WidgetsBinding.instance.addObserver(this);

      _startActiveTimer();

      // Catch-up check: If target milestone was met while offline/uninitialized, trigger review now
      if (_accumulatedSeconds >= target) {
        debugPrint('🚀 [ReviewTriggerService] Target milestone already reached on launch! Triggering review now...');
        _triggerMilestoneReview();
      }
    } catch (e) {
      debugPrint('⚠️ [ReviewTriggerService] Error during initialization: $e');
    }
  }

  /// Permanently marks review/feedback as complete and stops all future stage timers permanently.
  Future<void> markReviewAsGiven() async {
    _reviewCompletelyDone = true;
    _stopActiveTimer();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyReviewDone, true);
      debugPrint('✅ [ReviewTriggerService] Review marked as given! All future prompts permanently disabled.');
    } catch (e) {
      debugPrint('Error saving review done status: $e');
    }
  }

  /// Disposes lifecycle listener and cancels active tracking timer.
  void dispose() {
    _stopActiveTimer();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_reviewCompletelyDone) return;

    if (state == AppLifecycleState.resumed) {
      debugPrint('▶️ [ReviewTriggerService] App Resumed — Restarting incremental usage timer.');
      _startActiveTimer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      debugPrint('⏸️ [ReviewTriggerService] App Backgrounded — Pausing incremental usage timer.');
      _stopActiveTimer();
    }
  }

  /// Starts the 10-second tick timer while app is active in foreground
  void _startActiveTimer() {
    if (_reviewCompletelyDone || _timer != null) return;

    _timer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_reviewCompletelyDone) {
        _stopActiveTimer();
        return;
      }

      _accumulatedSeconds += 10;
      final target = getTargetSecondsForStage(_currentStage);
      debugPrint('⏱️ [ReviewTriggerService] Active usage: ${_accumulatedSeconds}s / ${target}s (Stage $_currentStage)');

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_keyAccumulatedSeconds, _accumulatedSeconds);
      } catch (e) {
        debugPrint('Error saving usage seconds: $e');
      }

      if (_accumulatedSeconds >= target) {
        await _triggerMilestoneReview();
      }
    });
  }

  /// Handles milestone trigger, advances stage, and resets active timer to 0
  Future<void> _triggerMilestoneReview() async {
    _stopActiveTimer();

    final target = getTargetSecondsForStage(_currentStage);
    debugPrint('🎉 [ReviewTriggerService] Reached milestone of ${target}s! Triggering review for Stage $_currentStage...');

    // Trigger review sheet
    await requestInAppReview();

    // Advance to next stage (Stage 1 -> 2, Stage 2 -> 3, etc.) and reset timer to 0
    _currentStage += 1;
    _accumulatedSeconds = 0;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyCurrentStage, _currentStage);
      await prefs.setInt(_keyAccumulatedSeconds, 0);
    } catch (e) {
      debugPrint('Error advancing stage: $e');
    }

    // Restart timer for next stage if not permanently stopped
    if (!_reviewCompletelyDone) {
      _startActiveTimer();
    }
  }

  /// Stops and cancels the active tick timer
  void _stopActiveTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Triggers Google Play Native In-App Review Bottom Sheet prompt
  Future<void> requestInAppReview({bool isManualTest = false}) async {
    if (_reviewCompletelyDone && !isManualTest) return;

    try {
      final InAppReview inAppReview = InAppReview.instance;
      final isAvailable = await inAppReview.isAvailable();

      debugPrint('🔍 [ReviewTriggerService] Is InAppReview Available: $isAvailable');

      if (isAvailable) {
        debugPrint('🚀 [ReviewTriggerService] Invoking InAppReview.requestReview()');
        await inAppReview.requestReview();

        // In debug builds / USB testing (`kDebugMode` or `isManualTest`), Google Play Core
        // suppresses the native overlay UI because the APK was not downloaded from Play Store.
        // Therefore, in debug mode or manual test mode, also open store listing fallback!
        if (kDebugMode || isManualTest) {
          debugPrint('🛠️ [ReviewTriggerService] Debug mode / USB build detected — opening Play Store listing fallback...');
          await inAppReview.openStoreListing(appStoreId: 'com.arkiolabs.rental');
        }
      } else {
        debugPrint('⚠️ [ReviewTriggerService] InAppReview not available on current device/environment. Opening Store Listing...');
        await inAppReview.openStoreListing(appStoreId: 'com.arkiolabs.rental');
      }
    } catch (e) {
      debugPrint('❌ [ReviewTriggerService] Failed to launch In-App Review dialog: $e. Opening Store Listing fallback...');
      try {
        await InAppReview.instance.openStoreListing(appStoreId: 'com.arkiolabs.rental');
      } catch (_) {}
    }
  }

  /// Resets tracker state to Stage 1 (0 seconds) for rapid testing & debugging
  Future<void> resetForTesting() async {
    _stopActiveTimer();
    _accumulatedSeconds = 0;
    _currentStage = 1;
    _reviewCompletelyDone = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAccumulatedSeconds);
      await prefs.remove(_keyCurrentStage);
      await prefs.remove(_keyReviewDone);
      debugPrint('🔄 [ReviewTriggerService] State reset for testing! Stage reset to 1 (5-min target).');
    } catch (e) {
      debugPrint('Error resetting testing state: $e');
    }

    _startActiveTimer();
  }

  /// Instantly triggers a specific stage milestone (Stage 1 = 5m, Stage 2 = 15m, Stage 3 = 30m) for testing
  Future<void> triggerStageForTesting(int targetStage) async {
    debugPrint('⚡ [ReviewTriggerService] Manual test trigger for Stage $targetStage invoked!');
    _currentStage = targetStage;
    _accumulatedSeconds = getTargetSecondsForStage(targetStage);
    await _triggerMilestoneReview();
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
