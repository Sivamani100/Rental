import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rental/features/settings/presentation/pages/settings_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:iconsax/iconsax.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental/core/widgets/app_snackbar.dart';
import 'package:rental/core/widgets/bouncing_button.dart';
import 'package:rental/core/widgets/rental_app_icon.dart';
import 'package:rental/features/property_posting/presentation/pages/posting_screen.dart';
import 'package:rental/features/property_details/presentation/pages/property_details_screen.dart';
import 'package:rental/features/search/presentation/widgets/location_picker_sheet.dart';
import 'package:rental/features/search/presentation/pages/search_screen.dart';
import 'package:rental/features/ai_chat/presentation/pages/ai_chat_screen.dart';
import 'package:rental/features/saved_properties/presentation/pages/saved_properties_screen.dart';
import 'package:rental/features/saved_properties/data/datasources/saved_properties_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lottie/lottie.dart';
import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/app/theme/theme_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rental/core/services/analytics_service.dart';
import 'package:rental/features/transport/data/datasources/transport_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:rental/core/models/property_model.dart';

class YellowSplashScreen extends StatefulWidget {
  final bool isLocating;
  final String? city;
  final String? subtext;
  final bool isDenied;
  const YellowSplashScreen({
    super.key,
    required this.isLocating,
    this.city,
    this.subtext,
    this.isDenied = false,
  });

  @override
  State<YellowSplashScreen> createState() => YellowSplashScreenState();
}

class YellowSplashScreenState extends State<YellowSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _dotsController;
  late final AnimationController _cityFadeController;
  late final Animation<double> _cityFade;

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _cityFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cityFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cityFadeController, curve: Curves.easeIn),
    );

    if (!widget.isLocating) {
      _cityFadeController.forward();
    }
  }

  @override
  void didUpdateWidget(YellowSplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLocating && !widget.isLocating) {
      _cityFadeController.forward();
    }
  }

  @override
  void dispose() {
    _dotsController.dispose();
    _cityFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFD600), // AppTheme.primaryAccent
      body: const Center(
        child: Image(
          image: AssetImage('assets/icons/logoblack.png'),
          width: 160,
        ),
      ),
    );
  }

  Widget _buildLocatingText() {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Locating',
              style: TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 2),
            ...List.generate(3, (i) {
              final delay = i * 0.33;
              final opacity = (((_dotsController.value - delay) % 1.0).abs() < 0.5) ? 1.0 : 0.3;
              return Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Opacity(
                  opacity: opacity.clamp(0.3, 1.0),
                  child: const Text(
                    '.',
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}