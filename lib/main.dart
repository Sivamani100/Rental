import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/admin_dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Black icons on Android
      statusBarBrightness: Brightness.light, // Black icons on iOS
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await Supabase.initialize(
    url: 'https://dhbwnteiahefjfpojapz.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRoYndudGVpYWhlZmpmcG9qYXB6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc2NDIwNTQsImV4cCI6MjEwMzIxODA1NH0.CnP-ogYh7FwPY9cqBRTX2oS6NqTT-mXgPsSyDDCADC8',
  );

  runApp(const RentalApp());
}

class RentalApp extends StatelessWidget {
  const RentalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: MaterialApp(
        title: 'Rental App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFFEB3A),
            primary: const Color(0xFFFFEB3A),
            onPrimary: Colors.black,
            secondary: Colors.black,
            onSecondary: Colors.white,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFFBF7F7),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFEB3A),
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black,
              side: const BorderSide(color: Colors.black, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
          appBarTheme: const AppBarTheme(
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
          ),
        ),
        onGenerateRoute: (settings) {
          final rawName = settings.name ?? '/';
          final uri = Uri.parse(rawName);
          final path = uri.path.toLowerCase();

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

          return MaterialPageRoute(
            settings: settings,
            builder: (_) => const HomeScreen(),
          );
        },
      ),
    );
  }
}
