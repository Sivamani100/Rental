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
import 'package:rental/features/home/presentation/widgets/skeleton_box.dart';
import 'package:rental/features/home/presentation/widgets/shimmer_effect.dart';

class SkeletonPropertyCard extends StatelessWidget {
  const SkeletonPropertyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.transparent,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ShimmerEffect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area shimmer
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: const SkeletonBox(
                    width: double.infinity,
                    height: 200,
                    borderRadius: 0,
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 56,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkCardElevated.withValues(alpha: 0.8)
                          : Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Price row
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonBox(width: 140, height: 18, borderRadius: 6),
                      SkeletonBox(width: 75, height: 18, borderRadius: 6),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Location row
                  Row(
                    children: [
                      const SkeletonBox(width: 16, height: 16, borderRadius: 8),
                      const SizedBox(width: 6),
                      SkeletonBox(
                        width: MediaQuery.of(context).size.width * 0.45,
                        height: 13,
                        borderRadius: 4,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Single row tags
                  const Row(
                    children: [
                      SkeletonBox(width: 65, height: 26, borderRadius: 30),
                      SizedBox(width: 8),
                      SkeletonBox(width: 95, height: 26, borderRadius: 30),
                      SizedBox(width: 8),
                      SkeletonBox(width: 80, height: 26, borderRadius: 30),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(
                    height: 1,
                    color: isDark ? AppTheme.darkBorder : const Color(0xFFEEEEEE),
                  ),
                  const SizedBox(height: 14),
                  // Bottom stats row
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SkeletonBox(width: 60, height: 14, borderRadius: 4),
                      SkeletonBox(width: 60, height: 14, borderRadius: 4),
                      SkeletonBox(width: 65, height: 14, borderRadius: 4),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}