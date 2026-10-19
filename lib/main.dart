import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental/features/home/presentation/pages/home_screen.dart';
import 'package:rental/features/onboarding/presentation/pages/onboarding_screen.dart';
import 'package:rental/features/ai_chat/presentation/pages/ai_chat_screen.dart';
import 'package:rental/features/ai_chat/data/datasources/ai_assistant_service.dart';
import 'package:rental/core/services/analytics_service.dart';
import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/app/theme/theme_provider.dart';
import 'package:rental/app/config/env.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:rental/core/services/push_notification_service.dart';
import 'package:rental/core/services/in_app_update_service.dart';
import 'package:rental/core/services/review_trigger_service.dart';
import 'package:rental/features/saved_properties/data/datasources/saved_properties_service.dart';
import 'package:rental/core/services/secure_storage_adapter.dart';
import 'package:rental/core/services/install_tracker.dart';
import 'package:rental/core/services/app_install_prompt_service.dart';
import 'package:rental/core/ads/ads_initializer.dart';
import 'package:rental/core/services/deep_link_service.dart';
import 'package:rental/core/widgets/network_status_bar.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {}
  debugPrint("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  // Catch unhandled Flutter framework errors safely
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error caught: ${details.exceptionAsString()}');
  };

  // Prevent any unhandled UI build error from displaying a red screen
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.refresh_rounded, size: 36, color: Color(0xFFFFB800)),
              const SizedBox(height: 10),
              const Text(
                'Something unexpected occurred. Pull or tap to refresh.',
                style: TextStyle(
                  fontFamily: 'ProximaNova',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 6),
                Text(
                  details.exceptionAsString(),
                  style: const TextStyle(fontSize: 10, color: Colors.red),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  };

  // Catch unhandled asynchronous errors safely
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Async error caught: $error');
    return true;
  };

  // Enable edge-to-edge rendering so the app draws behind
  // the status bar AND the Android 3-button/gesture navigation bar.
  try {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  } catch (e) {
    debugPrint('SystemUiMode error: $e');
  }

  // Turbocharge Flutter ImageCache for instant photo rendering
  try {
    PaintingBinding.instance.imageCache.maximumSize = 1000;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 250 << 20; // 250 MB
  } catch (_) {}

  // Safe initialization of local controllers and storage
  try {
    await ThemeController.instance.init();
  } catch (e) {
    debugPrint('ThemeController init error: $e');
  }

  try {
    await SavedPropertiesService.instance.init();
  } catch (e) {
    debugPrint('SavedPropertiesService init error: $e');
  }

  // Initialize Supabase safely
  try {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        localStorage: SecureLocalStorage(),
      ),
    );
  } catch (e) {
    debugPrint('Supabase initialize error: $e');
  }

  // Initialize Firebase before registering onBackgroundMessage
  try {
    if (Firebase.apps.isEmpty) {
      if (kIsWeb) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'AIzaSyBxP9pherG9E44m0Nzqm-eQmA066kvUG28',
            appId: '1:1045370324281:android:55dc0aca49e69a1bcdd4e8',
            messagingSenderId: '1045370324281',
            projectId: 'rental-67032',
            storageBucket: 'rental-67032.firebasestorage.app',
          ),
        );
      } else {
        await Firebase.initializeApp();
      }
    }
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  // Track unique installations anonymously in the background
  try {
    InstallTracker.initAndTrack();
  } catch (e) {
    debugPrint('InstallTracker error: $e');
  }

  // Pre-load AI Assistant local chat history and settings instantly
  try {
    AiAssistantService.instance.init();
  } catch (e) {
    debugPrint('AiAssistantService error: $e');
  }

  // Launch UI INSTANTLY — 0ms blank screen delay
  runApp(const RentalApp());

  // Initialize AdMob SDK non-blocking after first frame (never delays UI).
  try {
    AdsInitializer.init();
  } catch (e) {
    debugPrint('AdsInitializer error: $e');
  }

  // Initialize Analytics and Push Notification Service asynchronously in background
  _initAsyncServices();

  // Initialize deep links listener
  try {
    DeepLinkService.instance.init(PushNotificationService.instance.navigatorKey);
  } catch (e) {
    debugPrint('DeepLinkService error: $e');
  }

  // Trigger the web install prompt on web only
  if (kIsWeb) {
    AppInstallPromptService.instance.navigatorKey =
        PushNotificationService.instance.navigatorKey;
    Future.delayed(const Duration(seconds: 3), () {
      AppInstallPromptService.instance.checkAndShowPrompt();
    });
  }
}

void _initAsyncServices() async {
  try {
    await AnalyticsService.instance.init();
  } catch (e) {
    debugPrint('AnalyticsService init error: $e');
  }
  try {
    await PushNotificationService.instance.init();
  } catch (e) {
    debugPrint('PushNotificationService init error: $e');
  }
}

class RentalApp extends StatelessWidget {
  const RentalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            // Fully transparent so the edge-to-edge app draws behind the nav bar.
            // SafeArea handles the actual content padding for all nav styles
            // (gesture bar, 2-button, 3-button).
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.dark,
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
                child: InAppUpdateWrapper(
                  child: GlobalNetworkStatusBarWrapper(
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
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

              final propertyId = DeepLinkService.extractPropertyId(uri);
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
