import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental/features/partner/data/services/partner_service.dart';
import 'package:rental/features/partner/presentation/pages/partner_dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PartnerDashboardScreen builds without error', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'partner_manual_login_done': true,
      'current_partner_profile': '{"id":"test_id","email":"mallipurapuravi@gmail.com","name":"Test Partner","phone":"1234567890","role":"Direct Property Owner"}',
    });

    try {
      await Supabase.initialize(
        url: 'https://dhbwnteiahefjfpojapz.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummy',
      );
    } catch (_) {}

    await PartnerService.instance.init();

    await tester.pumpWidget(
      const MaterialApp(
        home: PartnerDashboardScreen(),
      ),
    );

    await tester.pump();
    expect(find.byType(PartnerDashboardScreen), findsOneWidget);
  });
}
