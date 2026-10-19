import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/core/models/property_model.dart';
import 'package:rental/core/widgets/bouncing_button.dart';

class PartnerPropertyCard extends StatelessWidget {
  final PropertyModel property;
  final ValueChanged<PropertyModel> onToggleAvailability;
  final VoidCallback onEdit;
  final VoidCallback onView;
  final VoidCallback onPromote;

  const PartnerPropertyCard({
    super.key,
    required this.property,
    required this.onToggleAvailability,
    required this.onEdit,
    required this.onView,
    required this.onPromote,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E222B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2C3240) : const Color(0xFFE5E7EB);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtextColor = isDark ? const Color(0xFF9E9E9E) : const Color(0xFF6B7280);

    final thumb = property.imageUrls.isNotEmpty ? property.imageUrls.first : '';
    final isApproved = property.status == 'approved';

    // Highlights / Specs
    final List<String> specs = [];
    if (property.beds.isNotEmpty && property.beds != '0') {
      specs.add('${property.beds} Beds');
    }
    if (property.baths.isNotEmpty && property.baths != '0') {
      specs.add('${property.baths} Baths');
    }
    if (property.bhkType != null && property.bhkType!.isNotEmpty) {
      specs.add(property.bhkType!);
    } else if (property.furnishingStatus != null && property.furnishingStatus!.isNotEmpty) {
      specs.add(property.furnishingStatus!);
    } else if (property.area.isNotEmpty) {
      specs.add('${property.area} sqft');
    }

    return BouncingButton(
      onTap: onView,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Main Row: Thumbnail + Property Details ───────────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Square Thumbnail (96x96)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 96,
                          height: 96,
                          child: Builder(
                            builder: (context) {
                              final hasValidUrl = thumb.isNotEmpty &&
                                  (thumb.startsWith('http://') || thumb.startsWith('https://'));

                              final placeholder = Container(
                                color: isDark ? const Color(0xFF262C38) : const Color(0xFFF3F4F6),
                                child: const Center(
                                  child: Icon(CupertinoIcons.photo, color: Colors.grey, size: 22),
                                ),
                              );

                              if (!hasValidUrl) {
                                return placeholder;
                              }

                              final image = CachedNetworkImage(
                                imageUrl: thumb,
                                fit: BoxFit.cover,
                                memCacheWidth: 400,
                                placeholder: (context, url) => placeholder,
                                errorWidget: (context, url, error) => placeholder,
                              );

                              if (property.isAvailable) {
                                return image;
                              }

                              return ColorFiltered(
                                colorFilter: const ColorFilter.matrix([
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0,      0,      0,      1, 0,
                                ]),
                                child: image,
                              );
                            },
                          ),
                        ),
                      ),

                      // Availability Pill over thumbnail
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: property.isAvailable
                                ? AppTheme.swiggyGreen
                                : AppTheme.swiggyRed,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            property.isAvailable ? 'LIVE' : 'OCCUPIED',
                            style: const TextStyle(
                              fontFamily: 'ProximaNova',
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),

                      // Property Type Pill on bottom of thumbnail
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            property.type.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'ProximaNova',
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryYellow,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Right: Property Information
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Verification status + Price
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isApproved
                                      ? CupertinoIcons.checkmark_seal_fill
                                      : CupertinoIcons.clock_fill,
                                  size: 13,
                                  color: isApproved ? AppTheme.swiggyGreen : const Color(0xFFFF9500),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isApproved ? 'Verified Partner' : 'Under Review',
                                  style: TextStyle(
                                    fontFamily: 'ProximaNova',
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: isApproved ? AppTheme.swiggyGreen : const Color(0xFFFF9500),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              property.price,
                              style: const TextStyle(
                                fontFamily: 'ProximaNova',
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFF5E3A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),

                        // Row 2: Title
                        Text(
                          property.title,
                          style: TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            height: 1.25,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),

                        // Row 3: Location
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.location_solid,
                              size: 12,
                              color: subtextColor,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                property.locationStr,
                                style: TextStyle(
                                  fontFamily: 'ProximaNova',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: subtextColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Row 4: Specs Chips
                        if (specs.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: specs.take(3).map((spec) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF262C38) : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  spec,
                                  style: TextStyle(
                                    fontFamily: 'ProximaNova',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: subtextColor,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Divider ─────────────────────────────────────────────
            Divider(height: 1, color: borderColor),

            // ── Bottom Action Strip (Clean & Compact) ────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Availability Toggle
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onToggleAvailability(property);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.scale(
                          scale: 0.72,
                          alignment: Alignment.centerLeft,
                          child: CupertinoSwitch(
                            value: property.isAvailable,
                            activeTrackColor: AppTheme.swiggyGreen,
                            onChanged: (_) => onToggleAvailability(property),
                          ),
                        ),
                        Text(
                          property.isAvailable ? 'Available' : 'Occupied',
                          style: TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: property.isAvailable
                                ? AppTheme.swiggyGreen
                                : AppTheme.swiggyRed,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action Buttons (Promote, Edit, View)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Promote Button
                      BouncingButton(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          onPromote();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5E3A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.flame_fill, size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Promote',
                                style: TextStyle(
                                  fontFamily: 'ProximaNova',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Edit Button
                      BouncingButton(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onEdit();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF262C38) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: Icon(
                            Iconsax.edit_2,
                            size: 15,
                            color: textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // View Details Button
                      BouncingButton(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onView();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF262C38) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: Icon(
                            Iconsax.eye,
                            size: 15,
                            color: textColor,
                          ),
                        ),
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
}
