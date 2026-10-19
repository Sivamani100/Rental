import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental/core/models/property_model.dart';
import 'package:rental/features/partner/data/services/partner_service.dart';
import 'package:rental/features/partner/presentation/pages/tabs/partner_home_tab.dart';
import 'package:rental/features/partner/presentation/pages/tabs/partner_properties_tab.dart';
import 'package:rental/features/partner/presentation/pages/tabs/partner_analytics_tab.dart';
import 'package:rental/features/partner/presentation/pages/tabs/partner_promote_tab.dart';
import 'package:rental/features/partner/presentation/pages/tabs/partner_profile_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
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
  });

  testWidgets('PartnerHomeTab builds without error', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PartnerHomeTab(
            onNavigateTab: (_) {},
            onRefresh: () {},
            onToggleAvailability: (_) {},
          ),
        ),
      ),
    );
    expect(find.byType(PartnerHomeTab), findsOneWidget);
  });

  testWidgets('PartnerPropertiesTab builds without error', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PartnerPropertiesTab(
            onRefresh: () {},
            onToggleAvailability: (_) {},
          ),
        ),
      ),
    );
    expect(find.byType(PartnerPropertiesTab), findsOneWidget);
  });

  testWidgets('PartnerAnalyticsTab builds without error', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PartnerAnalyticsTab(
            onRefresh: () {},
          ),
        ),
      ),
    );
    expect(find.byType(PartnerAnalyticsTab), findsOneWidget);
  });

  testWidgets('PartnerPromoteTab builds without error', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PartnerPromoteTab(
            onRefresh: () {},
            onNavigateTab: (_) {},
          ),
        ),
      ),
    );
    expect(find.byType(PartnerPromoteTab), findsOneWidget);
  });

  testWidgets('PartnerProfileTab builds without error', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PartnerProfileTab(
            onRefresh: () {},
          ),
        ),
      ),
    );
    expect(find.byType(PartnerProfileTab), findsOneWidget);
  });
}
