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
  bool _isBannerVisible = false;
  bool _isChecking = false;
  BuildContext? _currentContext;

  bool get isBannerVisible => _isBannerVisible;
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
        if (context.mounted) _showUpdateDownloadedBanner(context);
        _isChecking = false;
        return;
      }

      // State 1 & 2: Update is available and flexible update is allowed
      if (info.updateAvailability == UpdateAvailability.updateAvailable && info.flexibleUpdateAllowed) {
        if (!isAppResumeCheck && context.mounted) {
          _startFlexibleUpdate(context);
        }
      }
    } catch (e) {
      debugPrint('⚠️ [InAppUpdateService] In-App Update Check Skipped / Unsupported Environment: $e');
    } finally {
      _isChecking = false;
    }
  }

  /// Triggers Google Play Flexible Update Flow
  Future<void> _startFlexibleUpdate(BuildContext context) async {
    try {
      final result = await InAppUpdate.startFlexibleUpdate();
      if (result == AppUpdateResult.success && context.mounted) {
        debugPrint('✅ [InAppUpdateService] Flexible update downloaded successfully!');
        _showUpdateDownloadedBanner(context);
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to restart app automatically. Please restart the app manually from home screen.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Displays the persistent Bottom Installation Banner (State 3)
  void _showUpdateDownloadedBanner(BuildContext context) {
    if (_isBannerVisible || !context.mounted) return;
    _isBannerVisible = true;

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(days: 365), // Persistent until user acts
        behavior: SnackBarBehavior.fixed,
        backgroundColor: const Color(0xFF0F172A),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.arrow_down_1, color: Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rental app just downloaded an update',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Restart to apply features and security updates.',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                _isBannerVisible = false;
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                completeUpdate(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Reload',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
