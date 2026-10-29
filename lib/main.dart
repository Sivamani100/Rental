import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental/features/onboarding/presentation/pages/onboarding_screen.dart';
import 'package:rental/features/property_details/presentation/pages/property_details_screen.dart';
import 'package:rental/features/property_details/presentation/pages/property_loader_screen.dart';
import 'package:rental/features/transport/data/datasources/transport_service.dart';
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
import 'package:app_links/app_links.dart';
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

  // Run critical startup tasks concurrently for near-instant cold start
  String? initialPropertyId;
  String? cachedPropertiesJson;
  bool hasCompletedOnboarding = true;

  // Start Firebase safely in background without blocking first frame
  _initFirebaseSafely();

  // Non-blocking background initializations
  AiAssistantService.instance.init();

  // CRITICAL: Load SharedPreferences BEFORE deep link check so we can use cache
  // SharedPreferences is fast (usually <10ms) and needed for cache lookup
  try {
    final prefs = await SharedPreferences.getInstance();
    cachedPropertiesJson = prefs.getString('cached_properties');
    hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ??
        (prefs.containsKey('cached_properties') ||
            prefs.containsKey('unique_app_install_id'));
  } catch (e) {
    debugPrint('SharedPreferences init error: $e');
  }

  // CRITICAL: Check initial deep link - wait for it to ensure we don't miss it
  // If no deep link, this returns null quickly. If there is a deep link, we wait for it.
  // This prevents the blank screen issue by ensuring we know the target before launching UI.
  initialPropertyId = await _checkInitialDeepLink();

  // Mark that we handled the initial link to prevent duplicate navigation in DeepLinkService
  if (initialPropertyId != null) {
    DeepLinkService.instance.markInitialLinkHandled();
  }

  // Launch UI INSTANTLY - if we have a deep link, we route directly to property
  // If not, we route to HomeScreen (no blank screen)
  runApp(RentalApp(
    initialPropertyId: initialPropertyId,
    cachedPropertiesJson: cachedPropertiesJson,
    hasCompletedOnboarding: hasCompletedOnboarding,
  ));

  // Initialize remaining services in background AFTER UI is visible
  Future.wait([
    // ThemeController & SavedProperties in parallel
    Future.wait([
      ThemeController.instance.init().catchError((e) {
        debugPrint('ThemeController init error: $e');
      }),
      SavedPropertiesService.instance.init().catchError((e) {
        debugPrint('SavedPropertiesService init error: $e');
      }),
    ]),

    // Supabase initialize
    Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        localStorage: SecureLocalStorage(),
      ),
    ).then((_) {
      InstallTracker.initAndTrack();
    }).catchError((e) {
      debugPrint('Supabase initialize error: $e');
    }),
  ]);

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
    Future.delayed(const Duration(seconds: 15), () {
      AppInstallPromptService.instance.checkAndShowPrompt();
    });
  }
}

Future<void> _initFirebaseSafely() async {
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
}

Future<String?> _checkInitialDeepLink() async {
  try {
    if (kIsWeb) {
      final propId = DeepLinkService.extractPropertyId(Uri.base);
      debugPrint('[_checkInitialDeepLink] Web initial link: $propId');
      return propId;
    } else {
      final appLinks = AppLinks();
      // No timeout - wait for the link to ensure we don't miss it
      // If there's no link, this returns null quickly (typically <50ms)
      // If there is a link, we wait for it (necessary for deep link to work)
      final uri = await appLinks.getInitialLink();
      if (uri != null) {
        final propId = DeepLinkService.extractPropertyId(uri);
        debugPrint('[_checkInitialDeepLink] Mobile initial link: $uri -> $propId');
        return propId;
      } else {
        debugPrint('[_checkInitialDeepLink] No initial link found');
      }
    }
  } catch (e) {
    debugPrint('Initial deep link check error: $e');
  }
  return null;
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
  final String? initialPropertyId;
  final String? cachedPropertiesJson;
  final bool hasCompletedOnboarding;
  const RentalApp({
    super.key,
    this.initialPropertyId,
    this.cachedPropertiesJson,
    this.hasCompletedOnboarding = true,
  });

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

              debugPrint('[onGenerateRoute] Route: $rawName, Path: $path, initialPropertyId: $initialPropertyId');

              if (path == '/ai' || path == '/ai-chat' || path == '/assistant') {
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => const AiChatScreen(),
                );
              }

              final routePropId =
                  DeepLinkService.extractPropertyId(uri) ?? initialPropertyId;
              if (routePropId != null && routePropId.isNotEmpty) {
                debugPrint('[onGenerateRoute] Navigating to property: $routePropId');
                DeepLinkService.instance.markAsNavigated(routePropId);

                // 1. If property is in local cache, render PropertyDetailsScreen INSTANTLY (0ms!)
                final cached = DeepLinkService.findCachedProperty(
                  routePropId,
                  cachedPropertiesJson,
                );
                if (cached != null) {
                  debugPrint('[onGenerateRoute] Cache hit for $routePropId - showing PropertyDetails');
                  final transportFuture = TransportService.getNearby(
                    cached.latitude,
                    cached.longitude,
                  );
                  return MaterialPageRoute(
                    settings: settings,
                    builder: (_) => PropertyDetailsScreen(
                      property: cached,
                      preloadedTransportFuture: transportFuture,
                    ),
                  );
                }

                // 2. If not in cache, render PropertyLoaderScreen directly — NO HomeScreen overhead!
                debugPrint('[onGenerateRoute] Cache miss for $routePropId - showing PropertyLoaderScreen');
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => PropertyLoaderScreen(
                    propertyId: routePropId,
                    initialCachedPropertiesJson: cachedPropertiesJson,
                  ),
                );
              }

              debugPrint('[onGenerateRoute] No property ID - launching with splash screen');
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
