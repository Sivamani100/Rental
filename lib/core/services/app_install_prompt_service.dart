import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// A service that shows a "Get it on Google Play" bottom sheet popup
/// on the web, up to 3 times, with at least 1 minute between each show.
/// If the user dismisses it 3 times, it stops showing permanently.
class AppInstallPromptService {
  AppInstallPromptService._();
  static final AppInstallPromptService instance = AppInstallPromptService._();

  static const String _countKey = 'app_install_prompt_count';
  static const String _lastTimeKey = 'app_install_last_prompt_time';

  // NavigatorKey must be set from main.dart (same key used by MaterialApp)
  GlobalKey<NavigatorState>? navigatorKey;

  Future<void> checkAndShowPrompt() async {
    // Only show on Web platform
    if (!kIsWeb) return;

    final prefs = await SharedPreferences.getInstance();
    final int count = prefs.getInt(_countKey) ?? 0;

    // If shown/dismissed 3 times, stop forever
    if (count >= 3) return;

    final int lastTime = prefs.getInt(_lastTimeKey) ?? 0;
    final int now = DateTime.now().millisecondsSinceEpoch;

    // Must wait at least 1 minute between prompts
    if (now - lastTime < 60000) return;

    // Wait 2s for UI to settle, then show
    await Future.delayed(const Duration(seconds: 2));

    final context = navigatorKey?.currentContext;
    if (context == null || !context.mounted) return;

    // Record the show attempt
    await prefs.setInt(_lastTimeKey, now);
    await prefs.setInt(_countKey, count + 1);

    _showBottomSheet(context);
  }

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (ctx) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 24,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              // App logo
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 72,
                  width: 72,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Get the Full Experience',
                style: TextStyle(
                  fontFamily: GoogleFonts.inter().fontFamily,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Download the Rental App for a faster,\nsmoother experience and exclusive features!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: GoogleFonts.inter().fontFamily,
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 28),
              // Google Play Badge button
              GestureDetector(
                onTap: () async {
                  Navigator.pop(ctx);
                  final url = Uri.parse(
                    'https://play.google.com/store/apps/details?id=com.arkiolabs.rental',
                  );
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                child: SizedBox(
                  width: 200,
                  height: 60,
                  child: Image.asset(
                    'assets/images/googleplaybadge.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Maybe Later',
                  style: TextStyle(
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontSize: 14,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
