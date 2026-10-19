import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/core/widgets/app_snackbar.dart';
import 'package:rental/core/widgets/bouncing_button.dart';
import 'package:rental/features/partner/data/models/partner_notification_model.dart';
import 'package:rental/features/partner/data/services/partner_notification_service.dart';

class PartnerNotificationsScreen extends StatefulWidget {
  const PartnerNotificationsScreen({super.key});

  @override
  State<PartnerNotificationsScreen> createState() => _PartnerNotificationsScreenState();
}

class _PartnerNotificationsScreenState extends State<PartnerNotificationsScreen> {
  int _selectedFilterIndex = 0;

  final List<String> _filters = [
    'All',
    'Inquiries',
    'Claims & Admin',
    'Promotions',
    'Payouts',
    'System',
  ];

  List<PartnerNotificationModel> _filterNotifications(List<PartnerNotificationModel> list) {
    if (_selectedFilterIndex == 0) return list;
    final filterName = _filters[_selectedFilterIndex];
    return list.where((n) {
      switch (filterName) {
        case 'Inquiries':
          return n.type == PartnerNotificationType.inquiry;
        case 'Claims & Admin':
          return n.type == PartnerNotificationType.claimAdmin;
        case 'Promotions':
          return n.type == PartnerNotificationType.promotion;
        case 'Payouts':
          return n.type == PartnerNotificationType.payment;
        case 'System':
          return n.type == PartnerNotificationType.system;
        default:
          return true;
      }
    }).toList();
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  IconData _getTypeIcon(PartnerNotificationType type) {
    switch (type) {
      case PartnerNotificationType.inquiry:
        return Iconsax.message_text_1;
      case PartnerNotificationType.claimAdmin:
        return CupertinoIcons.shield_fill;
      case PartnerNotificationType.promotion:
        return CupertinoIcons.flame_fill;
      case PartnerNotificationType.payment:
        return Iconsax.card_pos;
      case PartnerNotificationType.system:
        return Iconsax.notification_bing;
    }
  }

  Color _getTypeColor(PartnerNotificationType type) {
    switch (type) {
      case PartnerNotificationType.inquiry:
        return AppTheme.swiggyGreen;
      case PartnerNotificationType.claimAdmin:
        return const Color(0xFF007AFF);
      case PartnerNotificationType.promotion:
        return const Color(0xFFFF5E3A);
      case PartnerNotificationType.payment:
        return const Color(0xFF5856D6);
      case PartnerNotificationType.system:
        return const Color(0xFFFF9500);
    }
  }

  String _getTypeLabel(PartnerNotificationType type) {
    switch (type) {
      case PartnerNotificationType.inquiry:
        return 'INQUIRY';
      case PartnerNotificationType.claimAdmin:
        return 'ADMIN & CLAIM';
      case PartnerNotificationType.promotion:
        return 'PROMOTION';
      case PartnerNotificationType.payment:
        return 'PAYOUT';
      case PartnerNotificationType.system:
        return 'SYSTEM ALERT';
    }
  }

  void _showNotificationDetailSheet(BuildContext context, PartnerNotificationModel notif, bool isDark) {
    PartnerNotificationService.instance.markAsRead(notif.id);
    final cardBg = isDark ? const Color(0xFF1E222B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtextColor = isDark ? const Color(0xFF9E9E9E) : const Color(0xFF6B7280);
    final color = _getTypeColor(notif.type);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_getTypeIcon(notif.type), color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _getTypeLabel(notif.type),
                          style: TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: color,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimeAgo(notif.createdAt),
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 12,
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              notif.title,
              style: TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              notif.message,
              style: TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 14,
                height: 1.45,
                color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
              ),
            ),
            if (notif.propertyName != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF262C38) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Iconsax.buildings, size: 16, color: subtextColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notif.propertyName!,
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
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: BouncingButton(
                    onTap: () {
                      Navigator.pop(ctx);
                      PartnerNotificationService.instance.deleteNotification(notif.id);
                      AppSnackbar.show(context, 'Notification removed');
                    },
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C3240) : const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Dismiss',
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                ),
                if (notif.actionLabel != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: BouncingButton(
                      onTap: () {
                        Navigator.pop(ctx);
                        HapticFeedback.mediumImpact();
                        AppSnackbar.show(context, '${notif.actionLabel} triggered');
                      },
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryYellow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          notif.actionLabel!,
                          style: const TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? AppTheme.darkScaffold : const Color(0xFFF4F5F8);
    final cardColor = isDark ? const Color(0xFF1E222B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtextColor = isDark ? const Color(0xFF9E9E9E) : const Color(0xFF6B7280);
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Column(
        children: [
          // ── 1. Top App Bar (Solid Yellow, Flat, Black Elements) ──
          Container(
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

                    // Title with Badges
                    Expanded(
                      child: Row(
                        children: [
                          const Text(
                            'Notifications',
                            style: TextStyle(
                              fontFamily: 'ProximaNova',
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 8),
                          AnimatedBuilder(
                            animation: PartnerNotificationService.instance,
                            builder: (context, _) {
                              final unread = PartnerNotificationService.instance.unreadCount;
                              if (unread == 0) return const SizedBox.shrink();
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$unread new',
                                  style: TextStyle(
                                    fontFamily: 'ProximaNova',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryYellow,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Mark all read button
                    BouncingButton(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        PartnerNotificationService.instance.markAllAsRead();
                        AppSnackbar.show(context, 'All notifications marked as read');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Iconsax.tick_circle, size: 14, color: Colors.black),
                            SizedBox(width: 4),
                            Text(
                              'Mark Read',
                              style: TextStyle(
                                fontFamily: 'ProximaNova',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
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
          ),

          // ── 2. Push Notification Status & Simulator Bar ──────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E222B) : const Color(0xFFFFFFFF),
              border: Border(bottom: BorderSide(color: borderColor, width: 0.8)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.swiggyGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Push Notifications: Active (Instant Alert)',
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: subtextColor,
                    ),
                  ),
                ),
                BouncingButton(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    PartnerNotificationService.instance.simulateNewPushNotification();
                    AppSnackbar.show(context, 'Simulated incoming push notification received!');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF262C38) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Iconsax.add_circle, size: 12, color: textColor),
                        const SizedBox(width: 4),
                        Text(
                          'Test Push',
                          style: TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 3. Category Filter Chips ─────────────────────────────
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isSelected = _selectedFilterIndex == index;
                final label = _filters[index];

                return BouncingButton(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedFilterIndex = index);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryYellow
                          : (isDark ? const Color(0xFF1E222B) : Colors.white),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryYellow : borderColor,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.black : subtextColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── 4. Notifications List ────────────────────────────────
          Expanded(
            child: AnimatedBuilder(
              animation: PartnerNotificationService.instance,
              builder: (context, _) {
                final all = PartnerNotificationService.instance.notifications;
                final filtered = _filterNotifications(all);

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E222B) : const Color(0xFFE5E7EB),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Iconsax.notification_status,
                              size: 28,
                              color: subtextColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No notifications found',
                            style: TextStyle(
                              fontFamily: 'ProximaNova',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _selectedFilterIndex == 0
                                ? 'You have no alerts at the moment. Live tenant inquiries and admin updates will appear here.'
                                : 'No notifications in the "${_filters[_selectedFilterIndex]}" category.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'ProximaNova',
                              fontSize: 12.5,
                              color: subtextColor,
                              height: 1.4,
                            ),
                          ),
                          if (_selectedFilterIndex != 0) ...[
                            const SizedBox(height: 14),
                            BouncingButton(
                              onTap: () => setState(() => _selectedFilterIndex = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryYellow,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Show All Notifications',
                                  style: TextStyle(
                                    fontFamily: 'ProximaNova',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final notif = filtered[index];
                    final color = _getTypeColor(notif.type);

                    return Dismissible(
                      key: Key(notif.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: AppTheme.swiggyRed,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(CupertinoIcons.delete_solid, color: Colors.white, size: 20),
                      ),
                      onDismissed: (_) {
                        PartnerNotificationService.instance.deleteNotification(notif.id);
                        AppSnackbar.show(context, 'Notification removed');
                      },
                      child: BouncingButton(
                        onTap: () => _showNotificationDetailSheet(context, notif, isDark),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: notif.isRead
                                ? cardColor
                                : (isDark ? const Color(0xFF222834) : const Color(0xFFFFFDF5)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: notif.isRead
                                  ? borderColor
                                  : AppTheme.primaryYellow.withValues(alpha: 0.5),
                              width: notif.isRead ? 1 : 1.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Type Icon
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(_getTypeIcon(notif.type), color: color, size: 20),
                              ),
                              const SizedBox(width: 12),

                              // Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row with Tag & Timestamp
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            _getTypeLabel(notif.type),
                                            style: TextStyle(
                                              fontFamily: 'ProximaNova',
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: color,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          _formatTimeAgo(notif.createdAt),
                                          style: TextStyle(
                                            fontFamily: 'ProximaNova',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: subtextColor,
                                          ),
                                        ),
                                        if (!notif.isRead) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFFF5E3A),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),

                                    // Title
                                    Text(
                                      notif.title,
                                      style: TextStyle(
                                        fontFamily: 'ProximaNova',
                                        fontSize: 14,
                                        fontWeight: notif.isRead ? FontWeight.w700 : FontWeight.w800,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),

                                    // Message
                                    Text(
                                      notif.message,
                                      style: TextStyle(
                                        fontFamily: 'ProximaNova',
                                        fontSize: 12.5,
                                        color: subtextColor,
                                        height: 1.35,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),

                                    // Property pill or Action link
                                    if (notif.propertyName != null || notif.actionLabel != null) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          if (notif.propertyName != null)
                                            Expanded(
                                              child: Text(
                                                notif.propertyName!,
                                                style: TextStyle(
                                                  fontFamily: 'ProximaNova',
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? const Color(0xFFB0B7C3) : const Color(0xFF4B5563),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          if (notif.actionLabel != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF262C38) : const Color(0xFFEEF2FF),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                notif.actionLabel!,
                                                style: const TextStyle(
                                                  fontFamily: 'ProximaNova',
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF007AFF),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
