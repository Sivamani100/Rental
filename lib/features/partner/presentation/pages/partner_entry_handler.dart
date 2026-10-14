import 'package:flutter/material.dart';

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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!PartnerService.instance.isLoggedIn) {
      return const PartnerAuthScreen();
    }

    return const PartnerDashboardScreen();
  }
}
