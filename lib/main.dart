import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/ai_chat_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/ai_assistant_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  // Turbocharge Flutter ImageCache for instant photo rendering
  PaintingBinding.instance.imageCache.maximumSize = 1000;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 250 << 20; // 250 MB

  await ThemeController.instance.init();

  await Supabase.initialize(
    url: 'https://dhbwnteiahefjfpojapz.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRoYndudGVpYWhlZmpmcG9qYXB6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc2NDIwNTQsImV4cCI6MjEwMzIxODA1NH0.CnP-ogYh7FwPY9cqBRTX2oS6NqTT-mXgPsSyDDCADC8',
  );

  // Pre-load AI Assistant local chat history and settings instantly
  AiAssistantService.instance.init();

  final prefs = await SharedPreferences.getInstance();
  final bool hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;

  runApp(RentalApp(hasCompletedOnboarding: hasCompletedOnboarding));
}

class RentalApp extends StatelessWidget {
  final bool hasCompletedOnboarding;

  const RentalApp({super.key, this.hasCompletedOnboarding = false});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final isDark = ThemeController.instance.isDarkMode;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: isDark ? AppTheme.darkScaffold : Colors.white,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
          child: MaterialApp(
            title: 'Rental App',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeController.instance.themeMode,
            onGenerateRoute: (settings) {
              final rawName = settings.name ?? '/';
              final uri = Uri.parse(rawName);
              final path = uri.path.toLowerCase();

              if (path == '/onboarding') {
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => const OnboardingScreen(),
                );
              }

              if (path == '/ai' || path == '/ai-chat' || path == '/assistant') {
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => const AiChatScreen(),
                );
              }

              if (path == '/admin' ||
                  path == '/admin/' ||
                  path == 'admin' ||
                  path.startsWith('/admin')) {
                final session = Supabase.instance.client.auth.currentSession;
                if (session != null) {
                  return MaterialPageRoute(
                    settings: settings,
                    builder: (_) => const AdminDashboardScreen(),
                  );
                }
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => const AdminLoginScreen(),
                );
              }

              if (path == '/admin/login') {
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => const AdminLoginScreen(),
                );
              }

              if (path == '/admin/dashboard') {
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => const AdminDashboardScreen(),
                );
              }

              String? propertyId = uri.queryParameters['propertyId'] ?? uri.queryParameters['id'];
              if (path.startsWith('/property/')) {
                propertyId = path.replaceFirst('/property/', '').trim();
              }

              // Direct property deep links open the property directly
              if (propertyId != null && propertyId.isNotEmpty) {
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => HomeScreen(initialPropertyId: propertyId),
                );
              }

              // First-time users see OnboardingScreen
              if (!hasCompletedOnboarding) {
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => const OnboardingScreen(),
                );
              }

              return MaterialPageRoute(
                settings: settings,
                builder: (_) => HomeScreen(initialPropertyId: propertyId),
              );
            },
          ),
        );
      },
    );
  }
}
