import 'package:flutter/material.dart';
import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/features/home/presentation/widgets/skeleton_box.dart';
import 'package:rental/features/home/presentation/widgets/shimmer_effect.dart';

class SkeletonPropertyCard extends StatelessWidget {
  const SkeletonPropertyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.transparent,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ShimmerEffect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area shimmer
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: const SkeletonBox(
                    width: double.infinity,
                    height: 200,
                    borderRadius: 0,
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 56,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkCardElevated.withValues(alpha: 0.8)
                          : Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Price row
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonBox(width: 140, height: 18, borderRadius: 6),
                      SkeletonBox(width: 75, height: 18, borderRadius: 6),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Location row
                  Row(
                    children: [
                      const SkeletonBox(width: 16, height: 16, borderRadius: 8),
                      const SizedBox(width: 6),
                      SkeletonBox(
                        width: MediaQuery.of(context).size.width * 0.45,
                        height: 13,
                        borderRadius: 4,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Single row tags
                  const Row(
                    children: [
                      SkeletonBox(width: 65, height: 26, borderRadius: 30),
                      SizedBox(width: 8),
                      SkeletonBox(width: 95, height: 26, borderRadius: 30),
                      SizedBox(width: 8),
                      SkeletonBox(width: 80, height: 26, borderRadius: 30),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(
                    height: 1,
                    color: isDark ? AppTheme.darkBorder : const Color(0xFFEEEEEE),
                  ),
                  const SizedBox(height: 14),
                  // Bottom stats row
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SkeletonBox(width: 60, height: 14, borderRadius: 4),
                      SkeletonBox(width: 60, height: 14, borderRadius: 4),
                      SkeletonBox(width: 65, height: 14, borderRadius: 4),
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

class SkeletonGridCard extends StatelessWidget {
  const SkeletonGridCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161822) : const Color(0xFFE8EAF0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF232736) : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: ShimmerEffect(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 52,
                height: 18,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF25293A) : const Color(0xFFD6DAE5),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2E344A) : const Color(0xFFCDD2E0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF25293A) : const Color(0xFFD6DAE5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: 80,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF25293A) : const Color(0xFFD6DAE5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
