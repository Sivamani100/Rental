import 'package:rental/features/home/presentation/widgets/card_bottom_strip.dart';
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

class PropertyCard extends StatelessWidget {
  final PropertyModel property;
  final double? distanceInMeters;
  final VoidCallback onTap;

  const PropertyCard({
    super.key,
    required this.property,
    this.distanceInMeters,
    required this.onTap,
  });

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m away';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km away';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final isAccentDark = ThemeData.estimateBrightnessForColor(AppTheme.swiggyOrange) == Brightness.dark;
    final accentTextColor = isAccentDark ? Colors.white : Colors.black87;

    return BouncingButton(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : const Color(0xFFEEEEEE),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image with overlays ─────────────────────────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: property.imageUrls.isNotEmpty ? property.imageUrls.first : '',
                    height: 210,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    memCacheWidth: 800,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholder: (context, url) => Container(
                      height: 210,
                      color: isDark ? AppTheme.darkCardElevated : const Color(0xFFF0F0F0),
                      child: Center(
                        child: Icon(CupertinoIcons.photo, color: Colors.grey.shade400, size: 28),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 210,
                      color: isDark ? AppTheme.darkCardElevated : const Color(0xFFF0F0F0),
                      child: Center(
                        child: Icon(CupertinoIcons.photo, color: Colors.grey.shade400, size: 28),
                      ),
                    ),
                  ),
                ),

                // ── Discount / distance badge (bottom-left, Swiggy style) ──
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: CardBottomStrip(
                    property: property,
                    distanceInMeters: distanceInMeters,
                    formatDistance: _formatDistance,
                  ),
                ),

                // ── Rating badge (top-left, Swiggy green) ──────────────────
                if (property.reviewCount > 0)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.swiggyGreen,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            property.averageRating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(CupertinoIcons.star_fill, color: Colors.white, size: 12),
                          Text(
                            ' (${property.reviewCount})',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Availability badge (top-right) ─────────────────────────
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: property.isAvailable
                          ? AppTheme.swiggyGreen
                          : AppTheme.swiggyRed,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      property.isAvailable ? 'Available' : 'Unavailable',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Card content (Swiggy restaurant list style) ────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location row (at the top now)
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.location_solid,
                        color: AppTheme.swiggyOrange,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          distanceInMeters != null
                              ? '${property.locationStr} • ${_formatDistance(distanceInMeters!)}'
                              : property.locationStr,
                          style: TextStyle(fontFamily: 'ProximaNova', 
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Title and Price row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: property.title),
                              const WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: SizedBox(width: 5),
                              ),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Icon(
                                  CupertinoIcons.check_mark_circled_solid,
                                  size: 15,
                                  color: AppTheme.swiggyOrange,
                                ),
                              ),
                            ],
                          ),
                          style: TextStyle(fontFamily: 'ProximaNova', 
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: isDark ? Colors.white : AppTheme.lightTextPrimary,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.swiggyOrange,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.swiggyOrange.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          property.price,
                          style: TextStyle(fontFamily: 'ProximaNova', 
                            fontSize: 15,
                            fontWeight: FontWeight.w800, color: accentTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Tags row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: property.tags.map((tag) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: _buildTag(context, tag),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    color: isDark ? AppTheme.darkBorder : const Color(0xFFF0F0F0),
                  ),
                  const SizedBox(height: 12),

                  // Bottom info row (Beds, Baths, Area)
                  if (property.type == 'PG')
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildBottomInfo(context, CupertinoIcons.moon_fill, property.beds),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14.0),
                            child: Container(height: 14, width: 1, color: isDark ? AppTheme.darkBorder : const Color(0xFFE0E0E0)),
                          ),
                          _buildBottomInfo(context, CupertinoIcons.drop_fill, property.baths),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14.0),
                            child: Container(height: 14, width: 1, color: isDark ? AppTheme.darkBorder : const Color(0xFFE0E0E0)),
                          ),
                          _buildBottomInfo(context, CupertinoIcons.fullscreen, property.area),
                        ],
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildBottomInfo(context, CupertinoIcons.moon_fill, property.beds),
                        Container(height: 14, width: 1, color: isDark ? AppTheme.darkBorder : const Color(0xFFE0E0E0)),
                        _buildBottomInfo(context, CupertinoIcons.drop_fill, property.baths),
                        Container(height: 14, width: 1, color: isDark ? AppTheme.darkBorder : const Color(0xFFE0E0E0)),
                        _buildBottomInfo(context, CupertinoIcons.fullscreen, property.area),
                      ],
                    ),

                  if (property.type == 'PG' &&
                     ((property.perDayWithFood != null && property.perDayWithFood!.isNotEmpty) ||
                      (property.perDayWithoutFood != null && property.perDayWithoutFood!.isNotEmpty)))
                    Column(
                      children: [
                        const SizedBox(height: 12),
                        Divider(height: 1, color: isDark ? AppTheme.darkBorder : const Color(0xFFF0F0F0)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (property.perDayWithFood != null && property.perDayWithFood!.isNotEmpty)
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(CupertinoIcons.calendar, color: Colors.grey.shade500, size: 15),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        '₹${property.perDayWithFood}/day with food',
                                        style: TextStyle(fontFamily: 'ProximaNova', 
                                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if ((property.perDayWithFood != null && property.perDayWithFood!.isNotEmpty) &&
                                (property.perDayWithoutFood != null && property.perDayWithoutFood!.isNotEmpty))
                              Container(height: 14, width: 1, color: isDark ? AppTheme.darkBorder : const Color(0xFFE0E0E0)),
                            if (property.perDayWithoutFood != null && property.perDayWithoutFood!.isNotEmpty)
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(CupertinoIcons.calendar, color: Colors.grey.shade500, size: 15),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        '₹${property.perDayWithoutFood}/day no food',
                                        style: TextStyle(fontFamily: 'ProximaNova', 
                                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
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

  Widget _buildTag(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardElevated : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFE8E8E8),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(fontFamily: 'ProximaNova', 
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBottomInfo(BuildContext context, IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 15, color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF9E9E9E)),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(fontFamily: 'ProximaNova', 
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}