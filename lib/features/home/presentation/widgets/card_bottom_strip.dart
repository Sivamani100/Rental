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

class CardBottomStrip extends StatefulWidget {
  final PropertyModel property;
  final double? distanceInMeters;
  final String Function(double) formatDistance;

  const CardBottomStrip({
    required this.property,
    required this.distanceInMeters,
    required this.formatDistance,
  });

  @override
  State<CardBottomStrip> createState() => CardBottomStripState();
}

class CardBottomStripState extends State<CardBottomStrip>
    with SingleTickerProviderStateMixin {
  Timer? _stateTimer;
  bool _showAdminVerified = false;
  late AnimationController _scrollAnimController;

  @override
  void initState() {
    super.initState();
    _scrollAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 11),
    );
    _scheduleNextState();
  }

  void _scheduleNextState() {
    _stateTimer?.cancel();
    // 6 seconds for info frame, 11 seconds for scrolling text frame
    final nextDuration = _showAdminVerified
        ? const Duration(seconds: 11)
        : const Duration(seconds: 6);

    _stateTimer = Timer(nextDuration, () {
      if (!mounted) return;
      setState(() {
        _showAdminVerified = !_showAdminVerified;
      });
      if (_showAdminVerified) {
        _scrollAnimController.forward(from: 0.0);
      } else {
        _scrollAnimController.stop();
      }
      _scheduleNextState();
    });
  }

  @override
  void dispose() {
    _stateTimer?.cancel();
    _scrollAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: const BoxDecoration(
        color: Color(0xFFFFEB3A),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.25),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        // Admin approved banner text hidden for now as requested (can be re-enabled later)
        child: _buildStandardInfoView(),
      ),
    );
  }

  Widget _buildStandardInfoView() {
    return Row(
      key: const ValueKey('standard_info'),
      children: [
        // Column 1: Location / Distance
        Expanded(
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.location_solid, color: Colors.black, size: 14.5),
                const SizedBox(width: 4),
                Text(
                  widget.distanceInMeters != null
                      ? widget.formatDistance(widget.distanceInMeters!)
                      : 'Nearby',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.black,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),

        // Divider 1
        Container(
          width: 1.2,
          height: 16,
          color: Colors.black.withValues(alpha: 0.25),
        ),

        // Column 2: Category / Property Type
        Expanded(
          child: Center(
            child: Text(
              widget.property.type == 'PG'
                  ? 'PG / Hostel'
                  : (widget.property.type == 'Buy' ? 'Buy / Sale' : widget.property.type),
              style: const TextStyle(
                fontFamily: 'Inter',
                color: Colors.black,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ),

        // Divider 2
        Container(
          width: 1.2,
          height: 16,
          color: Colors.black.withValues(alpha: 0.25),
        ),

        // Column 3: Rental App Brand
        Expanded(
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const RentalAppIcon(size: 14.5, color: Colors.black),
                const SizedBox(width: 4.5),
                const Text(
                  'Rental App',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.black,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminApprovedView() {
    return ClipRect(
      key: const ValueKey('admin_approved'),
      child: AnimatedBuilder(
        animation: _scrollAnimController,
        builder: (context, child) {
          // Starts at center (dx = 0.40) and glides steadily at 1x speed towards the left
          final double dx = (1.0 - _scrollAnimController.value) * 0.40 +
              (_scrollAnimController.value * -1.25);
          return FractionalTranslation(
            translation: Offset(dx, 0.0),
            child: child,
          );
        },
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          maxWidth: double.infinity,
          child: const Text(
            '100% Genuine Owner Listing   •   This property has been approved & verified by Admin   •   100% Trusted & Verified   •   Direct Owner Contact   •   You can trust and contact directly   •   ',
            style: TextStyle(
              fontFamily: 'Inter',
              color: Colors.black,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              wordSpacing: 1.5,
            ),
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ),
    );
  }
}