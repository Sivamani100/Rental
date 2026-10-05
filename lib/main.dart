import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental/features/home/presentation/pages/home_screen.dart';
import 'package:rental/features/onboarding/presentation/pages/onboarding_screen.dart';
import 'package:rental/features/ai_chat/presentation/pages/ai_chat_screen.dart';
import 'package:rental/features/ai_chat/data/datasources/ai_assistant_service.dart';
import 'package:rental/core/services/analytics_service.dart';
import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/app/theme/theme_provider.dart';
import 'package:rental/app/config/env.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:rental/core/services/push_notification_service.dart';
import 'package:rental/core/services/in_app_update_service.dart';
import 'package:rental/core/services/review_trigger_service.dart';
import 'package:rental/features/saved_properties/data/datasources/saved_properties_service.dart';
import 'package:rental/core/services/secure_storage_adapter.dart';
import 'package:rental/core/services/install_tracker.dart';
import 'package:rental/core/services/app_install_prompt_service.dart';
import 'package:rental/core/ads/ads_initializer.dart';



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
  await SavedPropertiesService.instance.init();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      localStorage: SecureLocalStorage(),
    ),
  );

  // Track unique installations anonymously in the background
  InstallTracker.initAndTrack();

  final prefs = await SharedPreferences.getInstance();

  // Pre-load AI Assistant local chat history and settings instantly
  AiAssistantService.instance.init();

  // Set up Firebase Messaging background handler (mobile only)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Launch UI INSTANTLY — 0ms blank screen delay
  runApp(const RentalApp());

  // Initialize AdMob SDK non-blocking after first frame (never delays UI).
  AdsInitializer.init();

  // Initialize Analytics and Push Notification Service asynchronously in background
  _initAsyncServices();

  // Trigger the web install prompt (shows up to 3 times with 1-min gaps)
  // Wire the navigator key first, then check after a short delay
  AppInstallPromptService.instance.navigatorKey =
      PushNotificationService.instance.navigatorKey;
  Future.delayed(const Duration(seconds: 3), () {
    AppInstallPromptService.instance.checkAndShowPrompt();
  });
}

void _initAsyncServices() async {
  await AnalyticsService.instance.init();
  await PushNotificationService.instance.init();
}

class RentalApp extends StatelessWidget {
  const RentalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final isDark = false;

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
            themeMode: ThemeMode.light,
            builder: (context, child) {
              final appContent = ReviewTriggerWrapper(
                child: InAppUpdateWrapper(child: child ?? const SizedBox.shrink()),
              );
              return appContent;
            },
            onGenerateRoute: (settings) {
              final rawName = settings.name ?? '/';
              final uri = Uri.parse(rawName);
              final path = uri.path.toLowerCase();

              if (path == '/ai' || path == '/ai-chat' || path == '/assistant') {
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => const AiChatScreen(),
                );
              }

              String? propertyId = uri.queryParameters['propertyId'] ?? uri.queryParameters['id'];
              if (path.startsWith('/property/')) {
                propertyId = path.replaceFirst('/property/', '').trim();
              }

              if (propertyId != null && propertyId.isNotEmpty) {
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => HomeScreen(initialPropertyId: propertyId),
                );
              }

              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const OnboardingScreen(),
              );
            },
          ),
        );
      },
    );
  }
}
