import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax/iconsax.dart';

import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/core/models/property_model.dart';
import 'package:rental/core/widgets/app_snackbar.dart';
import 'package:rental/core/widgets/bouncing_button.dart';
import 'package:rental/core/widgets/property_status_stamp.dart';
import 'package:rental/features/partner/data/models/partner_handover_request.dart';
import 'package:rental/features/partner/data/services/partner_service.dart';
import 'package:rental/features/partner/presentation/widgets/partner_claim_property_sheet.dart';
import 'package:rental/features/property_posting/presentation/pages/posting_screen.dart';
import 'package:rental/features/property_details/presentation/pages/property_details_screen.dart';

class PartnerDashboardScreen extends StatefulWidget {
  const PartnerDashboardScreen({super.key});

  @override
  State<PartnerDashboardScreen> createState() => _PartnerDashboardScreenState();
}

class _PartnerDashboardScreenState extends State<PartnerDashboardScreen> {
  int _selectedTab = 0; // 0: Your Properties, 1: Handover Requests
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await PartnerService.instance.fetchMyProperties();
      await PartnerService.instance.fetchMyRequests();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _openUploadProperty() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => const PostingScreen()),
    ).then((_) => _refreshData());
  }

  void _openClaimSheet() {
    HapticFeedback.mediumImpact();
    PartnerClaimPropertySheet.show(context).then((_) => _refreshData());
  }

  void _onToggleAvailability(PropertyModel property) async {
    HapticFeedback.lightImpact();
    final ok = await PartnerService.instance.toggleAvailability(property);
    if (!mounted) return;
    if (ok) {
      AppSnackbar.show(
        context,
        property.isAvailable
            ? 'Property marked as AVAILABLE'
            : 'Property marked as OCCUPIED / SOLD',
      );
    } else {
      AppSnackbar.show(context, 'Failed to update availability. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF7F7F9);
    final cardColor = isDark ? const Color(0xFF16181D) : Colors.white;
    final borderColor = isDark ? const Color(0xFF262A34) : const Color(0xFFECEEF2);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return AnimatedBuilder(
      animation: PartnerService.instance,
      builder: (context, _) {
        final partner = PartnerService.instance.currentPartner;
        final myProperties = PartnerService.instance.myProperties;
        final myRequests = PartnerService.instance.myRequests;

        final availableCount = myProperties.where((p) => p.isAvailable).length;
        final occupiedCount = myProperties.where((p) => !p.isAvailable).length;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: cardColor,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              splashRadius: 22,
              icon: Icon(CupertinoIcons.back, size: 24, color: textColor),
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context);
              },
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryYellow.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Iconsax.crown5,
                    size: 16,
                    color: isDark ? AppTheme.primaryYellow : const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Your Property',
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ],
            ),
            centerTitle: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: borderColor, height: 1),
            ),
            actions: [
              IconButton(
                splashRadius: 22,
                icon: _isRefreshing
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CupertinoActivityIndicator(
                          radius: 8,
                          color: textColor,
                        ),
                      )
                    : Icon(CupertinoIcons.arrow_clockwise, size: 20, color: textColor),
                tooltip: 'Refresh',
                onPressed: _isRefreshing
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        _refreshData();
                      },
              ),
              PopupMenuButton<String>(
                icon: Icon(Iconsax.more, size: 20, color: textColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                color: cardColor,
                onSelected: (val) {
                  if (val == 'logout') {
                    PartnerService.instance.logout();
                    Navigator.pop(context);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Iconsax.logout, size: 18, color: AppTheme.swiggyRed),
                        const SizedBox(width: 10),
                        Text(
                          'Switch Account / Logout',
                          style: TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.swiggyRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: RefreshIndicator(
            color: AppTheme.primaryYellow,
            onRefresh: _refreshData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Partner Profile Card with Real KPI Capsules
                  _buildProfileCard(
                    partner,
                    myProperties.length,
                    availableCount,
                    occupiedCount,
                    myRequests.length,
                    cardColor,
                    borderColor,
                    textColor,
                    subtextColor,
                    isDark,
                  ),
                  const SizedBox(height: 16),

                  // 2. High-Impact Action Buttons (Upload New & Ask Admin)
                  Row(
                    children: [
                      // Upload Property Card
                      Expanded(
                        child: BouncingButton(
                          onTap: _openUploadProperty,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryYellow,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryYellow.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Iconsax.add_circle5, size: 26, color: Colors.black),
                                SizedBox(height: 10),
                                Text(
                                  'Upload Property',
                                  style: TextStyle(
                                    fontFamily: 'DMSans',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Post for admin review',
                                  style: TextStyle(
                                    fontFamily: 'ProximaNova',
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Ask Admin / Claim Property Card
                      Expanded(
                        child: BouncingButton(
                          onTap: _openClaimSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? const Color(0xFF323846) : const Color(0xFFE2E5EB),
                                width: 1.2,
                              ),
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
                                const Icon(Iconsax.shield_tick5, size: 26, color: Color(0xFF007AFF)),
                                const SizedBox(height: 10),
                                Text(
                                  'Ask Admin',
                                  style: TextStyle(
                                    fontFamily: 'DMSans',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Claim existing listing',
                                  style: TextStyle(
                                    fontFamily: 'ProximaNova',
                                    fontSize: 11.5,
                                    color: subtextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 3. Segmented Pill Tab Selector
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF12141A) : const Color(0xFFEDEFF3),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedTab = 0);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedTab == 0 ? cardColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _selectedTab == 0
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Iconsax.building_3,
                                      size: 15,
                                      color: _selectedTab == 0 ? AppTheme.swiggyOrange : subtextColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Your Properties',
                                      style: TextStyle(
                                        fontFamily: 'DMSans',
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: _selectedTab == 0 ? textColor : subtextColor,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: _selectedTab == 0
                                            ? AppTheme.primaryYellow.withValues(alpha: 0.25)
                                            : (isDark ? Colors.white10 : Colors.black12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${myProperties.length}',
                                        style: TextStyle(
                                          fontFamily: 'ProximaNova',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: _selectedTab == 0
                                              ? (isDark ? AppTheme.primaryYellow : Colors.black87)
                                              : subtextColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedTab = 1);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedTab == 1 ? cardColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _selectedTab == 1
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Iconsax.direct_send,
                                      size: 15,
                                      color: _selectedTab == 1 ? const Color(0xFF007AFF) : subtextColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Claims',
                                      style: TextStyle(
                                        fontFamily: 'DMSans',
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: _selectedTab == 1 ? textColor : subtextColor,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: _selectedTab == 1
                                            ? const Color(0xFF007AFF).withValues(alpha: 0.18)
                                            : (isDark ? Colors.white10 : Colors.black12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${myRequests.length}',
                                        style: TextStyle(
                                          fontFamily: 'ProximaNova',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: _selectedTab == 1 ? const Color(0xFF007AFF) : subtextColor,
                                        ),
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
                  const SizedBox(height: 16),

                  // 4. Tab Content
                  if (_selectedTab == 0)
                    _buildPropertiesTab(myProperties, cardColor, borderColor, textColor, subtextColor, isDark)
                  else
                    _buildRequestsTab(myRequests, cardColor, borderColor, textColor, subtextColor, isDark),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Profile Banner Card with KPI Capsules ──────────────────────
  Widget _buildProfileCard(
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
          // Header info
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryYellow,
                      const Color(0xFFFFB300),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
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
                      fontFamily: 'DMSans',
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
                              fontFamily: 'DMSans',
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
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
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: borderColor),
          const SizedBox(height: 14),

          // 4 KPI Stat Capsules
          Row(
            children: [
              _buildStatCapsule('Total', totalCount.toString(), Iconsax.buildings, const Color(0xFF007AFF), isDark),
              const SizedBox(width: 8),
              _buildStatCapsule('Live', availableCount.toString(), Iconsax.tick_circle, AppTheme.swiggyGreen, isDark),
              const SizedBox(width: 8),
              _buildStatCapsule('Occupied', occupiedCount.toString(), Iconsax.close_circle, AppTheme.swiggyRed, isDark),
              const SizedBox(width: 8),
              _buildStatCapsule('Claims', requestsCount.toString(), Iconsax.clock, const Color(0xFFFF9500), isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCapsule(String label, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
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
                fontFamily: 'DMSans',
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
    );
  }

  // ── Tab 0: Properties List Styled like True App Property Cards ──
  Widget _buildPropertiesTab(
    List<PropertyModel> properties,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color subtextColor,
    bool isDark,
  ) {
    if (properties.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.primaryYellow.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Iconsax.building_4, size: 40, color: AppTheme.primaryYellow),
            ),
            const SizedBox(height: 16),
            Text(
              'No Properties Linked Yet',
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Upload your property for instant admin review, or Ask Admin to claim any existing listing already on the app!',
              style: TextStyle(fontFamily: 'ProximaNova', fontSize: 13, color: subtextColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BouncingButton(
                  onTap: _openUploadProperty,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryYellow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Iconsax.add, size: 16, color: Colors.black),
                        SizedBox(width: 6),
                        Text(
                          'Upload New',
                          style: TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                BouncingButton(
                  onTap: _openClaimSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF222631) : const Color(0xFFF2F4F7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Iconsax.shield_tick, size: 16, color: textColor),
                        const SizedBox(width: 6),
                        Text(
                          'Ask Admin',
                          style: TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: properties.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final p = properties[index];
        final thumb = p.imageUrls.isNotEmpty ? p.imageUrls.first : '';
        final isApproved = p.status == 'approved';

        return BouncingButton(
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(builder: (_) => PropertyDetailsScreen(property: p)),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Banner Image with overlays matching PropertyCard
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                      child: p.isAvailable
                          ? CachedNetworkImage(
                              imageUrl: thumb,
                              height: 175,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                height: 175,
                                color: isDark ? const Color(0xFF222631) : const Color(0xFFF2F4F7),
                                child: const Center(child: Icon(Iconsax.gallery, size: 32, color: Colors.grey)),
                              ),
                            )
                          : ColorFiltered(
                              colorFilter: const ColorFilter.matrix([
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0,      0,      0,      1, 0,
                              ]),
                              child: CachedNetworkImage(
                                imageUrl: thumb,
                                height: 175,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  height: 175,
                                  color: isDark ? const Color(0xFF222631) : const Color(0xFFF2F4F7),
                                  child: const Center(child: Icon(Iconsax.gallery, size: 32, color: Colors.grey)),
                                ),
                              ),
                            ),
                    ),

                    // Stamp overlay if occupied
                    if (!p.isAvailable)
                      Positioned.fill(
                        child: Center(
                          child: PropertyStatusStamp.fromPropertyType(
                            propertyType: p.type,
                            isCompact: false,
                          ),
                        ),
                      ),

                    // Top Left: Property Type Badge
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          p.type.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),

                    // Top Right: Approval Status Badge
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isApproved ? AppTheme.swiggyGreen : const Color(0xFFFF9500)).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isApproved ? Iconsax.verify5 : Iconsax.clock,
                              size: 11,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isApproved ? 'LIVE' : 'PENDING REVIEW',
                              style: const TextStyle(
                                fontFamily: 'ProximaNova',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Right: Price pill in signature Swiggy Yellow
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryYellow,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          p.price,
                          style: const TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Content Details
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Location Row
                      Row(
                        children: [
                          Icon(Iconsax.location5, color: AppTheme.swiggyOrange, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              p.locationStr,
                              style: TextStyle(
                                fontFamily: 'ProximaNova',
                                color: subtextColor,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Title
                      Text(
                        p.title,
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                Divider(height: 1, color: borderColor),

                // Owner Control Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Live Availability Toggle
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: p.isAvailable ? AppTheme.swiggyGreen : AppTheme.swiggyRed,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            p.isAvailable ? 'Available' : 'Occupied',
                            style: TextStyle(
                              fontFamily: 'ProximaNova',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: p.isAvailable ? AppTheme.swiggyGreen : AppTheme.swiggyRed,
                            ),
                          ),
                          const SizedBox(width: 8),
                          CupertinoSwitch(
                            value: p.isAvailable,
                            activeTrackColor: AppTheme.swiggyGreen,
                            onChanged: (_) => _onToggleAvailability(p),
                          ),
                        ],
                      ),

                      // Action Buttons: Edit & View
                      Row(
                        children: [
                          BouncingButton(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (_) => PostingScreen(propertyToEdit: p),
                                ),
                              ).then((_) => _refreshData());
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF222631) : const Color(0xFFF2F4F7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Iconsax.edit_2, size: 14, color: textColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Edit',
                                    style: TextStyle(
                                      fontFamily: 'ProximaNova',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          BouncingButton(
                            onTap: () {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(builder: (_) => PropertyDetailsScreen(property: p)),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF222631) : const Color(0xFFF2F4F7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Iconsax.eye, size: 14, color: textColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    'View',
                                    style: TextStyle(
                                      fontFamily: 'ProximaNova',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
                                    ),
                                  ),
                                ],
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
      },
    );
  }

  // ── Tab 1: Handover Claims List ────────────────────────────────
  Widget _buildRequestsTab(
    List<PartnerHandoverRequest> requests,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color subtextColor,
    bool isDark,
  ) {
    if (requests.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.direct_send, size: 40, color: Color(0xFF007AFF)),
            ),
            const SizedBox(height: 16),
            Text(
              'No Handover Claims',
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Use the "Ask Admin" button to claim existing platform properties listed by our team!',
              style: TextStyle(fontFamily: 'ProximaNova', fontSize: 13, color: subtextColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            BouncingButton(
              onTap: _openClaimSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryYellow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Iconsax.shield_tick, size: 16, color: Colors.black),
                    SizedBox(width: 6),
                    Text(
                      'Ask Admin to Handover',
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
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

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final r = requests[index];
        final isApproved = r.status == 'approved';
        final isPending = r.status == 'pending';

        final Color statusColor = isApproved
            ? AppTheme.swiggyGreen
            : (isPending ? const Color(0xFFFF9500) : AppTheme.swiggyRed);
        final IconData statusIcon = isApproved
            ? Iconsax.verify5
            : (isPending ? Iconsax.clock : Iconsax.close_circle);
        final String statusLabel = isApproved
            ? 'APPROVED & LINKED'
            : (isPending ? 'PENDING ADMIN REVIEW' : 'DECLINED');

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isPending ? const Color(0xFFFF9500).withValues(alpha: 0.35) : borderColor,
              width: isPending ? 1.4 : 1,
            ),
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
              // Status Pill Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${r.createdAt.day}/${r.createdAt.month}/${r.createdAt.year}',
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 11.5,
                      color: subtextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Property Title & Role
              Text(
                r.propertyTitle,
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Iconsax.user, size: 13, color: Color(0xFF007AFF)),
                  const SizedBox(width: 4),
                  Text(
                    'Claimed Role: ${r.role}',
                    style: const TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                ],
              ),

              if (r.note.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Iconsax.document_text, size: 14, color: subtextColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          r.note,
                          style: TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 12.5,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (isApproved) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.swiggyGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.swiggyGreen.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Iconsax.verify5, size: 16, color: AppTheme.swiggyGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ownership verified & granted! Manage availability directly in Your Properties tab.',
                          style: TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF065F46),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
