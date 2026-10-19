import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/core/models/property_model.dart';
import 'package:rental/core/widgets/bouncing_button.dart';
import 'package:rental/features/partner/data/models/partner_handover_request.dart';
import 'package:rental/features/partner/data/models/partner_promotion_model.dart';
import 'package:rental/features/partner/data/services/partner_service.dart';
import 'package:rental/features/partner/presentation/widgets/partner_property_card.dart';
import 'package:rental/features/partner/presentation/widgets/partner_create_promotion_sheet.dart';
import 'package:rental/features/partner/presentation/widgets/partner_claim_property_sheet.dart';
import 'package:rental/features/property_posting/presentation/pages/posting_screen.dart';
import 'package:rental/features/property_details/presentation/pages/property_details_screen.dart';

class PartnerHomeTab extends StatelessWidget {
  final ValueChanged<int> onNavigateTab;
  final VoidCallback onRefresh;
  final ValueChanged<PropertyModel> onToggleAvailability;

  const PartnerHomeTab({
    super.key,
    required this.onNavigateTab,
    required this.onRefresh,
    required this.onToggleAvailability,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTheme.darkCard : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFEEEEEE);
    final textColor = isDark ? Colors.white : AppTheme.lightTextPrimary;
    final subtextColor = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    final partner = PartnerService.instance.currentPartner;
    final properties = PartnerService.instance.myProperties;
    final requests = PartnerService.instance.myRequests;
    final promotions = PartnerService.instance.myPromotions;

    final totalCount = properties.length;
    final availableCount = properties.where((p) => p.isAvailable).length;
    final occupiedCount = properties.where((p) => !p.isAvailable).length;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Partner Welcome & Profile Card
          _buildHeroCard(
            context,
            partner,
            totalCount,
            availableCount,
            occupiedCount,
            requests.length,
            cardColor,
            borderColor,
            textColor,
            subtextColor,
            isDark,
          ),
          const SizedBox(height: 16),

          // 2. High Impact Action Grid
          _buildQuickActionGrid(context, cardColor, borderColor, textColor, subtextColor, isDark),
          const SizedBox(height: 20),

          // 3. Analytics Spotlight Widget
          _buildAnalyticsSpotlight(
            context,
            totalCount,
            availableCount,
            properties,
            cardColor,
            borderColor,
            textColor,
            subtextColor,
            isDark,
          ),
          const SizedBox(height: 20),

          // 4. Promotions Spotlight & Active Boosts Widget
          _buildPromotionsSpotlight(
            context,
            promotions,
            cardColor,
            borderColor,
            textColor,
            subtextColor,
            isDark,
          ),
          const SizedBox(height: 20),

          // 5. Properties Snapshot Section
          _buildPropertiesSnapshot(
            context,
            properties,
            cardColor,
            borderColor,
            textColor,
            subtextColor,
            isDark,
          ),
          const SizedBox(height: 20),

          // 6. Recent Claims Snapshot
          if (requests.isNotEmpty) ...[
            _buildClaimsSnapshot(
              context,
              requests,
              cardColor,
              borderColor,
              textColor,
              subtextColor,
              isDark,
            ),
            const SizedBox(height: 24),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── 1. Hero Card ──────────────────────────────────────────────
  Widget _buildHeroCard(
    BuildContext context,
    PartnerProfile? partner,
    int totalCount,
    int availableCount,
    int occupiedCount,
    int requestsCount,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color subtextColor,
    bool isDark,
  ) {
    final name = partner?.name ?? 'Property Partner';
    final role = partner?.role ?? 'Property Owner';
    final email = partner?.email ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryYellow,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryYellow.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'P',
                    style: const TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            email.isNotEmpty ? email : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'ProximaNova',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Iconsax.verify5, size: 16, color: Color(0xFF10B981)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            role.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'ProximaNova',
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF007AFF),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Verified Landlord',
                          style: TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 11,
                            color: subtextColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: borderColor),
          const SizedBox(height: 14),

          // 4 Stat Capsules
          Row(
            children: [
              _buildStatCapsule(
                'Total',
                totalCount.toString(),
                Iconsax.buildings,
                const Color(0xFF007AFF),
                isDark,
                () => onNavigateTab(1),
              ),
              const SizedBox(width: 8),
              _buildStatCapsule(
                'Live',
                availableCount.toString(),
                Iconsax.tick_circle,
                AppTheme.swiggyGreen,
                isDark,
                () => onNavigateTab(1),
              ),
              const SizedBox(width: 8),
              _buildStatCapsule(
                'Occupied',
                occupiedCount.toString(),
                Iconsax.close_circle,
                AppTheme.swiggyRed,
                isDark,
                () => onNavigateTab(1),
              ),
              const SizedBox(width: 8),
              _buildStatCapsule(
                'Claims',
                requestsCount.toString(),
                Iconsax.clock,
                const Color(0xFFFF9500),
                isDark,
                () => onNavigateTab(1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCapsule(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'ProximaNova',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'ProximaNova',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 2. Quick Action Buttons ───────────────────────────────────
  Widget _buildQuickActionGrid(
    BuildContext context,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color subtextColor,
    bool isDark,
  ) {
    return Row(
      children: [
        // Upload Property
        Expanded(
          child: BouncingButton(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => const PostingScreen()),
              ).then((_) => onRefresh());
            },
            child: Container(
              height: 104,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryYellow,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryYellow.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(CupertinoIcons.add_circled_solid, size: 24, color: Colors.black),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Upload Property',
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Post listing',
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Claim Property
        Expanded(
          child: BouncingButton(
            onTap: () {
              HapticFeedback.mediumImpact();
              PartnerClaimPropertySheet.show(context).then((_) => onRefresh());
            },
            child: Container(
              height: 104,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: borderColor,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(CupertinoIcons.shield_fill, size: 24, color: Color(0xFF007AFF)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ask Admin',
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
                        'Claim listing',
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: subtextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Promote Button
        Expanded(
          child: BouncingButton(
            onTap: () {
              HapticFeedback.mediumImpact();
              onNavigateTab(3); // Promote tab
            },
            child: Container(
              height: 104,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5E3A),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5E3A).withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(CupertinoIcons.flame_fill, size: 24, color: Colors.white),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Promote',
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Boost reach',
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 3. Analytics Spotlight ────────────────────────────────────
  Widget _buildAnalyticsSpotlight(
    BuildContext context,
    int totalCount,
    int availableCount,
    List<PropertyModel> properties,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color subtextColor,
    bool isDark,
  ) {
    final occupancyRate = totalCount > 0
        ? (((totalCount - availableCount) / totalCount) * 100).toInt()
        : 100;
    final analytics = PartnerService.instance.analytics;
    final propViewsSum = properties.fold<int>(0, (sum, p) => sum + p.viewsCount);
    final totalViews = (analytics != null && analytics.totalViews > 0)
        ? analytics.totalViews
        : propViewsSum;
    final totalInquiries = analytics?.totalInquiries ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Iconsax.chart_2, size: 16, color: Color(0xFF007AFF)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Performance Analytics',
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onNavigateTab(2); // Go to Analytics Tab
                },
                child: Row(
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.swiggyOrange,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(CupertinoIcons.chevron_forward, size: 13, color: AppTheme.swiggyOrange),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3 Metric Pills
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F232D) : const Color(0xFFF6F8FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Iconsax.eye, size: 15, color: subtextColor),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppTheme.swiggyGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                fontFamily: 'ProximaNova',
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.swiggyGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$totalViews',
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'Total Views',
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 11,
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F232D) : const Color(0xFFF6F8FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Iconsax.call, size: 15, color: subtextColor),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'HOT',
                              style: TextStyle(
                                fontFamily: 'ProximaNova',
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF007AFF),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$totalInquiries',
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'Inquiries / Leads',
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 11,
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F232D) : const Color(0xFFF6F8FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Iconsax.percentage_circle, size: 15, color: subtextColor),
                          const Icon(Iconsax.trend_up, size: 12, color: AppTheme.swiggyGreen),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$occupancyRate%',
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'Occupancy Rate',
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 11,
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Mini 7-Day Activity Sparkline Bar
          GestureDetector(
            onTap: () => onNavigateTab(2),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1D24) : const Color(0xFFF3F5F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.activity, size: 16, color: Color(0xFF007AFF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Peak tenant searches in your area on Friday & Saturday',
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  Icon(CupertinoIcons.right_chevron, size: 12, color: subtextColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. Promotions Spotlight ───────────────────────────────────
  Widget _buildPromotionsSpotlight(
    BuildContext context,
    List<PartnerPromotionModel> promotions,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color subtextColor,
    bool isDark,
  ) {
    final pendingList = promotions.where((p) => p.isPending).toList();
    final activeList = promotions.where((p) => p.isApproved || p.isActive).toList();

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryYellow.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryYellow.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryYellow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Iconsax.flash5, size: 16, color: Colors.black),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Promotions & Growth Hub',
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              if (pendingList.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB800).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '${pendingList.length} PENDING REVIEW',
                    style: const TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFFB800),
                    ),
                  ),
                )
              else if (activeList.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: AppTheme.swiggyGreen.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${activeList.length} LIVE BOOSTED',
                    style: const TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.swiggyGreen,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            promotions.isNotEmpty
                ? (pendingList.isNotEmpty
                    ? 'You have ${pendingList.length} promotion request(s) awaiting admin approval & priority ranking.'
                    : 'You have ${activeList.length} live promotion campaign(s) running right now!')
                : 'Accelerate tenant inquiries by up to 10x using In-App Featured Spotlight or External Meta & Google Ads campaigns.',
            style: TextStyle(
              fontFamily: 'ProximaNova',
              fontSize: 12.5,
              color: isDark ? Colors.white70 : const Color(0xFF4B5563),
              height: 1.35,
            ),
          ),
          if (promotions.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...promotions.take(2).map((promo) {
              final isPend = promo.isPending;
              final isLive = promo.isApproved || promo.isActive;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF15181E) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPend
                        ? const Color(0xFFFFB800).withValues(alpha: 0.4)
                        : (isLive
                            ? AppTheme.swiggyGreen.withValues(alpha: 0.4)
                            : borderColor),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            promo.propertyTitle,
                            style: TextStyle(
                              fontFamily: 'ProximaNova',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPend
                                ? const Color(0xFFFFB800).withValues(alpha: 0.15)
                                : (isLive
                                    ? AppTheme.swiggyGreen.withValues(alpha: 0.15)
                                    : const Color(0xFFEF4444).withValues(alpha: 0.15)),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            isPend
                                ? 'PENDING APPROVAL'
                                : (isLive
                                    ? 'BOOST RANK #${promo.priorityPosition}'
                                    : 'DECLINED'),
                            style: TextStyle(
                              fontFamily: 'ProximaNova',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: isPend
                                  ? const Color(0xFFFFB800)
                                  : (isLive ? AppTheme.swiggyGreen : const Color(0xFFEF4444)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isPend
                          ? '${promo.packageName} • ${promo.price} • Admin is reviewing ranking (1, 2, 3...)'
                          : '${promo.packageName} • Pinned top in 5.0 km search feed',
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 11,
                        color: subtextColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: BouncingButton(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    PartnerCreatePromotionSheet.show(
                      context,
                      initialType: 'in_app',
                    ).then((_) => onRefresh());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryYellow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Iconsax.mobile, size: 14, color: Colors.black),
                          SizedBox(width: 5),
                          Text(
                            'In-App Spotlight',
                            style: TextStyle(
                              fontFamily: 'ProximaNova',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: BouncingButton(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    PartnerCreatePromotionSheet.show(
                      context,
                      initialType: 'external',
                    ).then((_) => onRefresh());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2E2614) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.primaryYellow.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Iconsax.global, size: 14, color: Color(0xFF007AFF)),
                          const SizedBox(width: 5),
                          Text(
                            'Social & Google Ads',
                            style: TextStyle(
                              fontFamily: 'ProximaNova',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: textColor,
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
        ],
      ),
    );
  }

  // ── 5. Properties Snapshot ────────────────────────────────────
  Widget _buildPropertiesSnapshot(
    BuildContext context,
    List<PropertyModel> properties,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color subtextColor,
    bool isDark,
  ) {
    final previewList = properties.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Your Properties',
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryYellow.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${properties.length}',
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppTheme.primaryYellow : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onNavigateTab(1); // Go to Properties tab
              },
              child: Row(
                children: [
                  Text(
                    'See All',
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.swiggyOrange,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(CupertinoIcons.chevron_forward, size: 13, color: AppTheme.swiggyOrange),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (properties.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Iconsax.building_4, size: 36, color: subtextColor),
                  const SizedBox(height: 10),
                  Text(
                    'No Properties Linked Yet',
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Upload your property or claim an existing platform listing.',
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 12,
                      color: subtextColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: previewList.length,
            separatorBuilder: (context, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final p = previewList[index];
              return PartnerPropertyCard(
                property: p,
                onToggleAvailability: onToggleAvailability,
                onEdit: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (_) => PostingScreen(propertyToEdit: p)),
                  ).then((_) => onRefresh());
                },
                onView: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (_) => PropertyDetailsScreen(property: p)),
                  );
                },
                onPromote: () {
                  PartnerCreatePromotionSheet.show(
                    context,
                    initialProperty: p,
                  ).then((_) => onRefresh());
                },
              );
            },
          ),
      ],
    );
  }

  // ── 6. Claims Snapshot ────────────────────────────────────────
  Widget _buildClaimsSnapshot(
    BuildContext context,
    List<PartnerHandoverRequest> requests,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color subtextColor,
    bool isDark,
  ) {
    final pendingCount = requests.where((r) => r.status.toLowerCase() == 'pending').length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Iconsax.shield_tick5, size: 22, color: Color(0xFF007AFF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Handover Claims ($pendingCount Pending)',
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Track admin verification status of claimed properties.',
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 12,
                    color: subtextColor,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => onNavigateTab(1), // Go to Properties tab -> Claims
            icon: Icon(CupertinoIcons.chevron_forward, size: 16, color: subtextColor),
          ),
        ],
      ),
    );
  }
}
