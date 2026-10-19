import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax/iconsax.dart';

import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/core/models/property_model.dart';
import 'package:rental/core/widgets/app_snackbar.dart';
import 'package:rental/core/widgets/bouncing_button.dart';
import 'package:rental/features/partner/data/models/partner_promotion_model.dart';
import 'package:rental/features/partner/data/services/partner_service.dart';
import 'package:rental/features/partner/presentation/widgets/partner_create_promotion_sheet.dart';

class PartnerPromoteTab extends StatefulWidget {
  final VoidCallback onRefresh;
  final ValueChanged<int>? onNavigateTab;

  const PartnerPromoteTab({
    super.key,
    required this.onRefresh,
    this.onNavigateTab,
  });

  @override
  State<PartnerPromoteTab> createState() => _PartnerPromoteTabState();
}

class _PartnerPromoteTabState extends State<PartnerPromoteTab> {
  int _selectedTypeIndex = 0; // 0: In-App, 1: External
  PropertyModel? _selectedProperty;

  @override
  void initState() {
    super.initState();
    final properties = PartnerService.instance.myProperties;
    if (properties.isNotEmpty) {
      _selectedProperty = properties.first;
    }
  }

  void _openPromotionSheet({required String type, PropertyModel? property}) {
    HapticFeedback.mediumImpact();
    PartnerCreatePromotionSheet.show(
      context,
      initialProperty: property ?? _selectedProperty,
      initialType: type,
    ).then((_) => widget.onRefresh());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E222B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2C3240) : const Color(0xFFE5E7EB);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtextColor = isDark ? const Color(0xFF9E9E9E) : const Color(0xFF6B7280);

    final allProperties = PartnerService.instance.myProperties;
    final allPromotions = PartnerService.instance.myPromotions;

    PartnerPromotionModel? activePromo;
    if (_selectedProperty != null) {
      for (final p in allPromotions) {
        final matchesId = _selectedProperty!.id != null && p.propertyId == _selectedProperty!.id;
        final matchesTitle = p.propertyTitle.toLowerCase().trim() == _selectedProperty!.title.toLowerCase().trim();
        if ((matchesId || matchesTitle) && (p.isActive || p.isPending)) {
          activePromo = p;
          break;
        }
      }
    }

    final realTotalViews = allProperties.fold<int>(0, (sum, p) => sum + p.viewsCount);
    final realActiveBoosts = allPromotions.where((p) => p.isActive).length;
    final realTotalLeads = allPromotions.fold<int>(0, (sum, p) => sum + p.inquiries);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Real Dynamic Impact Summary (Zero Fake Multipliers) ─────────
          Row(
            children: [
              _buildImpactCapsule(
                '$realActiveBoosts',
                'Active Boosts',
                CupertinoIcons.flame_fill,
                const Color(0xFFFF5722),
                isDark,
              ),
              const SizedBox(width: 8),
              _buildImpactCapsule(
                '$realTotalViews',
                'Total Views',
                CupertinoIcons.eye_fill,
                const Color(0xFF007AFF),
                isDark,
              ),
              const SizedBox(width: 8),
              _buildImpactCapsule(
                '$realTotalLeads',
                'Verified Leads',
                CupertinoIcons.chat_bubble_2_fill,
                AppTheme.swiggyGreen,
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── 2. Live Promoted Card Preview (Visual Mockup) ────────
          if (_selectedProperty != null) ...[
            _buildLiveMockupPreview(cardColor, borderColor, textColor, subtextColor, isDark),
            const SizedBox(height: 14),
          ],

          // ── 3. Promotions & 5km Radius Priority Tracker ──────────
          if (allPromotions.isNotEmpty) ...[
            _buildPromotionsTracker(allPromotions, cardColor, borderColor, textColor, subtextColor, isDark),
            const SizedBox(height: 16),
          ],

          // ── 4. Property Selector Pill ────────────────────────────
          if (allProperties.isNotEmpty) ...[
            _buildPropertySelector(allProperties, cardColor, borderColor, textColor, subtextColor, isDark),
            const SizedBox(height: 14),
          ],

          // ── 5. Segment Switcher: In-App vs External Ads ──────────
          Container(
            height: 42,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF15181E) : const Color(0xFFE9ECF0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedTypeIndex = 0);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _selectedTypeIndex == 0 ? cardColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: _selectedTypeIndex == 0
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Iconsax.crown5,
                            size: 15,
                            color: _selectedTypeIndex == 0 ? Colors.black : subtextColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Show First in App',
                            style: TextStyle(
                              fontFamily: 'ProximaNova',
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              color: _selectedTypeIndex == 0 ? textColor : subtextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedTypeIndex = 1);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _selectedTypeIndex == 1 ? cardColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: _selectedTypeIndex == 1
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Iconsax.global,
                            size: 15,
                            color: _selectedTypeIndex == 1 ? const Color(0xFF007AFF) : subtextColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'External Ads (Soon)',
                            style: TextStyle(
                              fontFamily: 'ProximaNova',
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              color: _selectedTypeIndex == 1 ? textColor : subtextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── 6. In-App: Active Promotion Status vs Purchase Packages vs External
          if (allProperties.isEmpty) ...[
            _buildNoPropertiesState(cardColor, borderColor, textColor, subtextColor, isDark),
          ] else if (_selectedTypeIndex == 0) ...[
            if (activePromo != null) ...[
              _buildActivePromotionDetails(
                activePromo,
                _selectedProperty,
                cardColor,
                borderColor,
                textColor,
                subtextColor,
                isDark,
              ),
            ] else ...[
              _buildVisualPlanCard(
                title: 'Featured Starter',
                badge: 'SHOW FIRST',
                badgeColor: const Color(0xFF007AFF),
                price: '₹299',
                duration: '3 Days',
                reachEst: 'Show First in Locality',
                features: [
                  'Show First in Locality Search Results',
                  'Priority placement within 5km radius',
                  'Direct Call & WhatsApp Lead Routing',
                ],
                buttonText: 'Feature for 3 Days',
                buttonColor: AppTheme.primaryYellow,
                buttonTextColor: Colors.black,
                onTap: () => _openPromotionSheet(type: 'in_app'),
                cardColor: cardColor,
                borderColor: borderColor,
                textColor: textColor,
                subtextColor: subtextColor,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildVisualPlanCard(
                title: 'Top Rank Featured Booster',
                badge: 'MOST POPULAR',
                badgeColor: const Color(0xFFFF5E3A),
                price: '₹599',
                duration: '7 Days',
                reachEst: 'Top Rank Priority (5km Radius)',
                isHighlighted: true,
                features: [
                  'Pinned to Rank #1 for 7 Full Days',
                  'Instant 5km mobile feed search priority',
                  'Direct WhatsApp & Call Lead Routing',
                ],
                buttonText: 'Feature & Show First (7 Days)',
                buttonColor: const Color(0xFFFF5E3A),
                buttonTextColor: Colors.white,
                onTap: () => _openPromotionSheet(type: 'in_app'),
                cardColor: cardColor,
                borderColor: borderColor,
                textColor: textColor,
                subtextColor: subtextColor,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildVisualPlanCard(
                title: 'Mega Featured Blitz',
                badge: 'MAX ACCELERATION',
                badgeColor: const Color(0xFF5856D6),
                price: '₹1,199',
                duration: '15 Days',
                reachEst: '15 Days Top Priority Rank',
                features: [
                  'Permanent Rank #1 in locality search',
                  'Extended 15-day priority spotlight',
                  'Priority Landlord Lead Channel Support',
                ],
                buttonText: 'Activate Mega Featured Blitz',
                buttonColor: const Color(0xFF5856D6),
                buttonTextColor: Colors.white,
                onTap: () => _openPromotionSheet(type: 'in_app'),
                cardColor: cardColor,
                borderColor: borderColor,
                textColor: textColor,
                subtextColor: subtextColor,
                isDark: isDark,
              ),
            ],
          ] else ...[
            _buildExternalComingSoon(cardColor, borderColor, textColor, subtextColor, isDark),
          ],

          const SizedBox(height: 36),
        ],
      ),
    );
  }

  // ── 1. Impact Capsule ─────────────────────────────────────────
  Widget _buildImpactCapsule(
    String val,
    String label,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              val,
              style: TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── Active Promotion Details Card (Displayed when already promoted) ──
  Widget _buildActivePromotionDetails(
    PartnerPromotionModel promo,
    PropertyModel? property,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color subtextColor,
    bool isDark,
  ) {
    final isPend = promo.isPending;
    final isLive = promo.isActive || promo.isApproved;
    final realViews = property?.viewsCount ?? promo.impressions;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPend
              ? const Color(0xFFFFB800).withValues(alpha: 0.6)
              : (isLive ? AppTheme.swiggyGreen.withValues(alpha: 0.6) : borderColor),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isPend ? const Color(0xFFFFB800) : AppTheme.swiggyGreen)
                .withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Status Badge + Priority Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: isPend
                      ? const Color(0xFFFFB800).withValues(alpha: 0.15)
                      : AppTheme.swiggyGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isPend
                        ? const Color(0xFFFFB800).withValues(alpha: 0.4)
                        : AppTheme.swiggyGreen.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPend ? CupertinoIcons.time_solid : CupertinoIcons.flame_fill,
                      size: 13,
                      color: isPend ? const Color(0xFFFFB800) : AppTheme.swiggyGreen,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isPend ? 'PENDING ADMIN APPROVAL' : 'ACTIVE • RANK #${promo.priorityPosition}',
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: isPend ? const Color(0xFFFFB800) : AppTheme.swiggyGreen,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLive && promo.daysRemaining > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF15181E) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${promo.daysRemaining} days left',
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Title & Package Info
          Text(
            promo.propertyTitle,
            style: TextStyle(
              fontFamily: 'ProximaNova',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            'Package: ${promo.packageName} • ${promo.price} (${promo.durationDays} Days Duration)',
            style: TextStyle(
              fontFamily: 'ProximaNova',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: subtextColor,
            ),
          ),
          const SizedBox(height: 12),

          // Message banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF15181E) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Icon(
                  isPend ? Iconsax.info_circle : Iconsax.verify5,
                  size: 18,
                  color: isPend ? const Color(0xFFFFB800) : AppTheme.swiggyGreen,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isPend
                        ? 'Your promotion is under admin review. Once approved, it will be prioritized #1 in search results within a 5.0 km radius.'
                        : 'Your listing is actively boosted! Seekers within 5.0 km radius see this property at the very top of their search results.',
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Live Performance Metrics for this property
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF15181E) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$realViews',
                        style: const TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Property Views',
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF15181E) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${promo.clicks}',
                        style: const TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFF5722),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Clicks',
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF15181E) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${promo.inquiries}',
                        style: const TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.swiggyGreen,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Leads Generated',
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Helper note
          Center(
            child: Text(
              'No further promotion payment needed for this listing.',
              style: TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: subtextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPropertiesState(
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color subtextColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(Iconsax.buildings, size: 40, color: subtextColor),
          const SizedBox(height: 12),
          Text(
            'No Properties Associated',
            style: TextStyle(
              fontFamily: 'ProximaNova',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Upload or claim a listing first under this partner account to activate locality promotions and 5.0 km boost.',
            style: TextStyle(
              fontFamily: 'ProximaNova',
              fontSize: 12,
              color: subtextColor,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── 2. Live Mockup Preview Card ───────────────────────────────
  Widget _buildLiveMockupPreview(
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color subtextColor,
    bool isDark,
  ) {
    final previewProp = _selectedProperty;
    final title = previewProp?.title ?? 'Skyline 2BHK Luxury Apartment';
    final price = previewProp?.price ?? '₹28,000/mo';
    final location = previewProp?.locationStr ?? 'Koramangala, Bangalore';
    final thumb = previewProp?.imageUrls.isNotEmpty == true ? previewProp!.imageUrls.first : '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryYellow.withValues(alpha: 0.7), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryYellow.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryYellow,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.flame_fill, size: 10, color: Colors.black),
                    SizedBox(width: 3),
                    Text(
                      'PROMOTED PREVIEW',
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Rank #1 in Search',
                style: TextStyle(
                  fontFamily: 'ProximaNova',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.swiggyGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Mini horizontal preview card
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: thumb.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: thumb,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(color: Colors.grey.shade300),
                        )
                      : Container(
                          color: isDark ? const Color(0xFF262C38) : const Color(0xFFF3F4F6),
                          child: const Icon(Iconsax.building, size: 20, color: Colors.grey),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      location,
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 11,
                        color: subtextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      price,
                      style: const TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFF5E3A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 3. Promotions & 5km Radius Priority Tracker ──────────────
  Widget _buildPromotionsTracker(
    List<PartnerPromotionModel> promotionsList,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color subtextColor,
    bool isDark,
  ) {
    final pendingCount = promotionsList.where((p) => p.isPending).length;
    final liveCount = promotionsList.where((p) => p.isApproved || p.isActive).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: liveCount > 0 ? AppTheme.swiggyGreen : const Color(0xFFFFB800),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'YOUR PROMOTIONS & 5KM BOOSTS (${promotionsList.length})',
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: subtextColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            if (pendingCount > 0)
              Text(
                '$pendingCount awaiting admin ranking',
                style: const TextStyle(
                  fontFamily: 'ProximaNova',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFFB800),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ...promotionsList.map((promo) {
          final isPend = promo.isPending;
          final isLive = promo.isApproved || promo.isActive;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isPend
                    ? const Color(0xFFFFB800).withValues(alpha: 0.4)
                    : (isLive ? AppTheme.swiggyGreen.withValues(alpha: 0.4) : borderColor),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            promo.propertyTitle,
                            style: TextStyle(
                              fontFamily: 'ProximaNova',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${promo.packageName} • ${promo.price} • ${promo.durationDays} Days',
                            style: TextStyle(
                              fontFamily: 'ProximaNova',
                              fontSize: 11.5,
                              color: subtextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: isPend
                            ? const Color(0xFFFFB800).withValues(alpha: 0.15)
                            : (isLive
                                ? AppTheme.swiggyGreen.withValues(alpha: 0.15)
                                : const Color(0xFFEF4444).withValues(alpha: 0.15)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isPend
                            ? 'PENDING APPROVAL'
                            : (isLive
                                ? 'ACTIVE • RANK #${promo.priorityPosition}'
                                : 'DECLINED'),
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isPend
                              ? const Color(0xFFFFB800)
                              : (isLive ? AppTheme.swiggyGreen : const Color(0xFFEF4444)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isPend
                      ? '⏳ Admin is reviewing and setting priority ranking (1, 2, 3...) for 5.0 km mobile feed boost.'
                      : (isLive
                          ? '⚡ Pinned to rank #${promo.priorityPosition} within 5.0 km search radius • ${promo.daysRemaining} days left'
                          : 'Promotion request was declined by admin.'),
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 11,
                    color: isPend ? const Color(0xFFFFB800) : subtextColor,
                    height: 1.3,
                  ),
                ),
                if (isLive) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF15181E) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(
                          '${promo.impressions} Views',
                          style: TextStyle(fontFamily: 'ProximaNova', fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
                        ),
                        Text('•', style: TextStyle(color: subtextColor)),
                        Text(
                          '${promo.clicks} Clicks',
                          style: TextStyle(fontFamily: 'ProximaNova', fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
                        ),
                        Text('•', style: TextStyle(color: subtextColor)),
                        Text(
                          '${promo.inquiries} Leads',
                          style: TextStyle(fontFamily: 'ProximaNova', fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.swiggyGreen),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── 4. Property Selector Pill ─────────────────────────────────
  Widget _buildPropertySelector(
    List<PropertyModel> properties,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color subtextColor,
    bool isDark,
  ) {
    if (properties.isEmpty) return const SizedBox.shrink();

    // Deduplicate properties by ID/title to prevent any duplicate dropdown item assertion
    final uniqueMap = <String, PropertyModel>{};
    for (final p in properties) {
      final key = p.id ?? p.title;
      uniqueMap[key] = p;
    }
    final distinctList = uniqueMap.values.toList();
    if (distinctList.isEmpty) return const SizedBox.shrink();

    final safeSelected = distinctList.any((p) => p == _selectedProperty)
        ? distinctList.firstWhere((p) => p == _selectedProperty)
        : distinctList.first;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<PropertyModel>(
          value: safeSelected,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF1E222B) : Colors.white,
          icon: Icon(Iconsax.arrow_down_1, size: 16, color: textColor),
          items: distinctList.map((p) {
            return DropdownMenuItem<PropertyModel>(
              value: p,
              child: Row(
                children: [
                  const Icon(Iconsax.building_3, size: 16, color: Colors.black),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p.title,
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    p.price,
                    style: const TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFF5E3A),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (newProp) {
            if (newProp != null) {
              setState(() => _selectedProperty = newProp);
            }
          },
        ),
      ),
    );
  }

  // ── 5. Visual Plan Card ───────────────────────────────────────
  Widget _buildVisualPlanCard({
    required String title,
    required String badge,
    required Color badgeColor,
    required String price,
    required String duration,
    required String reachEst,
    bool isHighlighted = false,
    List<String>? channels,
    required List<String> features,
    required String buttonText,
    required Color buttonColor,
    required Color buttonTextColor,
    required VoidCallback onTap,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? badgeColor : borderColor,
          width: isHighlighted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isHighlighted ? badgeColor : Colors.black).withValues(alpha: isHighlighted ? 0.15 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Badge + Duration
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF262C38) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  duration,
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Title and Price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ),
              Text(
                price,
                style: TextStyle(
                  fontFamily: 'ProximaNova',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Reach Capsule
          Row(
            children: [
              Icon(Iconsax.eye, size: 13, color: subtextColor),
              const SizedBox(width: 4),
              Text(
                reachEst,
                style: TextStyle(
                  fontFamily: 'ProximaNova',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: subtextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Channels row if external
          if (channels != null) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: channels.map((ch) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF262C38) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    ch,
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],

          // Visual Feature Bullets
          ...features.map((feat) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Iconsax.tick_circle5, size: 14, color: AppTheme.swiggyGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feat,
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),

          // Action Button
          BouncingButton(
            onTap: onTap,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: buttonColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.flame_fill, size: 14, color: buttonTextColor),
                  const SizedBox(width: 6),
                  Text(
                    buttonText,
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: buttonTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 7. External Promotions: Coming Soon ───────────────────────
  Widget _buildExternalComingSoon(
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color subtextColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'COMING SOON',
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF007AFF),
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Iconsax.global, size: 18, color: Color(0xFF007AFF)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'External Ad Campaigns',
            style: TextStyle(
              fontFamily: 'ProximaNova',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Attract renters from outside the app with automated ad campaigns tailored for your locality.',
            style: TextStyle(
              fontFamily: 'ProximaNova',
              fontSize: 13,
              height: 1.35,
              color: subtextColor,
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: borderColor),
          const SizedBox(height: 16),

          Text(
            'UPCOMING CHANNELS',
            style: TextStyle(
              fontFamily: 'ProximaNova',
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: subtextColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),

          // Channel Items
          _buildUpcomingChannelItem(
            icon: Iconsax.instagram,
            iconColor: const Color(0xFFE1306C),
            title: 'Instagram & Facebook Ads',
            subtitle: 'Targeted reel & feed ads to active renters in your 5km radius.',
            textColor: textColor,
            subtextColor: subtextColor,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildUpcomingChannelItem(
            icon: Iconsax.search_normal_1,
            iconColor: const Color(0xFF4285F4),
            title: 'Google Search Campaigns',
            subtitle: 'Show at the top when tenants search "houses for rent near me".',
            textColor: textColor,
            subtextColor: subtextColor,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildUpcomingChannelItem(
            icon: Iconsax.message_2,
            iconColor: AppTheme.swiggyGreen,
            title: 'Direct WhatsApp Routing',
            subtitle: 'External clicks route immediately into direct WhatsApp inquiries.',
            textColor: textColor,
            subtextColor: subtextColor,
            isDark: isDark,
          ),
          const SizedBox(height: 18),

          // Early Access / Notify Me Button
          BouncingButton(
            onTap: () {
              HapticFeedback.mediumImpact();
              AppSnackbar.show(
                context,
                'You are on the priority waitlist! We will notify you when external promotions launch.',
              );
            },
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.notification_bing, size: 16, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Notify Me When Available',
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingChannelItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color textColor,
    required Color subtextColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262C38) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 11,
                    height: 1.25,
                    color: subtextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
