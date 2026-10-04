import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:in_app_update/in_app_update.dart';

/// Clean Orchestrator Service handling Google Play Flexible In-App Updates.
///
/// Handles:
/// 1. State 1 (Prompt): Native Play Store Flexible Update overlay prompt.
/// 2. State 2 (Background Download): Non-blocking silent download in background.
/// 3. State 3 (Installation Banner): Persistent bottom banner with green "Reload" button
///    invoking `InAppUpdate.completeFlexibleUpdate()`.
/// 4. App Resume Lifecycle Handler: Re-checks update status when app is resumed from background.
class InAppUpdateService with WidgetsBindingObserver {
  InAppUpdateService._();
  static final InAppUpdateService instance = InAppUpdateService._();

  AppUpdateInfo? _updateInfo;
  bool _isChecking = false;
  BuildContext? _currentContext;

  AppUpdateInfo? get updateInfo => _updateInfo;

  /// Initializes lifecycle observation and performs initial update check.
  void initialize(BuildContext context) {
    _currentContext = context;
    if (_isSupportedPlatform()) {
      WidgetsBinding.instance.removeObserver(this);
      WidgetsBinding.instance.addObserver(this);
      checkForUpdate(context);
    }
  }

  /// Removes lifecycle observer on disposal.
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _currentContext != null) {
      // Re-verify update status on app resume
      checkForUpdate(_currentContext!, isAppResumeCheck: true);
    }
  }

  /// Queries the Play Store for update availability and handles flexible update flow.
  Future<void> checkForUpdate(BuildContext context, {bool isAppResumeCheck = false}) async {
    if (!_isSupportedPlatform() || _isChecking) return;
    _currentContext = context;
    _isChecking = true;

    try {
      final info = await InAppUpdate.checkForUpdate();
      _updateInfo = info;

      debugPrint('📦 [InAppUpdateService] Status: ${info.updateAvailability}, InstallStatus: ${info.installStatus}, FlexibleAllowed: ${info.flexibleUpdateAllowed}');

      // Edge Case 1: Download has already completed (e.g. while app was minimized or in background)
      if (info.installStatus == InstallStatus.downloaded) {
        if (context.mounted) completeUpdate(context);
        _isChecking = false;
        return;
      }

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (info.immediateUpdateAllowed && !isAppResumeCheck) {
          _startImmediateUpdate();
        } else if (info.flexibleUpdateAllowed && !isAppResumeCheck && context.mounted) {
          _startFlexibleUpdate(context);
        }
      }
    } catch (e) {
      debugPrint('⚠️ [InAppUpdateService] In-App Update Check Skipped / Unsupported Environment: $e');
    } finally {
      _isChecking = false;
    }
  }

  /// Triggers Google Play Immediate Update Flow (Auto-completes)
  Future<void> _startImmediateUpdate() async {
    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (e) {
      debugPrint('❌ [InAppUpdateService] Failed to start immediate update: $e');
    }
  }

  /// Triggers Google Play Flexible Update Flow
  Future<void> _startFlexibleUpdate(BuildContext context) async {
    try {
      final result = await InAppUpdate.startFlexibleUpdate();
      if (result == AppUpdateResult.success && context.mounted) {
        debugPrint('✅ [InAppUpdateService] Flexible update downloaded successfully! Automatically completing...');
        completeUpdate(context);
      }
    } catch (e) {
      debugPrint('❌ [InAppUpdateService] Failed to start flexible update: $e');
    }
  }

  /// Completes flexible update by restarting app and installing APK
  Future<void> completeUpdate(BuildContext context) async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (e) {
      debugPrint('❌ [InAppUpdateService] Error completing flexible update: $e');
    }
  }


  /// Platform check helper to avoid non-Android runtime exceptions
  bool _isSupportedPlatform() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }
}

/// Root Wrapper Component that mounts InAppUpdateService onto your MaterialApp
class InAppUpdateWrapper extends StatefulWidget {
  final Widget child;
  const InAppUpdateWrapper({super.key, required this.child});

  @override
  State<InAppUpdateWrapper> createState() => _InAppUpdateWrapperState();
}

class _InAppUpdateWrapperState extends State<InAppUpdateWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        InAppUpdateService.instance.initialize(context);
      }
    });
  }

  @override
  void dispose() {
    InAppUpdateService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
