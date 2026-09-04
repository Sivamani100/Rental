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
import 'services/analytics_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'config/env.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/push_notification_service.dart';
import 'services/in_app_update_service.dart';
import 'services/review_trigger_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  print("Handling a background message: ${message.messageId}");
}
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  // Enable edge-to-edge rendering so the app draws behind
  // the status bar AND the Android 3-button/gesture navigation bar.
  // SafeArea widgets in each screen then push content up/down correctly
  // regardless of whether the phone uses gestures or 3-button navigation.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Turbocharge Flutter ImageCache for instant photo rendering
  PaintingBinding.instance.imageCache.maximumSize = 1000;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 250 << 20; // 250 MB

  await ThemeController.instance.init();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  final prefs = await SharedPreferences.getInstance();
  final bool hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;

  // Pre-load AI Assistant local chat history and settings instantly
  AiAssistantService.instance.init();

  // Set up Firebase Messaging background handler (mobile only)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Launch UI INSTANTLY — 0ms blank screen delay
  runApp(RentalApp(hasCompletedOnboarding: hasCompletedOnboarding));

  // Initialize Analytics and Push Notification Service asynchronously in background
  _initAsyncServices();
}

void _initAsyncServices() async {
  await AnalyticsService.instance.init();
  await PushNotificationService.instance.init();
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
            // Fully transparent so the edge-to-edge app draws behind the nav bar.
            // SafeArea handles the actual content padding for all nav styles
            // (gesture bar, 2-button, 3-button).
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
          child: MaterialApp(
            navigatorKey: PushNotificationService.instance.navigatorKey,
            title: 'Rental App',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeController.instance.themeMode,
            builder: (context, child) => ReviewTriggerWrapper(
              child: InAppUpdateWrapper(child: child ?? const SizedBox.shrink()),
            ),
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
                // SECURITY: Require valid session — same guard as /admin root
                final dashSession = Supabase.instance.client.auth.currentSession;
                if (dashSession != null) {
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
