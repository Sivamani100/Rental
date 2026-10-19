import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rental/app/theme/app_theme.dart';

class PartnerBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int propertyCount;
  final int activePromotionsCount;

  const PartnerBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.propertyCount = 0,
    this.activePromotionsCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeTextColor = isDark ? Colors.white : Colors.black87;
    final inactiveIconColor = isDark
        ? Colors.grey.shade500
        : Colors.grey.shade400;
    final bgColor = isDark ? AppTheme.darkScaffold : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : Colors.grey.shade200;

    final tabItems = [
      (
        label: 'Home',
        activeIcon: CupertinoIcons.house_fill,
        inactiveIcon: CupertinoIcons.house,
        badge: null,
      ),
      (
        label: 'Properties',
        activeIcon: CupertinoIcons.square_stack_3d_up_fill,
        inactiveIcon: CupertinoIcons.square_stack_3d_up,
        badge: propertyCount > 0 ? '$propertyCount' : null,
      ),
      (
        label: 'Analytics',
        activeIcon: CupertinoIcons.chart_bar_alt_fill,
        inactiveIcon: CupertinoIcons.chart_bar,
        badge: null,
      ),
      (
        label: 'Promote',
        activeIcon: CupertinoIcons.flame_fill,
        inactiveIcon: CupertinoIcons.flame,
        badge: activePromotionsCount > 0 ? '$activePromotionsCount' : null,
      ),
      (
        label: 'Profile',
        activeIcon: CupertinoIcons.person_crop_circle_fill,
        inactiveIcon: CupertinoIcons.person_crop_circle,
        badge: null,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(tabItems.length, (index) {
              final isSelected = currentIndex == index;
              final item = tabItems[index];

              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap(index);
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            isSelected ? item.activeIcon : item.inactiveIcon,
                            size: 24,
                            color: isSelected ? activeTextColor : inactiveIconColor,
                          ),
                          if (item.badge != null)
                            Positioned(
                              top: -3,
                              right: -8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: index == 3 ? const Color(0xFFFF3B30) : const Color(0xFF007AFF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                constraints: const BoxConstraints(minWidth: 15),
                                child: Text(
                                  item.badge!,
                                  style: const TextStyle(
                                    fontFamily: 'ProximaNova',
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.1,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          color: isSelected
                              ? activeTextColor
                              : inactiveIconColor,
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
