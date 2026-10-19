import 'package:flutter/material.dart';

import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/features/partner/data/services/partner_service.dart';
import 'package:rental/features/partner/presentation/pages/partner_auth_screen.dart';
import 'package:rental/features/partner/presentation/pages/partner_dashboard_screen.dart';

class PartnerEntryHandler extends StatefulWidget {
  const PartnerEntryHandler({super.key});

  @override
  State<PartnerEntryHandler> createState() => _PartnerEntryHandlerState();
}

class _PartnerEntryHandlerState extends State<PartnerEntryHandler> {
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    await PartnerService.instance.init();
    if (mounted) {
      setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF7F7F9),
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryYellow),
        ),
      );
    }

    return AnimatedBuilder(
      animation: PartnerService.instance,
      builder: (context, _) {
        // Only show Dashboard (home page & all tabs) after partner logs in
        if (PartnerService.instance.isLoggedIn) {
          return const PartnerDashboardScreen();
        }

        // Otherwise show Partner Login Screen
        return const PartnerAuthScreen(isEmbeddedInEntryHandler: true);
      },
    );
  }
}
