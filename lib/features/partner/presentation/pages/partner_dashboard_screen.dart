import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:iconsax/iconsax.dart';
import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/core/models/property_model.dart';
import 'package:rental/core/widgets/app_snackbar.dart';
import 'package:rental/core/widgets/bouncing_button.dart';
import 'package:rental/features/partner/data/services/partner_notification_service.dart';
import 'package:rental/features/partner/data/services/partner_service.dart';
import 'package:rental/features/partner/presentation/pages/partner_auth_screen.dart';
import 'package:rental/features/partner/presentation/pages/partner_notifications_screen.dart';
import 'package:rental/features/partner/presentation/widgets/partner_bottom_nav_bar.dart';
import 'package:rental/features/partner/presentation/pages/tabs/partner_home_tab.dart';
import 'package:rental/features/partner/presentation/pages/tabs/partner_properties_tab.dart';
import 'package:rental/features/partner/presentation/pages/tabs/partner_analytics_tab.dart';
import 'package:rental/features/partner/presentation/pages/tabs/partner_promote_tab.dart';
import 'package:rental/features/partner/presentation/pages/tabs/partner_profile_tab.dart';

class PartnerDashboardScreen extends StatefulWidget {
  final int initialTab;

  const PartnerDashboardScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<PartnerDashboardScreen> createState() => _PartnerDashboardScreenState();
}

class _PartnerDashboardScreenState extends State<PartnerDashboardScreen> {
  late int _currentTab;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _refreshData();
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await PartnerService.instance.fetchMyProperties();
      await PartnerService.instance.fetchMyRequests();
      await PartnerService.instance.fetchMyPromotions();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
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

  void _setTab(int index) {
    setState(() => _currentTab = index);
  }

  String _getAppBarTitle() {
    switch (_currentTab) {
      case 0:
        return 'Your Properties';
      case 1:
        return 'Properties';
      case 2:
        return 'Analytics';
      case 3:
        return 'Promote';
      case 4:
        return 'Profile';
      default:
        return 'Your Properties';
    }
  }

  Widget _buildTopHeader(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryYellow,
        border: const Border(
          bottom: BorderSide(color: Color(0x1F000000), width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              // Back Button
              BouncingButton(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                },
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(
                    CupertinoIcons.back,
                    size: 24,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Simple Clean Title (Premium Minimalist)
              Expanded(
                child: Text(
                  _getAppBarTitle(),
                  style: const TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Notification Icon (Styled identically to Settings Icon in user-side app)
              BouncingButton(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (_) => const PartnerNotificationsScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(
                        Iconsax.notification,
                        size: 24,
                        color: Colors.black,
                      ),
                      AnimatedBuilder(
                        animation: PartnerNotificationService.instance,
                        builder: (context, _) {
                          final unread = PartnerNotificationService.instance.unreadCount;
                          if (unread == 0) return const SizedBox.shrink();
                          return Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF3B30),
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? AppTheme.darkScaffold : const Color(0xFFF2F2F7);

    return AnimatedBuilder(
      animation: PartnerService.instance,
      builder: (context, _) {
        if (!PartnerService.instance.isLoggedIn) {
          return const PartnerAuthScreen(isEmbeddedInEntryHandler: true);
        }
        final myProperties = PartnerService.instance.myProperties;
        final myPromotions = PartnerService.instance.myPromotions;
        final activePromotionsCount = myPromotions.where((p) => p.isActive || p.isPending).length;

        return Scaffold(
          backgroundColor: scaffoldBg,
          body: Column(
            children: [
              _buildTopHeader(context, isDark),
              Expanded(
                child: RefreshIndicator(
                  color: AppTheme.primaryYellow,
                  onRefresh: _refreshData,
                  child: IndexedStack(
                    index: _currentTab,
                    children: [
                      // 0: Home Tab
                      PartnerHomeTab(
                        onNavigateTab: _setTab,
                        onRefresh: _refreshData,
                        onToggleAvailability: _onToggleAvailability,
                      ),

                      // 1: Properties & Claims Tab
                      PartnerPropertiesTab(
                        onRefresh: _refreshData,
                        onToggleAvailability: _onToggleAvailability,
                      ),

                      // 2: Analytics Tab
                      PartnerAnalyticsTab(
                        onRefresh: _refreshData,
                      ),

                      // 3: Promote Tab
                      PartnerPromoteTab(
                        onRefresh: _refreshData,
                        onNavigateTab: _setTab,
                      ),

                      // 4: Profile Tab
                      PartnerProfileTab(
                        onRefresh: _refreshData,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: PartnerBottomNavBar(
            currentIndex: _currentTab,
            onTap: _setTab,
            propertyCount: myProperties.length,
            activePromotionsCount: activePromotionsCount,
          ),
        );
      },
    );
  }
}
