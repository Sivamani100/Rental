import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/bouncing_button.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart' show PropertyModel;
import 'map_screen.dart';
import 'full_screen_image_viewer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/transport_service.dart';
import 'transport_street_view_screen.dart';

class PropertyDetailsScreen extends StatefulWidget {
  final PropertyModel property;

  const PropertyDetailsScreen({super.key, required this.property});

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
    _nearbyTransportFuture = TransportService.getNearby(
      widget.property.latitude,
      widget.property.longitude,
    );
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
        'Check out "${widget.property.title}" (${widget.property.type == 'PG' ? 'PG / Hostel' : (widget.property.type == 'Buy' || widget.property.type == 'Sale' ? 'Property for Sale' : 'Rental House')}) for ${widget.property.price} on Arkio Rental:\n$shareUrl';

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
    if (imagePath.startsWith('http')) {
      return CachedNetworkImage(
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
            child: Icon(Iconsax.image, color: Colors.grey, size: 40),
          ),
        ),
      );
    } else if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey.shade300,
          child: const Center(
            child: Icon(Iconsax.image, color: Colors.grey, size: 40),
          ),
        ),
      );
    } else if (kIsWeb) {
      return Image.network(
        imagePath,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey.shade300,
          child: const Center(
            child: Icon(Iconsax.image, color: Colors.grey, size: 40),
          ),
        ),
      );
    } else {
      return Image.file(
        File(imagePath),
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey.shade300,
          child: const Center(
            child: Icon(Iconsax.image, color: Colors.grey, size: 40),
          ),
        ),
      );
    }
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.8),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: iconColor ?? (isDark ? Colors.white : const Color(0xFF1E1E1E)),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  // --- Transport type styling helpers ---
  IconData _transportIcon(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('bus')) return Iconsax.bus;
    if (lower.contains('auto')) return Iconsax.car;
    if (lower.contains('train') || lower.contains('railway')) return Icons.train_outlined;
    if (lower.contains('metro')) return Icons.tram_outlined;
    if (lower.contains('airport') || lower.contains('aero')) return Iconsax.airplane;
    return Iconsax.location;
  }

  Widget _buildTransportSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Nearby Transport', Iconsax.bus),
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
                      child: Icon(Iconsax.info_circle, color: isDark ? AppTheme.primaryYellow : Colors.black, size: 22),
                    ),
                    const SizedBox(width: 14),
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
              Icon(Iconsax.info_circle, size: 14, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade400),
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
                              Icon(Iconsax.location, size: 14, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade500),
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
                      Icon(Iconsax.location, size: 14, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade500),
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
            return Column(
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
                        icon: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.black54),
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
                                    Icon(Icons.arrow_forward_ios, size: 10, color: primaryColor),
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
            color: isDark ? AppTheme.primaryYellow.withValues(alpha: 0.15) : const Color(0xFFFFEB3A).withValues(alpha: 0.3),
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
                icon: item['icon'] as IconData? ?? Iconsax.info_circle,
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
                              icon: Iconsax.arrow_left_2,
                              onTap: () => Navigator.pop(context),
                            ),
                            Row(
                              children: [
                                _buildGlassIconButton(
                                  icon: Icons.share_rounded,
                                  onTap: _shareProperty,
                                ),
                                const SizedBox(width: 10),
                                if (widget.property.isAvailable)
                                  _buildGlassIconButton(
                                    icon: Iconsax.slash,
                                    onTap: _showAvailabilityBottomSheet,
                                    iconColor: isDark ? Colors.white : const Color(0xFF1E1E1E),
                                  )
                                else
                                  _buildGlassIconButton(
                                    icon: Icons.undo_rounded,
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
                                      const Icon(Iconsax.gallery, color: Colors.white, size: 13),
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
                              color: isDark ? AppTheme.primaryYellow.withValues(alpha: 0.2) : const Color(0xFFFFEB3A),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPg ? Iconsax.building_3 : (isBuy ? Iconsax.shop : Iconsax.home_2),
                                  size: 13,
                                  color: isDark ? AppTheme.primaryYellow : Colors.black,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isPg ? 'PG / Hostel' : (isBuy ? 'For Sale (Buy)' : 'Rental House / Flat'),
                                  style: TextStyle(
                                    color: isDark ? AppTheme.primaryYellow : Colors.black,
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
                                  const Icon(Iconsax.star1, color: Colors.amber, size: 13),
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
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: '${widget.property.title} '),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Icon(
                                Iconsax.verify5,
                                size: 20,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Location & Address Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Iconsax.location5, color: Color(0xFFF59E0B), size: 16),
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
                                    const SizedBox(height: 2),
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
                                          Icon(Iconsax.receipt_item, size: 15, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
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
                                          Icon(Iconsax.calendar_1, size: 15, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
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
                                          Icon(Iconsax.calendar, size: 15, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
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
                        icon: isPg ? Iconsax.user : (isBuy ? Iconsax.building_3 : Iconsax.home_2),
                        items: [
                          if (isPg) ...[
                            if (widget.property.sharingType != null && widget.property.sharingType!.isNotEmpty)
                              {'icon': Iconsax.profile_2user, 'label': 'Room Sharing', 'value': widget.property.sharingType!},
                            if (widget.property.genderPreference != null && widget.property.genderPreference!.isNotEmpty)
                              {'icon': Iconsax.user, 'label': 'Gender Preference', 'value': widget.property.genderPreference!},
                            if (widget.property.bathroomType != null && widget.property.bathroomType!.isNotEmpty)
                              {'icon': Iconsax.drop, 'label': 'Bathroom Setup', 'value': widget.property.bathroomType!},
                            if (widget.property.area.isNotEmpty)
                              {'icon': Iconsax.maximize_4, 'label': 'Carpet Area', 'value': widget.property.area},
                            if (widget.property.acType != null && widget.property.acType!.isNotEmpty)
                              {'icon': Iconsax.wind_2, 'label': 'AC / Climate', 'value': widget.property.acType!},
                          ] else if (isBuy) ...[
                            if (widget.property.bhkType != null && widget.property.bhkType!.isNotEmpty)
                              {'icon': Iconsax.home_2, 'label': 'BHK Configuration', 'value': widget.property.bhkType!},
                            if (widget.property.baths.isNotEmpty)
                              {'icon': Iconsax.routing_2, 'label': 'Facing Direction', 'value': widget.property.baths},
                            if (widget.property.area.isNotEmpty)
                              {'icon': Iconsax.maximize_4, 'label': 'Plot & Built-up Space', 'value': widget.property.area},
                            if (widget.property.furnishingStatus != null && widget.property.furnishingStatus!.isNotEmpty)
                              {'icon': Iconsax.lamp_1, 'label': 'Furnishing & Interior', 'value': widget.property.furnishingStatus!},
                            if (widget.property.parkingInfo != null && widget.property.parkingInfo!.isNotEmpty)
                              {'icon': Iconsax.car, 'label': 'Parking Space', 'value': widget.property.parkingInfo!},
                          ] else ...[
                            if (widget.property.bhkType != null && widget.property.bhkType!.isNotEmpty)
                              {'icon': Iconsax.home_2, 'label': 'BHK Configuration', 'value': widget.property.bhkType!},
                            if (widget.property.furnishingStatus != null && widget.property.furnishingStatus!.isNotEmpty)
                              {'icon': Iconsax.lamp_1, 'label': 'Furnishing Status', 'value': widget.property.furnishingStatus!},
                            if (widget.property.beds.isNotEmpty)
                              {'icon': Iconsax.building_3, 'label': 'Bedrooms', 'value': widget.property.beds},
                            if (widget.property.baths.isNotEmpty)
                              {'icon': Iconsax.drop, 'label': 'Bathrooms', 'value': widget.property.baths},
                            if (widget.property.area.isNotEmpty)
                              {'icon': Iconsax.maximize_4, 'label': 'Super Built-up Area', 'value': widget.property.area},
                          ],
                        ],
                      ),

                      // ==========================================
                      // 5. DESCRIPTION
                      // ==========================================
                      _buildSectionHeader('Description', Iconsax.document_text),
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
                        // Food, Mess & Drinking Water
                        _buildVerticalSectionCard(
                          title: 'Food, Mess & Dining',
                          icon: Iconsax.coffee,
                          items: [
                            if (widget.property.foodDetails != null)
                              {'icon': Iconsax.coffee, 'label': 'Meal Plan Included', 'value': widget.property.foodDetails!},
                            if (widget.property.foodQuality != null)
                              {'icon': Iconsax.heart, 'label': 'Food Quality & Type', 'value': widget.property.foodQuality!},
                            if (widget.property.drinkingWater != null)
                              {'icon': Iconsax.drop, 'label': 'Drinking Water', 'value': widget.property.drinkingWater!},
                          ],
                        ),

                        // Utilities & Living Comfort
                        _buildVerticalSectionCard(
                          title: 'Utilities & Living Comfort',
                          icon: Iconsax.flash_1,
                          items: [
                            if (widget.property.waterSupply != null)
                              {'icon': Iconsax.drop, 'label': 'Water Supply', 'value': widget.property.waterSupply!},
                            if (widget.property.powerBackup != null)
                              {'icon': Iconsax.flash_1, 'label': 'Power Backup', 'value': widget.property.powerBackup!},
                            if (widget.property.acType != null)
                              {'icon': Iconsax.wind_2, 'label': 'AC Setup', 'value': widget.property.acType!},
                            if (widget.property.bathroomType != null)
                              {'icon': Iconsax.drop, 'label': 'Bathroom Setup', 'value': widget.property.bathroomType!},
                          ],
                        ),

                        // Security, Hygiene & Housekeeping
                        _buildVerticalSectionCard(
                          title: 'Hygiene & Security',
                          icon: Iconsax.shield_tick,
                          items: [
                            if (widget.property.cleanlinessInfo != null)
                              {'icon': Iconsax.broom, 'label': 'Housekeeping & Cleaning', 'value': widget.property.cleanlinessInfo!},
                            if (widget.property.securityInfo != null)
                              {'icon': Iconsax.shield_tick, 'label': 'Security & CCTV', 'value': widget.property.securityInfo!},
                            if (widget.property.verificationPolicy != null)
                              {'icon': Iconsax.security_user, 'label': 'ID Verification', 'value': widget.property.verificationPolicy!},
                          ],
                        ),

                        // Rules, Curfew & Management
                        _buildVerticalSectionCard(
                          title: 'Rules, Curfew & Management',
                          icon: Iconsax.clock,
                          items: [
                            if (widget.property.gateRules != null)
                              {'icon': Iconsax.clock, 'label': 'Gate Curfew / Timings', 'value': widget.property.gateRules!},
                            if (widget.property.noticePeriod != null)
                              {'icon': Iconsax.calendar, 'label': 'Notice Period', 'value': widget.property.noticePeriod!},
                            if (widget.property.agreementDuration != null)
                              {'icon': Iconsax.document_text, 'label': 'Agreement / Lock-in', 'value': widget.property.agreementDuration!},
                            if (widget.property.managementInfo != null)
                              {'icon': Iconsax.user_tag, 'label': 'Warden / Management', 'value': widget.property.managementInfo!},
                          ],
                        ),
                      ] else if (isBuy) ...[
                        // Buy: Legal Clearances & Approvals
                        _buildVerticalSectionCard(
                          title: 'Legal Clearances & Approvals',
                          icon: Iconsax.document_text,
                          items: [
                            if (widget.property.billsInfo != null)
                              {'icon': Iconsax.shield_tick, 'label': 'Approvals & Clear Title', 'value': widget.property.billsInfo!},
                            if (widget.property.agreementDuration != null)
                              {'icon': Iconsax.user_tag, 'label': 'Seller & Ownership Type', 'value': widget.property.agreementDuration!},
                            if (widget.property.tenantPreference != null)
                              {'icon': Iconsax.tag, 'label': 'Price Negotiability', 'value': widget.property.tenantPreference!},
                          ],
                        ),

                        // Buy: Road Access & Infrastructure
                        _buildVerticalSectionCard(
                          title: 'Road Access & Infrastructure',
                          icon: Iconsax.routing,
                          items: [
                            if (widget.property.petPolicy != null)
                              {'icon': Iconsax.routing, 'label': 'Connecting Road Width', 'value': widget.property.petPolicy!},
                            if (widget.property.meterStatus != null)
                              {'icon': Iconsax.drop, 'label': 'Water & Power Supply', 'value': widget.property.meterStatus!},
                            if (widget.property.parkingInfo != null)
                              {'icon': Iconsax.car, 'label': 'Parking Infrastructure', 'value': widget.property.parkingInfo!},
                          ],
                        ),
                      ] else ...[
                        // Rental: Space & Physical Condition
                        _buildVerticalSectionCard(
                          title: 'Physical Condition & Fittings',
                          icon: Iconsax.setting_2,
                          items: [
                            if (widget.property.bhkType != null)
                              {'icon': Iconsax.home_2, 'label': 'BHK Type', 'value': widget.property.bhkType!},
                            if (widget.property.furnishingStatus != null)
                              {'icon': Iconsax.lamp_1, 'label': 'Furnishing Status', 'value': widget.property.furnishingStatus!},
                            if (widget.property.plumbingStatus != null)
                              {'icon': Iconsax.drop, 'label': 'Plumbing & Drainage', 'value': widget.property.plumbingStatus!},
                            if (widget.property.seepageStatus != null)
                              {'icon': Iconsax.shield, 'label': 'Walls & Roof Seepage', 'value': widget.property.seepageStatus!},
                            if (widget.property.electricalStatus != null)
                              {'icon': Iconsax.flash_1, 'label': 'Electrical Wiring', 'value': widget.property.electricalStatus!},
                          ],
                        ),

                        // Rental: Water, Electricity & Bills
                        _buildVerticalSectionCard(
                          title: 'Water, Electricity & Metering',
                          icon: Iconsax.receipt_item,
                          items: [
                            if (widget.property.meterStatus != null)
                              {'icon': Iconsax.flash_1, 'label': 'EB Metering', 'value': widget.property.meterStatus!},
                            if (widget.property.billsInfo != null)
                              {'icon': Iconsax.receipt_item, 'label': 'Bills & Utilities Policy', 'value': widget.property.billsInfo!},
                            if (widget.property.waterSupply != null)
                              {'icon': Iconsax.drop, 'label': 'Water Facility', 'value': widget.property.waterSupply!},
                            if (widget.property.parkingInfo != null)
                              {'icon': Iconsax.car, 'label': 'Parking Space', 'value': widget.property.parkingInfo!},
                          ],
                        ),

                        // Rental: Agreement & Policies
                        _buildVerticalSectionCard(
                          title: 'Rental Agreement & Policies',
                          icon: Iconsax.document_text,
                          items: [
                            if (widget.property.agreementDuration != null)
                              {'icon': Iconsax.document_text, 'label': 'Agreement Duration', 'value': widget.property.agreementDuration!},
                            if (widget.property.noticePeriod != null)
                              {'icon': Iconsax.calendar, 'label': 'Notice Period', 'value': widget.property.noticePeriod!},
                            if (widget.property.tenantPreference != null)
                              {'icon': Iconsax.profile_2user, 'label': 'Tenant Preference', 'value': widget.property.tenantPreference!},
                            if (widget.property.petPolicy != null)
                              {'icon': Iconsax.heart, 'label': 'Pet Policy', 'value': widget.property.petPolicy!},
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
                            _buildSectionHeader('Features & Amenities', Iconsax.tick_circle),
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
                                                  child: Icon(Iconsax.tick_circle, color: Color(0xFF10B981), size: 17),
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
                                                  child: Icon(Iconsax.tick_circle, color: Color(0xFF10B981), size: 17),
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
                      _buildSectionHeader('Location Map', Iconsax.location),
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
                                      urlTemplate: 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
                                      userAgentPackageName: 'com.example.rental',
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
                                            child: const Icon(Iconsax.location5, color: Colors.red, size: 28),
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
                                      Icon(Iconsax.map_1, size: 14, color: isDark ? AppTheme.primaryYellow : Colors.black),
                                      const SizedBox(width: 5),
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
                                color: isDark ? AppTheme.primaryYellow.withValues(alpha: 0.15) : const Color(0xFFFFEB3A).withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Iconsax.camera, color: isDark ? AppTheme.primaryYellow : Colors.black, size: 22),
                            ),
                            const SizedBox(width: 12),
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
                          _buildSectionHeader('Reviews & Ratings', Iconsax.star),
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
                                  Icon(Iconsax.edit_2, size: 13, color: isDark ? AppTheme.primaryYellow : Colors.black87),
                                  const SizedBox(width: 5),
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
              offset: const Offset(0, -4),
              blurRadius: 16,
            ),
          ],
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
                        color: const Color(0xFFFFEB3A),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFEB3A).withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Iconsax.call, color: Colors.black, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Contact Owner',
                            style: TextStyle(
                              color: Colors.black,
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
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF25D366).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
        return Padding(
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
                            await Supabase.instance.client
                                .from('properties')
                                .update({'is_available': false})
                                .eq('id', widget.property.id!);
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
                      child: const Text('No, Occupied', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
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
        return Padding(
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
                            await Supabase.instance.client
                                .from('properties')
                                .update({'is_available': true})
                                .eq('id', widget.property.id!);
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
                  index < (review['rating'] as num).toInt() ? Iconsax.star1 : Iconsax.star,
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
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
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
            return Padding(
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
                        icon: const Icon(Icons.close, size: 20),
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
                            isFilled ? Iconsax.star1 : Iconsax.star,
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
                        icon: Icon(Iconsax.camera, color: isDark ? AppTheme.primaryYellow : Colors.black, size: 16),
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
                                      child: const Icon(Icons.close, color: Colors.white, size: 14),
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
                                    final fileName =
                                        '${DateTime.now().millisecondsSinceEpoch}_${file.path.split(Platform.pathSeparator).last}';
                                    await supabase.storage.from('property_images').upload(fileName, file);
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

                                await supabase
                                    .from('properties')
                                    .update({'reviews': updatedReviews}).eq('id', widget.property.id!);

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
                                  AppSnackbar.error(context, 'Failed to save review: $e');
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
            return Padding(
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
                        icon: const Icon(Icons.close, size: 20),
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
                    icon: Icon(Iconsax.gallery_add, color: isDark ? AppTheme.primaryYellow : Colors.black, size: 18),
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
                                      child: const Icon(Icons.close, color: Colors.white, size: 14),
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
                                  final fileName =
                                      '${DateTime.now().millisecondsSinceEpoch}_${file.path.split(Platform.pathSeparator).last}';
                                  await supabase.storage.from('property_images').upload(fileName, file);
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

                                await supabase
                                    .from('properties')
                                    .update({'suggested_photos': updatedSuggestions}).eq('id', widget.property.id!);

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
                                  AppSnackbar.error(context, 'Failed to submit photos: $e');
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
            );
          },
        );
      },
    );
  }
}
