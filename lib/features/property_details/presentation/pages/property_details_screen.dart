import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:rental/core/widgets/app_snackbar.dart';
import 'package:rental/core/widgets/bouncing_button.dart';
import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/core/models/property_model.dart';
import 'package:rental/features/search/presentation/pages/map_screen.dart';
import 'package:rental/core/widgets/full_screen_image_viewer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rental/features/transport/data/datasources/transport_service.dart';
import 'package:rental/core/services/analytics_service.dart';
import 'package:rental/core/utils/image_compressor.dart';

class PropertyDetailsScreen extends StatefulWidget {
  final PropertyModel property;
  // Pre-started Future from HomeScreen (started on card tap, before navigation)
  final Future<List<TransportPlace>>? preloadedTransportFuture;

  const PropertyDetailsScreen({
    super.key,
    required this.property,
    this.preloadedTransportFuture,
  });

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  int _currentImageIndex = 0;
  bool _hasReviewed = false;
  String? _deviceId;
  Map<String, dynamic>? _myReview;

  // Transport facilities
  late Future<List<TransportPlace>> _nearbyTransportFuture;

  @override
  void initState() {
    super.initState();
    _checkIfReviewed();
    // Use preloaded Future if available (started on card tap for zero wait time)
    _nearbyTransportFuture = widget.preloadedTransportFuture ??
        TransportService.getNearby(
          widget.property.latitude,
          widget.property.longitude,
        );

    // Track property view
    if (widget.property.id != null) {
      AnalyticsService.instance.logPropertyView(widget.property.id!, widget.property.type);
    }
  }

  Future<void> _checkIfReviewed() async {
    if (widget.property.id == null) return;
    final prefs = await SharedPreferences.getInstance();

    String? dId = prefs.getString('device_id');
    if (dId == null) {
      dId = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString('device_id', dId);
    }
    _deviceId = dId;

    final reviewedProperties = prefs.getStringList('reviewed_properties') ?? [];
    if (reviewedProperties.contains(widget.property.id)) {
      try {
        _myReview = widget.property.reviews.firstWhere(
          (r) => r['device_id'] == _deviceId,
          orElse: () => widget.property.reviews.last,
        );
      } catch (_) {}

      if (mounted) {
        setState(() {
          _hasReviewed = true;
        });
      }
    } else {
      // Track this property as viewed; cap list at 200 to prevent unbounded growth
      reviewedProperties.add(widget.property.id!);
      if (reviewedProperties.length > 200) {
        reviewedProperties.removeRange(0, reviewedProperties.length - 200);
      }
      // We don't set _hasReviewed = true here; that only happens after actual review submission
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        AppSnackbar.error(context, 'Could not launch WhatsApp');
      }
    }
  }

  Future<void> _launchPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final url = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        AppSnackbar.error(context, 'Could not launch dialer');
      }
    }
  }

  Future<void> _shareProperty() async {
    HapticFeedback.selectionClick();
    final propertyId = widget.property.id ?? '';
    final shareUrl = 'https://rental.arkio.in/?propertyId=$propertyId';
    final shareText =
        '🏡 Check out "${widget.property.title}" (${widget.property.type == 'PG' ? 'PG / Hostel' : (widget.property.type == 'Buy' || widget.property.type == 'Sale' ? 'Property for Sale' : 'Rental House')}) for ${widget.property.price} on Arkio Rental!\n\n📱 Open in App:\n$shareUrl';

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          subject: widget.property.title,
        ),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: shareUrl));
      if (mounted) {
        AppSnackbar.success(context, 'Link copied to clipboard!');
      }
    }
  }

  Widget _buildCarouselImage(String imagePath) {
    Widget imageWidget;
    if (imagePath.startsWith('http')) {
      imageWidget = CachedNetworkImage(
        imageUrl: imagePath,
        width: double.infinity,
        fit: BoxFit.cover,
        memCacheWidth: 1080,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (context, url) => Container(
          color: Colors.grey.shade300,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey.shade300,
          child: const Center(
            child: Icon(CupertinoIcons.photo, color: Colors.grey, size: 40),
          ),
        ),
      );
    } else if (imagePath.startsWith('assets/')) {
      imageWidget = Image.asset(
        imagePath,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey.shade300,
          child: const Center(
            child: Icon(CupertinoIcons.photo, color: Colors.grey, size: 40),
          ),
        ),
      );
    } else if (kIsWeb) {
      imageWidget = Image.network(
        imagePath,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey.shade300,
          child: const Center(
            child: Icon(CupertinoIcons.photo, color: Colors.grey, size: 40),
          ),
        ),
      );
    } else {
      imageWidget = Image.file(
        File(imagePath),
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey.shade300,
          child: const Center(
            child: Icon(CupertinoIcons.photo, color: Colors.grey, size: 40),
          ),
        ),
      );
    }

    if (!widget.property.isAvailable) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]),
        child: imageWidget,
      );
    }
    
    return imageWidget;
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BouncingButton(
      scaleFactor: 0.92,
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2330) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: iconColor ?? (isDark ? Colors.white : const Color(0xFF1E1E1E)),
          size: 24,
        ),
      ),
    );
  }

  // --- Transport type styling helpers ---
  IconData _transportIcon(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('bus')) return CupertinoIcons.bus;
    if (lower.contains('auto')) return CupertinoIcons.car_detailed;
    if (lower.contains('train') || lower.contains('railway')) return CupertinoIcons.tram_fill;
    if (lower.contains('metro')) return CupertinoIcons.tram_fill;
    if (lower.contains('airport') || lower.contains('aero')) return CupertinoIcons.airplane;
    return CupertinoIcons.location_solid;
  }

  Widget _buildTransportSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Nearby Transport', CupertinoIcons.bus),
        const SizedBox(height: 12),
        FutureBuilder<List<TransportPlace>>(
          future: _nearbyTransportFuture,
          builder: (context, snapshot) {
            // ── Loading ──────────────────────────────────────────
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                height: 110,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCard : const Color(0xFFFAFAFC),
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCard : const Color(0xFFFAFAFC),
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final places = snapshot.data ?? [];

            // ── Empty ────────────────────────────────────────────
            if (places.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : const Color(0xFFF8F8FA),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.primaryYellow.withValues(alpha: 0.15) : AppTheme.primaryYellow.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(CupertinoIcons.info_circle_fill, color: isDark ? AppTheme.primaryYellow : Colors.black, size: 22),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Fetching transport data...\nCheck back in a moment.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            // ── Aggregate by type ────────────────────────────────
            final Map<String, List<TransportPlace>> grouped = {};
            for (final p in places) {
              grouped.putIfAbsent(p.type, () => []).add(p);
            }

            final types = grouped.keys.toList();
            types.sort((a, b) {
              if (a == 'Airport') return 1;
              if (b == 'Airport') return -1;
              return a.compareTo(b);
            });

            return LayoutBuilder(
              builder: (context, constraints) {
                final double spacing = 12;
                final double itemWidth = (constraints.maxWidth - spacing) / 2 - 0.5;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: types.asMap().entries.map((entry) {
                    final index = entry.key;
                    final type = entry.value;
                    final items = grouped[type]!;
                    final nearest = items.first;
                    // If total items is odd and this is the last item, it stands alone on its row
                    final isFullWidth = (types.length % 2 != 0) && (index == types.length - 1); 

                    return _buildGridTypeCard(
                      type: type,
                      count: items.length,
                      nearestDistance: nearest.distanceLabel,
                      icon: _transportIcon(type),
                      width: isFullWidth ? constraints.maxWidth : itemWidth,
                      isFullWidth: isFullWidth,
                      isDark: isDark,
                      onTap: () => _showTransportBottomSheet(type, items, isDark),
                    );
                  }).toList(),
                );
              },
            );
          },
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 20),
          child: Row(
            children: [
              Icon(CupertinoIcons.info_circle_fill, size: 14, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade400),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tap any category to view all routes and live 360° Street View',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGridTypeCard({
    required String type,
    required int count,
    required String nearestDistance,
    required IconData icon,
    required double width,
    required bool isFullWidth,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final bgColor = isDark ? AppTheme.darkCard : const Color(0xFFFAFAFC);
    final borderColor = isDark ? AppTheme.darkBorder : Colors.grey.shade200;

    return BouncingButton(
      scaleFactor: 0.95,
      onTap: onTap,
      child: Container(
        width: width,
        height: 145,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: borderColor,
            width: 1.2,
          ),
          // User asked for "don't give that much shadow", so removing the box shadow completely
        ),
        child: isFullWidth
            ? Stack(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 60),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type,
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(CupertinoIcons.location_solid, size: 14, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  nearestDistance,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkBorder : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: isDark ? null : Border.all(color: Colors.grey.shade300, width: 0.5),
                      ),
                      child: Text(
                        '$count Options',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Icon(icon, color: isDark ? AppTheme.primaryYellow : const Color(0xFF1E1E1E), size: 36),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(icon, color: isDark ? AppTheme.primaryYellow : const Color(0xFF1E1E1E), size: 28),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkBorder : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: isDark ? null : Border.all(color: Colors.grey.shade300, width: 0.5),
                        ),
                        child: Text(
                          '$count Options',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    type,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(CupertinoIcons.location_solid, size: 14, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          nearestDistance,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  void _showTransportBottomSheet(String type, List<TransportPlace> places, bool isDark) {
    final primaryColor = isDark ? AppTheme.primaryYellow : Colors.black;
    final onPrimaryColor = isDark ? Colors.black : Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF33333E) : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
              ),
              child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_transportIcon(type), color: onPrimaryColor, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nearby $type',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              '${places.length} options found within 25km',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(CupertinoIcons.clear, color: isDark ? Colors.white54 : Colors.black54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Divider(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200, height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: places.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final place = places[index];
                      return BouncingButton(
                        scaleFactor: 0.97,
                        onTap: () async {
                          Navigator.pop(context);
                          final url = Uri.parse(place.streetViewUrl);
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          } else {
                            final fallbackUrl = Uri.parse(place.googleMapsUrl);
                            if (await canLaunchUrl(fallbackUrl)) {
                              await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
                            } else {
                              if (context.mounted) {
                                AppSnackbar.error(context, 'Could not open Google Maps.');
                              }
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkCardElevated : const Color(0xFFF8F8FA),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.darkBorder : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(_transportIcon(type), color: primaryColor, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      place.name,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      place.distanceLabel + ' from property',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.primaryYellow.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '360°',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: primaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(CupertinoIcons.forward, size: 10, color: primaryColor),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

  // --- Section Header with Theme Badge Layout ---
  Widget _buildSectionHeader(String title, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primaryYellow.withValues(alpha: isDark ? 0.15 : 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isDark ? AppTheme.primaryYellow : Colors.black,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  // --- Full Width Line-by-Line Detail Row (Never cut or truncated) ---
  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool showDivider = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  icon,
                  size: 16,
                  color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
          ),
      ],
    );
  }

  // --- Vertical Section Card with Line-by-Line Items ---
  Widget _buildVerticalSectionCard({
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> items,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final validItems = items.where((i) => i['value'] != null && (i['value'] as String).trim().isNotEmpty).toList();
    if (validItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title, icon),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : const Color(0xFFFAFAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
              width: 1.2,
            ),
          ),
          child: Column(
            children: List.generate(validItems.length, (idx) {
              final item = validItems[idx];
              return _buildDetailRow(
                icon: item['icon'] as IconData? ?? CupertinoIcons.info_circle_fill,
                label: item['label'] as String,
                value: item['value'] as String,
                showDivider: idx < validItems.length - 1,
              );
            }),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  List<String> _getFilteredFeatures() {
    final Set<String> alreadyShown = {};

    void addNormalized(String? val) {
      if (val != null && val.trim().isNotEmpty) {
        alreadyShown.add(val.trim().toLowerCase());
      }
    }

    addNormalized(widget.property.securityDeposit);
    addNormalized(widget.property.noticePeriod);
    addNormalized(widget.property.agreementDuration);
    addNormalized(widget.property.maintenanceCharges);
    addNormalized(widget.property.perDayWithFood);
    addNormalized(widget.property.perDayWithoutFood);
    addNormalized(widget.property.genderPreference);
    addNormalized(widget.property.sharingType);
    addNormalized(widget.property.foodDetails);
    addNormalized(widget.property.foodQuality);
    addNormalized(widget.property.drinkingWater);
    addNormalized(widget.property.waterSupply);
    addNormalized(widget.property.powerBackup);
    addNormalized(widget.property.acType);
    addNormalized(widget.property.bathroomType);
    addNormalized(widget.property.cleanlinessInfo);
    addNormalized(widget.property.securityInfo);
    addNormalized(widget.property.verificationPolicy);
    addNormalized(widget.property.managementInfo);
    addNormalized(widget.property.gateRules);
    addNormalized(widget.property.bhkType);
    addNormalized(widget.property.furnishingStatus);
    addNormalized(widget.property.plumbingStatus);
    addNormalized(widget.property.seepageStatus);
    addNormalized(widget.property.electricalStatus);
    addNormalized(widget.property.meterStatus);
    addNormalized(widget.property.billsInfo);
    addNormalized(widget.property.tenantPreference);
    addNormalized(widget.property.petPolicy);
    addNormalized(widget.property.parkingInfo);
    addNormalized(widget.property.beds);
    addNormalized(widget.property.baths);
    addNormalized(widget.property.area);

    final List<String> result = [];
    final Set<String> seenResult = {};

    for (final feat in widget.property.features) {
      final trimmed = feat.trim();
      if (trimmed.isEmpty) continue;
      final lower = trimmed.toLowerCase();

      bool isDuplicate = false;
      for (final shown in alreadyShown) {
        if (shown == lower || (shown.length > 3 && (shown.contains(lower) || lower.contains(shown)))) {
          isDuplicate = true;
          break;
        }
      }

      if (!isDuplicate && !seenResult.contains(lower)) {
        seenResult.add(lower);
        result.add(trimmed);
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAccentDark = ThemeData.estimateBrightnessForColor(AppTheme.primaryYellow) == Brightness.dark;
    final accentTextColor = isAccentDark ? Colors.white : Colors.black;
    final isPg = widget.property.type == 'PG';
    final isBuy = widget.property.type == 'Buy' || widget.property.type == 'Sale';

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffold : Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================================
                // 1. HERO CAROUSEL & OVERLAY ACTIONS
                // ==========================================
                Stack(
                  children: [
                    SizedBox(
                      height: 380,
                      child: PageView.builder(
                        itemCount: widget.property.imageUrls.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentImageIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          final imagePath = widget.property.imageUrls[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullScreenImageViewer(
                                    imageUrls: widget.property.imageUrls,
                                    initialIndex: index,
                                    isGrayscale: !widget.property.isAvailable,
                                  ),
                                ),
                              );
                            },
                            child: _buildCarouselImage(imagePath),
                          );
                        },
                      ),
                    ),

                    // Top Scrim Gradient for glass buttons
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 110,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.55),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom Scrim Gradient for counter/indicators
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 80,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.6),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Top Navigation & Glass Action Buttons
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildGlassIconButton(
                              icon: CupertinoIcons.chevron_left,
                              onTap: () => Navigator.pop(context),
                            ),
                            Row(
                              children: [
                                _buildGlassIconButton(
                                  icon: CupertinoIcons.share,
                                  onTap: _shareProperty,
                                ),
                                const SizedBox(width: 10),
                                if (widget.property.isAvailable)
                                  _buildGlassIconButton(
                                    icon: CupertinoIcons.nosign,
                                    onTap: _showAvailabilityBottomSheet,
                                    iconColor: isDark ? Colors.white : const Color(0xFF1E1E1E),
                                  )
                                else
                                  _buildGlassIconButton(
                                    icon: CupertinoIcons.arrow_uturn_left,
                                    onTap: _showRevokeConfirmationDialog,
                                    iconColor: const Color(0xFF1A9E5B),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Carousel Indicator Dots & Photo Counter Badge
                    Positioned(
                      bottom: 16,
                      left: 20,
                      right: 20,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Dots indicator
                          Row(
                            children: List.generate(
                              widget.property.imageUrls.length,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: _currentImageIndex == index ? 22 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _currentImageIndex == index
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),

                          // Counter Chip
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullScreenImageViewer(
                                    imageUrls: widget.property.imageUrls,
                                    initialIndex: _currentImageIndex,
                                    isGrayscale: !widget.property.isAvailable,
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(CupertinoIcons.photo, color: Colors.white, size: 13),
                                      const SizedBox(width: 5),
                                      Text(
                                        '${_currentImageIndex + 1} / ${widget.property.imageUrls.length}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ==========================================
                // 2. PROPERTY INFO & BODY CONTENT
                // ==========================================
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges Row (Category, Rating, Status)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryYellow,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPg ? CupertinoIcons.building_2_fill : (isBuy ? CupertinoIcons.tag_fill : CupertinoIcons.house_fill),
                                  size: 13,
                                  color: accentTextColor,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  isPg ? 'PG / Hostel' : (isBuy ? 'For Sale (Buy)' : 'Rental House / Flat'),
                                  style: TextStyle(
                                    color: accentTextColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (widget.property.reviewCount > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: isDark ? 0.18 : 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(CupertinoIcons.star_fill, color: Colors.amber, size: 13),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.property.averageRating.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    ' (${widget.property.reviewCount})',
                                    style: TextStyle(
                                      color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: (widget.property.isAvailable ? Colors.green : Colors.red).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: widget.property.isAvailable ? Colors.green : Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  widget.property.isAvailable ? (isBuy ? 'For Sale' : 'Available') : 'Occupied / Sold',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: widget.property.isAvailable ? Colors.green : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Title
                      Text(widget.property.title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.25, color: isDark ? Colors.white : const Color(0xFF1E1E1E), letterSpacing: -0.5)),
                      const SizedBox(height: 8),

                      // Location & Address Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(CupertinoIcons.location_solid, color: Color(0xFFF59E0B), size: 16),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.property.locationStr,
                              style: TextStyle(
                                color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                                fontSize: 13.5,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ==========================================
                      // 3. PRICING & FINANCIAL SUMMARY CARD
                      // ==========================================
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCard : const Color(0xFFFAFAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isBuy ? 'TOTAL ASKING PRICE' : 'MONTHLY RENT',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade500,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      widget.property.price,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? AppTheme.primaryYellow : Colors.black,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                if (widget.property.securityDeposit != null && widget.property.securityDeposit!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppTheme.darkCardElevated : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          isBuy ? 'Token / Advance' : 'Deposit',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          widget.property.securityDeposit!,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            if ((widget.property.maintenanceCharges != null && widget.property.maintenanceCharges!.isNotEmpty) ||
                                (isPg && widget.property.perDayWithFood != null && widget.property.perDayWithFood!.isNotEmpty) ||
                                (isPg && widget.property.perDayWithoutFood != null && widget.property.perDayWithoutFood!.isNotEmpty)) ...[
                              Divider(
                                height: 20,
                                thickness: 1,
                                color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                              ),
                              if (widget.property.maintenanceCharges != null && widget.property.maintenanceCharges!.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(CupertinoIcons.doc_text_fill, size: 15, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                                          const SizedBox(width: 8),
                                          Text(
                                            isBuy ? 'Rate / Price per Unit' : 'Maintenance Charges',
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        widget.property.maintenanceCharges!,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if ((isPg && widget.property.perDayWithFood != null && widget.property.perDayWithFood!.isNotEmpty) ||
                                    (isPg && widget.property.perDayWithoutFood != null && widget.property.perDayWithoutFood!.isNotEmpty))
                                  Divider(height: 1, thickness: 1, color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
                              ],
                              if (isPg && widget.property.perDayWithFood != null && widget.property.perDayWithFood!.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(CupertinoIcons.calendar, size: 15, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Per Day (With Food)',
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '₹${widget.property.perDayWithFood}/day',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? AppTheme.primaryYellow : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isPg && widget.property.perDayWithoutFood != null && widget.property.perDayWithoutFood!.isNotEmpty)
                                  Divider(height: 1, thickness: 1, color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
                              ],
                              if (isPg && widget.property.perDayWithoutFood != null && widget.property.perDayWithoutFood!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(CupertinoIcons.calendar, size: 15, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Per Day (Without Food)',
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '₹${widget.property.perDayWithoutFood}/day',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? AppTheme.primaryYellow : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ==========================================
                      // 4. OVERVIEW / KEY PROPERTY SPECS
                      // ==========================================
                      _buildVerticalSectionCard(
                        title: isPg
                            ? 'Room & Occupancy Details'
                            : (isBuy ? 'Property Specifications & Dimensions' : 'Property Overview & Layout'),
                        icon: isPg ? CupertinoIcons.person_fill : (isBuy ? CupertinoIcons.building_2_fill : CupertinoIcons.house_fill),
                        items: [
                          if (isPg) ...[
                            if (widget.property.sharingType != null && widget.property.sharingType!.isNotEmpty)
                              {'icon': CupertinoIcons.person_2_fill, 'label': 'Room Sharing', 'value': widget.property.sharingType!},
                            if (widget.property.genderPreference != null && widget.property.genderPreference!.isNotEmpty)
                              {'icon': CupertinoIcons.person_fill, 'label': 'Gender Preference', 'value': widget.property.genderPreference!},
                            if (widget.property.bathroomType != null && widget.property.bathroomType!.isNotEmpty)
                              {'icon': CupertinoIcons.drop_fill, 'label': 'Bathroom Setup', 'value': widget.property.bathroomType!},
                            if (widget.property.area.isNotEmpty)
                              {'icon': CupertinoIcons.fullscreen, 'label': 'Carpet Area', 'value': widget.property.area},
                            if (widget.property.acType != null && widget.property.acType!.isNotEmpty)
                              {'icon': CupertinoIcons.wind, 'label': 'AC / Climate', 'value': widget.property.acType!},
                          ] else if (isBuy) ...[
                            if (widget.property.bhkType != null && widget.property.bhkType!.isNotEmpty)
                              {'icon': CupertinoIcons.house_fill, 'label': 'BHK Configuration', 'value': widget.property.bhkType!},
                            if (widget.property.baths.isNotEmpty)
                              {'icon': CupertinoIcons.arrow_swap, 'label': 'Facing Direction', 'value': widget.property.baths},
                            if (widget.property.area.isNotEmpty)
                              {'icon': CupertinoIcons.fullscreen, 'label': 'Plot & Built-up Space', 'value': widget.property.area},
                            if (widget.property.furnishingStatus != null && widget.property.furnishingStatus!.isNotEmpty)
                              {'icon': CupertinoIcons.lightbulb_fill, 'label': 'Furnishing & Interior', 'value': widget.property.furnishingStatus!},
                            if (widget.property.parkingInfo != null && widget.property.parkingInfo!.isNotEmpty)
                              {'icon': CupertinoIcons.car_detailed, 'label': 'Parking Space', 'value': widget.property.parkingInfo!},
                          ] else ...[
                            if (widget.property.bhkType != null && widget.property.bhkType!.isNotEmpty)
                              {'icon': CupertinoIcons.house_fill, 'label': 'BHK Configuration', 'value': widget.property.bhkType!},
                            if (widget.property.furnishingStatus != null && widget.property.furnishingStatus!.isNotEmpty)
                              {'icon': CupertinoIcons.lightbulb_fill, 'label': 'Furnishing Status', 'value': widget.property.furnishingStatus!},
                            if (widget.property.beds.isNotEmpty)
                              {'icon': CupertinoIcons.building_2_fill, 'label': 'Bedrooms', 'value': widget.property.beds},
                            if (widget.property.baths.isNotEmpty)
                              {'icon': CupertinoIcons.drop_fill, 'label': 'Bathrooms', 'value': widget.property.baths},
                            if (widget.property.area.isNotEmpty)
                              {'icon': CupertinoIcons.fullscreen, 'label': 'Super Built-up Area', 'value': widget.property.area},
                          ],
                        ],
                      ),

                      // ==========================================
                      // 5. DESCRIPTION
                      // ==========================================
                      _buildSectionHeader('Description', CupertinoIcons.doc_text_fill),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCard : const Color(0xFFFAFAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          widget.property.description ??
                              (isBuy
                                  ? 'Clear title property ready for immediate registration with modern construction and prime connectivity.'
                                  : 'Well-maintained property with essential amenities, good ventilation, and peaceful surroundings.'),
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade800,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ==========================================
                      // 6. DETAILED CATEGORY SECTIONS (LINE-BY-LINE)
                      // ==========================================
                      if (isPg) ...[
                        if (widget.property.foodMenu != null && widget.property.foodMenu!.isNotEmpty) ...[
                          _buildWeeklyFoodMenu(),
                          const SizedBox(height: 24),
                        ],
                        // Food, Mess & Drinking Water
                        _buildVerticalSectionCard(
                          title: 'Food, Mess & Dining',
                          icon: CupertinoIcons.circle_grid_hex,
                          items: [
                            if (widget.property.foodDetails != null)
                              {'icon': CupertinoIcons.circle_grid_hex, 'label': 'Meal Plan Included', 'value': widget.property.foodDetails!},
                            if (widget.property.foodQuality != null)
                              {'icon': CupertinoIcons.heart, 'label': 'Food Quality & Type', 'value': widget.property.foodQuality!},
                            if (widget.property.drinkingWater != null)
                              {'icon': CupertinoIcons.drop_fill, 'label': 'Drinking Water', 'value': widget.property.drinkingWater!},
                          ],
                        ),

                        // Utilities & Living Comfort
                        _buildVerticalSectionCard(
                          title: 'Utilities & Living Comfort',
                          icon: CupertinoIcons.bolt_fill,
                          items: [
                            if (widget.property.waterSupply != null)
                              {'icon': CupertinoIcons.drop_fill, 'label': 'Water Supply', 'value': widget.property.waterSupply!},
                            if (widget.property.powerBackup != null)
                              {'icon': CupertinoIcons.bolt_fill, 'label': 'Power Backup', 'value': widget.property.powerBackup!},
                            if (widget.property.acType != null)
                              {'icon': CupertinoIcons.wind, 'label': 'AC Setup', 'value': widget.property.acType!},
                            if (widget.property.bathroomType != null)
                              {'icon': CupertinoIcons.drop_fill, 'label': 'Bathroom Setup', 'value': widget.property.bathroomType!},
                          ],
                        ),

                        // Security, Hygiene & Housekeeping
                        _buildVerticalSectionCard(
                          title: 'Hygiene & Security',
                          icon: CupertinoIcons.shield_fill,
                          items: [
                            if (widget.property.cleanlinessInfo != null)
                              {'icon': CupertinoIcons.paintbrush, 'label': 'Housekeeping & Cleaning', 'value': widget.property.cleanlinessInfo!},
                            if (widget.property.securityInfo != null)
                              {'icon': CupertinoIcons.shield_fill, 'label': 'Security & CCTV', 'value': widget.property.securityInfo!},
                            if (widget.property.verificationPolicy != null)
                              {'icon': CupertinoIcons.shield_fill, 'label': 'ID Verification', 'value': widget.property.verificationPolicy!},
                          ],
                        ),

                        // Rules, Curfew & Management
                        _buildVerticalSectionCard(
                          title: 'Rules, Curfew & Management',
                          icon: CupertinoIcons.clock_fill,
                          items: [
                            if (widget.property.gateRules != null)
                              {'icon': CupertinoIcons.clock_fill, 'label': 'Gate Curfew / Timings', 'value': widget.property.gateRules!},
                            if (widget.property.noticePeriod != null)
                              {'icon': CupertinoIcons.calendar, 'label': 'Notice Period', 'value': widget.property.noticePeriod!},
                            if (widget.property.agreementDuration != null)
                              {'icon': CupertinoIcons.doc_text_fill, 'label': 'Agreement / Lock-in', 'value': widget.property.agreementDuration!},
                            if (widget.property.managementInfo != null)
                              {'icon': CupertinoIcons.person_fill, 'label': 'Warden / Management', 'value': widget.property.managementInfo!},
                          ],
                        ),
                      ] else if (isBuy) ...[
                        // Buy: Legal Clearances & Approvals
                        _buildVerticalSectionCard(
                          title: 'Legal Clearances & Approvals',
                          icon: CupertinoIcons.doc_text_fill,
                          items: [
                            if (widget.property.billsInfo != null)
                              {'icon': CupertinoIcons.shield_fill, 'label': 'Approvals & Clear Title', 'value': widget.property.billsInfo!},
                            if (widget.property.agreementDuration != null)
                              {'icon': CupertinoIcons.person_fill, 'label': 'Seller & Ownership Type', 'value': widget.property.agreementDuration!},
                            if (widget.property.tenantPreference != null)
                              {'icon': CupertinoIcons.tag_fill, 'label': 'Price Negotiability', 'value': widget.property.tenantPreference!},
                          ],
                        ),

                        // Buy: Road Access & Infrastructure
                        _buildVerticalSectionCard(
                          title: 'Road Access & Infrastructure',
                          icon: CupertinoIcons.arrow_swap,
                          items: [
                            if (widget.property.petPolicy != null)
                              {'icon': CupertinoIcons.arrow_swap, 'label': 'Connecting Road Width', 'value': widget.property.petPolicy!},
                            if (widget.property.meterStatus != null)
                              {'icon': CupertinoIcons.drop_fill, 'label': 'Water & Power Supply', 'value': widget.property.meterStatus!},
                            if (widget.property.parkingInfo != null)
                              {'icon': CupertinoIcons.car_detailed, 'label': 'Parking Infrastructure', 'value': widget.property.parkingInfo!},
                          ],
                        ),
                      ] else ...[
                        // Rental: Space & Physical Condition
                        _buildVerticalSectionCard(
                          title: 'Physical Condition & Fittings',
                          icon: CupertinoIcons.settings,
                          items: [
                            if (widget.property.bhkType != null)
                              {'icon': CupertinoIcons.house_fill, 'label': 'BHK Type', 'value': widget.property.bhkType!},
                            if (widget.property.furnishingStatus != null)
                              {'icon': CupertinoIcons.lightbulb_fill, 'label': 'Furnishing Status', 'value': widget.property.furnishingStatus!},
                            if (widget.property.plumbingStatus != null)
                              {'icon': CupertinoIcons.drop_fill, 'label': 'Plumbing & Drainage', 'value': widget.property.plumbingStatus!},
                            if (widget.property.seepageStatus != null)
                              {'icon': CupertinoIcons.shield_fill, 'label': 'Walls & Roof Seepage', 'value': widget.property.seepageStatus!},
                            if (widget.property.electricalStatus != null)
                              {'icon': CupertinoIcons.bolt_fill, 'label': 'Electrical Wiring', 'value': widget.property.electricalStatus!},
                          ],
                        ),

                        // Rental: Water, Electricity & Bills
                        _buildVerticalSectionCard(
                          title: 'Water, Electricity & Metering',
                          icon: CupertinoIcons.doc_text_fill,
                          items: [
                            if (widget.property.meterStatus != null)
                              {'icon': CupertinoIcons.bolt_fill, 'label': 'EB Metering', 'value': widget.property.meterStatus!},
                            if (widget.property.billsInfo != null)
                              {'icon': CupertinoIcons.doc_text_fill, 'label': 'Bills & Utilities Policy', 'value': widget.property.billsInfo!},
                            if (widget.property.waterSupply != null)
                              {'icon': CupertinoIcons.drop_fill, 'label': 'Water Facility', 'value': widget.property.waterSupply!},
                            if (widget.property.parkingInfo != null)
                              {'icon': CupertinoIcons.car_detailed, 'label': 'Parking Space', 'value': widget.property.parkingInfo!},
                          ],
                        ),

                        // Rental: Agreement & Policies
                        _buildVerticalSectionCard(
                          title: 'Rental Agreement & Policies',
                          icon: CupertinoIcons.doc_text_fill,
                          items: [
                            if (widget.property.agreementDuration != null)
                              {'icon': CupertinoIcons.doc_text_fill, 'label': 'Agreement Duration', 'value': widget.property.agreementDuration!},
                            if (widget.property.noticePeriod != null)
                              {'icon': CupertinoIcons.calendar, 'label': 'Notice Period', 'value': widget.property.noticePeriod!},
                            if (widget.property.tenantPreference != null)
                              {'icon': CupertinoIcons.person_2_fill, 'label': 'Tenant Preference', 'value': widget.property.tenantPreference!},
                            if (widget.property.petPolicy != null)
                              {'icon': CupertinoIcons.heart, 'label': 'Pet Policy', 'value': widget.property.petPolicy!},
                          ],
                        ),
                      ],

                      // ==========================================
                      // 7. FEATURES & AMENITIES
                      // ==========================================
                      () {
                        final filteredFeatures = _getFilteredFeatures();
                        if (filteredFeatures.isEmpty) return const SizedBox.shrink();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader('Features & Amenities', CupertinoIcons.checkmark_alt),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkCard : const Color(0xFFFAFAFC),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        for (int i = 0; i < filteredFeatures.length; i += 2)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Padding(
                                                  padding: EdgeInsets.only(top: 1),
                                                  child: Icon(CupertinoIcons.checkmark_alt, color: Color(0xFF10B981), size: 17),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    filteredFeatures[i],
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w700,
                                                      color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                                                      height: 1.35,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        for (int i = 1; i < filteredFeatures.length; i += 2)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Padding(
                                                  padding: EdgeInsets.only(top: 1),
                                                  child: Icon(CupertinoIcons.checkmark_alt, color: Color(0xFF10B981), size: 17),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    filteredFeatures[i],
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w700,
                                                      color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                                                      height: 1.35,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        );
                      }(),

                      // ==========================================
                      // 8. INTERACTIVE LOCATION MAP
                      // ==========================================
                      _buildSectionHeader('Location Map', CupertinoIcons.location_solid),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MapScreen(
                                latitude: widget.property.latitude,
                                longitude: widget.property.longitude,
                                title: widget.property.title,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          height: 190,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                              width: 1.2,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              IgnorePointer(
                                child: FlutterMap(
                                  options: MapOptions(
                                    initialCenter: LatLng(widget.property.latitude, widget.property.longitude),
                                    initialZoom: 14.0,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate: 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                                      userAgentPackageName: 'com.arkiolabs.rental',
                                      maxNativeZoom: 21,
                                      maxZoom: 22.0,
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: LatLng(widget.property.latitude, widget.property.longitude),
                                          width: 44,
                                          height: 44,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.3),
                                                  blurRadius: 8,
                                                ),
                                              ],
                                            ),
                                            child: const Icon(CupertinoIcons.location_solid, color: Colors.red, size: 28),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Map Action Overlay Pill
                              Positioned(
                                bottom: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppTheme.darkScaffold : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(CupertinoIcons.map_fill, size: 14, color: isDark ? AppTheme.primaryYellow : Colors.black),
                                      SizedBox(width: 5),
                                      Text(
                                        'Open Full Map',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ==========================================
                      // 8b. NEARBY TRANSPORT SECTION
                      // ==========================================
                      _buildTransportSection(),
                      const SizedBox(height: 24),

                      // ==========================================
                      // 9. CONTRIBUTE PHOTOS CARD
                      // ==========================================
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCard : const Color(0xFFFAFAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryYellow.withValues(alpha: isDark ? 0.15 : 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(CupertinoIcons.camera_fill, color: isDark ? AppTheme.primaryYellow : Colors.black, size: 22),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Help the Community',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Have more photos of this property? Contribute them.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            BouncingButton(
                              scaleFactor: 0.95,
                              onTap: _showContributePhotosSheet,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.darkCardElevated : Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  'Add',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppTheme.primaryYellow : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ==========================================
                      // 10. REVIEWS & RATINGS SECTION
                      // ==========================================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader('Reviews & Ratings', CupertinoIcons.star_fill),
                          BouncingButton(
                            scaleFactor: 0.95,
                            onTap: _showAddReviewSheet,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkCard : Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.pencil, size: 13, color: isDark ? AppTheme.primaryYellow : Colors.black87),
                                  SizedBox(width: 5),
                                  Text(
                                    _hasReviewed ? 'Edit Review' : 'Write Review',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppTheme.primaryYellow : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (widget.property.reviews.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkCard : const Color(0xFFFAFAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'No reviews yet. Be the first to share your experience!',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                            ),
                          ),
                        )
                      else
                        ...widget.property.reviews.map((r) => _buildReviewItem(r)),

                      // ==========================================
                      // 11. REPORT INCORRECT LISTING SECTION
                      // ==========================================
                      _buildReportListingSection(),

                      // ==========================================
                      // 12. BOTTOM FLAT RE-VERIFY NOTE (NO SHADOWS / NO BUTTONS)
                      // ==========================================
                      _buildReverifyNoteCard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // ==========================================
      // STICKY BOTTOM ACTION BAR (FULL WIDTH CALL OWNER)
      // ==========================================
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                // Full Width Call Owner Action Button
                Expanded(
                  child: BouncingButton(
                    scaleFactor: 0.96,
                    onTap: () => _launchPhone(widget.property.ownerPhone),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryYellow,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.phone_fill, color: accentTextColor, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Contact Owner',
                            style: TextStyle(
                              color: accentTextColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // WhatsApp Action Button
                BouncingButton(
                  scaleFactor: 0.90,
                  onTap: () => _launchWhatsApp(widget.property.ownerWhatsapp ?? widget.property.ownerPhone),
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: const BoxDecoration(
                      color: Color(0xFF25D366),
                      shape: BoxShape.circle,
                    ),
                    child: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAvailabilityBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkScaffold : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkScaffold : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF33333E) : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Is this property still vacant?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Help keeping the listings up to date for all renters.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.black),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: Text(
                        'Yes, Vacant',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          widget.property.isAvailable = false;
                        });
                        Navigator.pop(context);
                        AppSnackbar.success(context, 'Marked as Not Available');

                        if (widget.property.id != null && widget.property.id!.isNotEmpty) {
                          try {
                            await Supabase.instance.client.rpc(
                              'toggle_availability',
                              params: {'p_property_id': widget.property.id!, 'p_is_available': false},
                            );
                          } catch (e) {
                            debugPrint('Error updating availability: $e');
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      child: Text('No, Occupied', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    },
  );
}

  void _showRevokeConfirmationDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkScaffold : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkScaffold : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF33333E) : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Make Property Available?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to mark this property as Available? It will immediately show as active and vacant for all users.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.black),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          widget.property.isAvailable = true;
                        });
                        Navigator.pop(context);
                        AppSnackbar.success(context, 'Restored to Available');

                        if (widget.property.id != null && widget.property.id!.isNotEmpty) {
                          try {
                            await Supabase.instance.client.rpc(
                              'toggle_availability',
                              params: {'p_property_id': widget.property.id!, 'p_is_available': true},
                            );
                          } catch (e) {
                            debugPrint('Error updating availability: $e');
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A9E5B),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Yes, Available',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildReviewItem(dynamic review) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(5, (index) {
                return Icon(
                  index < (review['rating'] as num).toInt() ? CupertinoIcons.star_fill : CupertinoIcons.star_fill,
                  color: Colors.amber,
                  size: 14,
                );
              }),
              const SizedBox(width: 6),
              Text(
                '${(review['rating'] as num).toInt()}.0',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                review['date'] ?? '',
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade500,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review['text'] ?? '',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF2D2D2D),
            ),
          ),
          if (review['photos'] != null && (review['photos'] as List).isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: (review['photos'] as List).length,
                itemBuilder: (context, idx) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullScreenImageViewer(
                              imageUrls: List<String>.from(review['photos']),
                              initialIndex: idx,
                              isGrayscale: !widget.property.isAvailable,
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: !widget.property.isAvailable 
                          ? ColorFiltered(
                              colorFilter: const ColorFilter.matrix([
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0,      0,      0,      1, 0,
                              ]),
                              child: CachedNetworkImage(
                                imageUrl: review['photos'][idx],
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: review['photos'][idx],
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddReviewSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int rating = _myReview != null ? (_myReview!['rating'] as num).toInt() : 0;
    final TextEditingController reviewController =
        TextEditingController(text: _myReview != null ? _myReview!['text'] : '');
    List<File> selectedPhotos = [];
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.darkScaffold : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkScaffold : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF33333E) : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
              ),
              child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _myReview != null ? 'Edit Your Review' : 'Write a Review',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(CupertinoIcons.clear, size: 20),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (index) {
                        final isFilled = rating > 0 && index < rating;
                        return IconButton(
                          icon: Icon(
                            isFilled ? CupertinoIcons.star_fill : CupertinoIcons.star_fill,
                            color: isFilled ? Colors.amber : (isDark ? AppTheme.darkTextSecondary : Colors.grey.shade400),
                            size: 32,
                          ),
                          onPressed: () {
                            setModalState(() {
                              rating = index + 1;
                            });
                          },
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: reviewController,
                    maxLines: 4,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Share your genuine experience with this property...',
                      hintStyle: TextStyle(color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade400, fontSize: 13),
                      filled: true,
                      fillColor: isDark ? AppTheme.darkCard : const Color(0xFFFAFAFC),
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: isDark ? AppTheme.primaryYellow : Colors.black, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picker = ImagePicker();
                          final pickedFiles = await picker.pickMultiImage();
                          if (pickedFiles.isNotEmpty) {
                            setModalState(() {
                              selectedPhotos.addAll(pickedFiles.map((e) => File(e.path)));
                            });
                          }
                        },
                        icon: Icon(CupertinoIcons.camera_fill, color: isDark ? AppTheme.primaryYellow : Colors.black, size: 16),
                        label: Text(
                          'Add Photos',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                        ),
                      ),
                    ],
                  ),
                  if (selectedPhotos.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: selectedPhotos.length,
                        itemBuilder: (context, idx) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(selectedPhotos[idx], width: 60, height: 60, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        selectedPhotos.removeAt(idx);
                                      });
                                    },
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(2),
                                      child: const Icon(CupertinoIcons.clear, color: Colors.white, size: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (rating == 0) {
                                AppSnackbar.error(context, 'Please tap a star to give your rating');
                                return;
                              }
                              if (reviewController.text.trim().isEmpty) {
                                AppSnackbar.error(context, 'Please enter a review');
                                return;
                              }
                              setModalState(() => isSubmitting = true);

                              try {
                                final supabase = Supabase.instance.client;
                                List<String> photoUrls =
                                    _myReview != null ? List<String>.from(_myReview!['photos'] ?? []) : [];

                                if (selectedPhotos.isNotEmpty) {
                                  for (var file in selectedPhotos) {
                                    final cleanName = file.path.split(RegExp(r'[\\/]')).last.split('.').first.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
                                    final originalBytes = await file.readAsBytes();
                                    final result = await ImageCompressor.smartCompress(originalBytes);
                                    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$cleanName.${result.fileExtension}';
                                    await supabase.storage.from('property_images').uploadBinary(
                                      fileName,
                                      result.bytes,
                                      fileOptions: FileOptions(contentType: result.mimeType),
                                    );
                                    final url = supabase.storage.from('property_images').getPublicUrl(fileName);
                                    photoUrls.add(url);
                                  }
                                }

                                final newReview = {
                                  'rating': rating,
                                  'text': reviewController.text.trim(),
                                  'photos': photoUrls,
                                  'date': DateTime.now().toIso8601String().split('T').first,
                                  'device_id': _deviceId,
                                };

                                final updatedReviews = List<dynamic>.from(widget.property.reviews);
                                if (_hasReviewed && _myReview != null) {
                                  final index =
                                      updatedReviews.indexWhere((r) => r['device_id'] == _deviceId || r == _myReview);
                                  if (index != -1) {
                                    updatedReviews[index] = newReview;
                                  } else {
                                    updatedReviews.add(newReview);
                                  }
                                } else {
                                  updatedReviews.add(newReview);
                                }

                                await supabase.rpc(
                                  'add_property_review',
                                  params: {'p_property_id': widget.property.id!, 'p_review_data': newReview},
                                );

                                final prefs = await SharedPreferences.getInstance();
                                final reviewedProps = prefs.getStringList('reviewed_properties') ?? [];
                                if (widget.property.id != null && !reviewedProps.contains(widget.property.id)) {
                                  reviewedProps.add(widget.property.id!);
                                  await prefs.setStringList('reviewed_properties', reviewedProps);
                                }

                                if (mounted) {
                                  setState(() {
                                    widget.property.reviews = updatedReviews;
                                    _myReview = newReview;
                                    _hasReviewed = true;
                                  });
                                }

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  AppSnackbar.success(
                                    context,
                                    _hasReviewed ? 'Review updated successfully!' : 'Review added successfully!',
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  AppSnackbar.error(context, 'Failed to save review: ${AppSnackbar.getErrorMessage(e)}');
                                }
                              } finally {
                                if (mounted) {
                                  setModalState(() => isSubmitting = false);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppTheme.primaryYellow : Colors.black,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: isSubmitting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: isDark ? Colors.black : Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _myReview != null ? 'Update Review' : 'Submit Review',
                              style: TextStyle(
                                color: isDark ? Colors.black : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

  void _showContributePhotosSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    List<File> suggestedPhotos = [];
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.darkScaffold : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkScaffold : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF33333E) : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
              ),
              child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Contribute Photos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(CupertinoIcons.clear, size: 20),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Help fellow house-hunters by sharing photos of this property. They will appear after review.',
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final ImagePicker picker = ImagePicker();
                      final List<XFile> images = await picker.pickMultiImage();
                      if (images.isNotEmpty) {
                        setModalState(() {
                          suggestedPhotos.addAll(images.map((img) => File(img.path)));
                        });
                      }
                    },
                    icon: Icon(CupertinoIcons.photo_on_rectangle, color: isDark ? AppTheme.primaryYellow : Colors.black, size: 18),
                    label: Text(
                      'Select Photos from Gallery',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  if (suggestedPhotos.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 70,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: suggestedPhotos.length,
                        itemBuilder: (context, idx) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(suggestedPhotos[idx], width: 70, height: 70, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  right: 2,
                                  top: 2,
                                  child: GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        suggestedPhotos.removeAt(idx);
                                      });
                                    },
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(3),
                                      child: const Icon(CupertinoIcons.clear, color: Colors.white, size: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: suggestedPhotos.isEmpty || isSubmitting
                          ? null
                          : () async {
                              setModalState(() => isSubmitting = true);
                              try {
                                final supabase = Supabase.instance.client;
                                List<Map<String, dynamic>> newSuggestions = [];

                                for (var file in suggestedPhotos) {
                                  final cleanName = file.path.split(RegExp(r'[\\/]')).last.split('.').first.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
                                  final originalBytes = await file.readAsBytes();
                                  final result = await ImageCompressor.smartCompress(originalBytes);
                                  final fileName = '${DateTime.now().millisecondsSinceEpoch}_$cleanName.${result.fileExtension}';
                                  await supabase.storage.from('property_images').uploadBinary(
                                    fileName,
                                    result.bytes,
                                    fileOptions: FileOptions(contentType: result.mimeType),
                                  );
                                  final url = supabase.storage.from('property_images').getPublicUrl(fileName);
                                  newSuggestions.add({
                                    'url': url,
                                    'status': 'pending',
                                    'device_id': _deviceId,
                                    'date': DateTime.now().toIso8601String().split('T').first,
                                  });
                                }

                                final updatedSuggestions = List<dynamic>.from(widget.property.suggestedPhotos)
                                  ..addAll(newSuggestions);

                                await supabase.rpc(
                                  'add_suggested_photos',
                                  params: {'p_property_id': widget.property.id!, 'p_new_suggestions': newSuggestions},
                                );

                                if (mounted) {
                                  setState(() {
                                    widget.property.suggestedPhotos = updatedSuggestions;
                                  });
                                }

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  AppSnackbar.success(context, 'Photos submitted for approval!');
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  AppSnackbar.error(context, 'Failed to submit photos: ${AppSnackbar.getErrorMessage(e)}');
                                }
                              } finally {
                                if (mounted) {
                                  setModalState(() => isSubmitting = false);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: isDark ? AppTheme.primaryYellow : Colors.black,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: isSubmitting
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: isDark ? Colors.black : Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Submit Photos (${suggestedPhotos.length})',
                              style: TextStyle(
                                color: isDark ? Colors.black : Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

  // ==========================================
  // REPORT LISTING SECTION
  // ==========================================
  Widget _buildReportListingSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(CupertinoIcons.flag_fill, color: Colors.redAccent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report Incorrect Listing',
                  style: TextStyle(fontFamily: 'ProximaNova', 
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Wrong rent, unreachable phone, or wrong details?',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _showReportIncorrectInfoSheet,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              side: const BorderSide(color: Colors.redAccent, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(
              'Report',
              style: TextStyle(fontFamily: 'ProximaNova', 
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SIMPLE FLAT RE-VERIFY NOTE (NO SHADOWS, NO BUTTONS)
  // ==========================================
  Widget _buildReverifyNoteCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final type = widget.property.type;

    String ownerRoleName = 'Hostel / PG Owner';
    if (type == 'Rental') {
      ownerRoleName = 'Flat / House Owner';
    } else if (type == 'Buy' || type == 'Sale') {
      ownerRoleName = 'Property Seller';
    }

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1B20) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFFD97706).withValues(alpha: 0.3) : const Color(0xFFFDE68A),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.info_circle_fill,
            color: isDark ? AppTheme.primaryYellow : const Color(0xFFD97706),
            size: 17,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Note: Please re-verify property details, rent, deposit, and room availability directly with the $ownerRoleName before making any payment or advance agreements.',
              style: TextStyle(fontFamily: 'ProximaNova', 
                fontSize: 12,
                height: 1.4,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportIncorrectInfoSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String selectedReason = 'Wrong Monthly Rent / Deposit';
    final TextEditingController commentsController = TextEditingController();
    bool isSubmitting = false;

    final reasons = [
      'Wrong Monthly Rent / Deposit',
      'Phone Number Unreachable',
      'Property Already Rented / Occupied',
      'Fake or Misleading Photos',
      'Incorrect Location / Address',
      'Other Discrepancy',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.darkScaffold : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(CupertinoIcons.flag_fill, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Report Incorrect Information',
                            style: TextStyle(fontFamily: 'ProximaNova', 
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(CupertinoIcons.clear, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Help us keep listings accurate. What is incorrect about this post?',
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: reasons.map((r) {
                      final isSelected = selectedReason == r;
                      return ChoiceChip(
                        label: Text(r),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) setModalState(() => selectedReason = r);
                        },
                        selectedColor: Colors.redAccent.withValues(alpha: 0.2),
                        backgroundColor: isDark ? AppTheme.darkCard : Colors.grey.shade100,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        side: BorderSide(
                          color: isSelected ? Colors.redAccent : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                        ),
                        labelStyle: TextStyle(fontFamily: 'ProximaNova', 
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.redAccent : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: commentsController,
                    maxLines: 2,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Additional details (optional)...',
                      hintStyle: TextStyle(color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade400, fontSize: 12),
                      filled: true,
                      fillColor: isDark ? AppTheme.darkCard : const Color(0xFFFAFAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  BouncingButton(
                    onTap: isSubmitting
                        ? null
                        : () async {
                            setModalState(() => isSubmitting = true);
                            try {
                              // 1. Save report directly into Supabase listing_reports table
                              await Supabase.instance.client.from('listing_reports').insert({
                                'property_id': widget.property.id ?? '',
                                'property_title': widget.property.title,
                                'property_type': widget.property.type,
                                'owner_phone': widget.property.ownerPhone,
                                'reason': selectedReason,
                                'comments': commentsController.text.trim(),
                                'reporter_device_id': _deviceId,
                                'status': 'pending',
                                'created_at': DateTime.now().toIso8601String(),
                              });

                              // 2. Log analytics event
                              await AnalyticsService.instance.logEvent(
                                'report_listing',
                                category: widget.property.type,
                                itemId: widget.property.id,
                              );
                            } catch (e) {
                              debugPrint('Error saving report to Supabase: $e');
                            }
                            if (context.mounted) {
                              Navigator.pop(context);
                              AppSnackbar.success(
                                context,
                                'Thank you! Report submitted. Our team will verify with the owner.',
                              );
                            }
                          },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Center(
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                'Submit Report to Admin',
                                style: TextStyle(fontFamily: 'ProximaNova', 
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWeeklyFoodMenu() {
    if (widget.property.foodMenu == null || widget.property.foodMenu!.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Day order for display
    final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Weekly Food Menu', CupertinoIcons.calendar),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : AppTheme.lightBackground,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: DataTable(
                border: TableBorder.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder, 
                  width: 1.0,
                  borderRadius: BorderRadius.circular(16),
                ),
                headingRowColor: WidgetStateProperty.all(
                  isDark ? AppTheme.primaryAccent.withOpacity(0.15) : AppTheme.primaryAccent.withOpacity(0.1)
                ),
                dataRowMinHeight: 56,
                dataRowMaxHeight: double.infinity,
                columnSpacing: 32,
                headingTextStyle: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isDark ? AppTheme.primaryAccent : AppTheme.primaryDark,
                  letterSpacing: 0.5,
                ),
                dataTextStyle: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                columns: const [
                  DataColumn(label: Text('DAY')),
                  DataColumn(label: Text('Breakfast')),
                  DataColumn(label: Text('Lunch')),
                  DataColumn(label: Text('Snacks')),
                  DataColumn(label: Text('Dinner')),
                ],
                rows: days.where((day) => widget.property.foodMenu!.containsKey(day)).map((day) {
                  final dayData = widget.property.foodMenu![day] ?? {};
                  return DataRow(
                    cells: [
                      DataCell(
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Text(
                            day.substring(0, 3).toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      DataCell(Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(dayData['breakfast']?.toString() ?? '-'),
                      )),
                      DataCell(Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(dayData['lunch']?.toString() ?? '-'),
                      )),
                      DataCell(Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(dayData['snacks']?.toString() ?? '-'),
                      )),
                      DataCell(Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(dayData['dinner']?.toString() ?? '-'),
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}


