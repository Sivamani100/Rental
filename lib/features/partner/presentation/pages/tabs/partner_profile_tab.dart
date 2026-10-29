import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/core/widgets/app_snackbar.dart';
import 'package:rental/core/widgets/bouncing_button.dart';
import 'package:rental/features/partner/data/services/partner_service.dart';

class PartnerProfileTab extends StatefulWidget {
  final VoidCallback onRefresh;

  const PartnerProfileTab({
    super.key,
    required this.onRefresh,
  });

  @override
  State<PartnerProfileTab> createState() => _PartnerProfileTabState();
}

class _PartnerProfileTabState extends State<PartnerProfileTab> {
  bool _instantLeadAlerts = true;
  bool _whatsAppInquiries = true;
  bool _autoAvailabilitySync = false;
  bool _weeklyPerformanceDigest = true;

  void _onLogout(BuildContext context) {
    HapticFeedback.mediumImpact();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out from your property partner account?',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Sign Out'),
            onPressed: () {
              Navigator.pop(ctx);
              PartnerService.instance.logout();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _contactConcierge() async {
    HapticFeedback.selectionClick();
    final uri = Uri.parse('https://wa.me/919999999999?text=Hello%20Rental%20Support,%20I%20am%20a%20property%20partner');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        AppSnackbar.show(context, 'Landlord Concierge: partner-support@rental.com');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E222B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2C3240) : Colors.grey.shade200;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? const Color(0xFF9E9E9E) : const Color(0xFF8E8E93);

    final partner = PartnerService.instance.currentPartner;
    final name = partner?.name ?? 'Property Partner';
    final email = partner?.email ?? 'partner@rental.com';
    final partnerId = partner != null && partner.id.isNotEmpty
        ? partner.id.substring(0, (partner.id.length > 8 ? 8 : partner.id.length)).toUpperCase()
        : 'PTR-8821';
    final propertiesCount = PartnerService.instance.myProperties.length;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Profile Header Card (Matching Settings Screen Style) ──
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar with Single Solid Yellow
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryYellow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'P',
                      style: const TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Partner Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontFamily: 'ProximaNova',
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            CupertinoIcons.checkmark_seal_fill,
                            color: AppTheme.swiggyGreen,
                            size: 16,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        email,
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: subtextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF262C38) : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              'ID: $partnerId',
                              style: TextStyle(
                                fontFamily: 'ProximaNova',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: subtextColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.swiggyGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '$propertiesCount Listings',
                              style: const TextStyle(
                                fontFamily: 'ProximaNova',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.swiggyGreen,
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

          // ── 2. Account & Landlord Verification ─────────────────
          _buildSectionHeader('ACCOUNT & VERIFICATION'),
          _buildTileGroup(
            cardBg,
            borderColor,
            [
              _buildNavTile(
                icon: _iconBox(const Color(0xFF007AFF), CupertinoIcons.shield_fill),
                label: 'Partner Verification',
                subtitle: 'Ownership documents & KYC approved',
                trailingBadge: 'VERIFIED',
                trailingBadgeColor: AppTheme.swiggyGreen,
                textColor: textColor,
                subtextColor: subtextColor,
                onTap: () {
                  HapticFeedback.selectionClick();
                  AppSnackbar.show(context, 'Your Partner account is fully verified.');
                },
              ),
              _buildNavTile(
                icon: _iconBox(const Color(0xFF5856D6), Iconsax.card_pos),
                label: 'Payout Bank Details',
                subtitle: 'Direct tenant rent & deposit payouts',
                trailingBadge: 'LINKED',
                trailingBadgeColor: const Color(0xFF007AFF),
                textColor: textColor,
                subtextColor: subtextColor,
                onTap: () {
                  HapticFeedback.selectionClick();
                  AppSnackbar.show(context, 'Bank account linked for direct payouts.');
                },
              ),
              _buildNavTile(
                icon: _iconBox(const Color(0xFFFF9500), Iconsax.document_text_1),
                label: 'Rental Agreements & Invoices',
                subtitle: 'Standard lease templates and tax receipts',
                textColor: textColor,
                subtextColor: subtextColor,
                onTap: () {
                  HapticFeedback.selectionClick();
                  AppSnackbar.show(context, 'Rental agreement generator opened.');
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── 3. Lead & Notification Preferences ─────────────────
          _buildSectionHeader('LEAD & NOTIFICATION PREFERENCES'),
          _buildTileGroup(
            cardBg,
            borderColor,
            [
              _buildSwitchTile(
                icon: _iconBox(const Color(0xFF007AFF), CupertinoIcons.bell_fill),
                label: 'Instant Lead Push Alerts',
                subtitle: 'Receive notification when tenant visits or calls',
                value: _instantLeadAlerts,
                textColor: textColor,
                subtextColor: subtextColor,
                onChanged: (val) {
                  setState(() => _instantLeadAlerts = val);
                  HapticFeedback.selectionClick();
                },
              ),
              _buildSwitchTile(
                icon: _iconBox(AppTheme.swiggyGreen, CupertinoIcons.chat_bubble_2_fill),
                label: 'WhatsApp Tenant Inquiries',
                subtitle: 'Allow verified tenants to chat directly on WhatsApp',
                value: _whatsAppInquiries,
                textColor: textColor,
                subtextColor: subtextColor,
                onChanged: (val) {
                  setState(() => _whatsAppInquiries = val);
                  HapticFeedback.selectionClick();
                },
              ),
              _buildSwitchTile(
                icon: _iconBox(const Color(0xFFFF5E3A), Iconsax.status_up),
                label: 'Auto Availability Sync',
                subtitle: 'Mark occupied automatically upon lease confirmation',
                value: _autoAvailabilitySync,
                textColor: textColor,
                subtextColor: subtextColor,
                onChanged: (val) {
                  setState(() => _autoAvailabilitySync = val);
                  HapticFeedback.selectionClick();
                },
              ),
              _buildSwitchTile(
                icon: _iconBox(const Color(0xFF34C759), Iconsax.chart_21),
                label: 'Weekly Performance Digest',
                subtitle: 'Weekly summary of property views and leads',
                value: _weeklyPerformanceDigest,
                textColor: textColor,
                subtextColor: subtextColor,
                onChanged: (val) {
                  setState(() => _weeklyPerformanceDigest = val);
                  HapticFeedback.selectionClick();
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── 4. Concierge & Support ─────────────────────────────
          _buildSectionHeader('SUPPORT & LEGAL'),
          _buildTileGroup(
            cardBg,
            borderColor,
            [
              _buildNavTile(
                icon: _iconBox(AppTheme.swiggyGreen, Iconsax.headphone),
                label: '24/7 Landlord Concierge',
                subtitle: 'Dedicated WhatsApp partner assistance',
                textColor: textColor,
                subtextColor: subtextColor,
                onTap: _contactConcierge,
              ),
              _buildNavTile(
                icon: _iconBox(const Color(0xFF007AFF), CupertinoIcons.question_circle_fill),
                label: 'Partner FAQs & Help Guide',
                subtitle: 'Tips on maximizing rental returns',
                textColor: textColor,
                subtextColor: subtextColor,
                onTap: () {
                  HapticFeedback.selectionClick();
                  AppSnackbar.show(context, 'Partner Help Center opened.');
                },
              ),
              _buildNavTile(
                icon: _iconBox(Colors.grey, CupertinoIcons.doc_plaintext),
                label: 'Terms & Ecosystem Guidelines',
                subtitle: 'Partner rules & tenant safety code',
                textColor: textColor,
                subtextColor: subtextColor,
                onTap: () {
                  HapticFeedback.selectionClick();
                  AppSnackbar.show(context, 'Ecosystem guidelines opened.');
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── 5. Session & Actions ───────────────────────────────
          _buildSectionHeader('SESSION'),
          _buildTileGroup(
            cardBg,
            borderColor,
            [
              _buildActionTile(
                icon: _iconBox(AppTheme.swiggyRed, CupertinoIcons.square_arrow_right),
                label: 'Sign Out from Partner Account',
                isDestructive: true,
                onTap: () => _onLogout(context),
              ),
            ],
          ),

          // ── Footer: Version Info (Matching Settings Screen) ────
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 24),
              child: Text(
                'Rental Partner Ecosystem v1.1.18  •  Made with ♥ in India',
                style: TextStyle(
                  fontFamily: 'ProximaNova',
                  fontSize: 12,
                  color: subtextColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers (Exact Style from Settings Screen) ─────────────────
  Widget _iconBox(Color bg, IconData icon) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Center(
        child: Icon(icon, color: Colors.white, size: 15),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'ProximaNova',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF8E8E93),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTileGroup(Color cardBg, Color borderColor, List<Widget> tiles) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: tiles.asMap().entries.map((entry) {
          final i = entry.key;
          final tile = entry.value;
          final isLast = i == tiles.length - 1;
          return Column(
            children: [
              tile,
              if (!isLast)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 52,
                  color: borderColor.withValues(alpha: 0.5),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSwitchTile({
    required Widget icon,
    required String label,
    String? subtitle,
    required bool value,
    required Color textColor,
    required Color subtextColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 11.5,
                      color: subtextColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: CupertinoSwitch(
              value: value,
              activeTrackColor: AppTheme.primaryYellow,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile({
    required Widget icon,
    required String label,
    String? subtitle,
    String? trailingBadge,
    Color? trailingBadgeColor,
    required Color textColor,
    required Color subtextColor,
    required VoidCallback onTap,
  }) {
    return BouncingButton(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 11.5,
                        color: subtextColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingBadge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: (trailingBadgeColor ?? AppTheme.primaryYellow).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  trailingBadge,
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: trailingBadgeColor ?? AppTheme.primaryYellow,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(
              CupertinoIcons.chevron_forward,
              size: 15,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required Widget icon,
    required String label,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    return BouncingButton(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'ProximaNova',
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: isDestructive ? AppTheme.swiggyRed : Colors.black87,
                ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_forward,
              size: 15,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
