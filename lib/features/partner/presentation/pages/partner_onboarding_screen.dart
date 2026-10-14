import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/core/widgets/bouncing_button.dart';
import 'package:rental/features/partner/data/services/partner_service.dart';
import 'package:rental/features/partner/presentation/pages/partner_auth_screen.dart';
import 'package:rental/features/partner/presentation/pages/partner_dashboard_screen.dart';

class PartnerOnboardingScreen extends StatefulWidget {
  const PartnerOnboardingScreen({super.key});

  @override
  State<PartnerOnboardingScreen> createState() => _PartnerOnboardingScreenState();
}

class _PartnerOnboardingScreenState extends State<PartnerOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<({
    String badge,
    String title,
    String description,
    IconData icon,
    Color accentColor,
    List<String> highlights,
  })> _slides = [
    (
      badge: 'PROPERTY OWNER HUB',
      title: 'Own or Manage\nYour Properties',
      description:
          'Take full command of your real estate portfolio. Whether you are an individual homeowner or a property manager, easily control all your flats, PGs, and houses in one place.',
      icon: Iconsax.building_4,
      accentColor: const Color(0xFFFF9500),
      highlights: [
        'Dedicated dashboard for all your properties',
        'Direct connection to verified tenant inquiries',
        'Built for both individual owners & dealers',
      ],
    ),
    (
      badge: 'REAL-TIME CONTROL',
      title: 'Instant Availability\n& Live Edits',
      description:
          'Mark your property as Available or Occupied in a single tap. Edit rent prices, modify amenities, and keep your listings accurately updated at any moment.',
      icon: Iconsax.slider_horizontal_1,
      accentColor: const Color(0xFF34C759),
      highlights: [
        '1-Tap live "Available / Occupied" toggle',
        'Update rent, deposits, and house rules on the go',
        'Stop receiving calls when your property is full',
      ],
    ),
    (
      badge: 'SEAMLESS HANDOVER',
      title: 'Admin Handover &\nInstant Uploads',
      description:
          'Already have a property listed on Rental App? Use the "Ask Admin" button to claim ownership without re-uploading! Or post new properties for swift admin review.',
      icon: Iconsax.shield_security,
      accentColor: AppTheme.primaryYellow,
      highlights: [
        '1-Click "Ask Admin" to link existing listings',
        'Direct upload pipeline for brand new properties',
        'Instant notifications on admin approvals',
      ],
    ),
  ];

  void _onNext() {
    HapticFeedback.selectionClick();
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() async {
    await PartnerService.instance.completeOnboarding();
    if (!mounted) return;

    if (PartnerService.instance.isLoggedIn) {
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(builder: (_) => const PartnerDashboardScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(builder: (_) => const PartnerAuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF7F7F9);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Back & Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Iconsax.arrow_left, size: 22, color: textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                  TextButton(
                    onPressed: _finishOnboarding,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page View
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Visual Icon Badge
                        Center(
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  slide.accentColor.withValues(alpha: 0.22),
                                  slide.accentColor.withValues(alpha: 0.04),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: slide.accentColor.withValues(alpha: 0.35),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                slide.icon,
                                size: 48,
                                color: slide.accentColor == AppTheme.primaryYellow && !isDark
                                    ? const Color(0xFFD97706)
                                    : slide.accentColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Badge Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: slide.accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: slide.accentColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            slide.badge,
                            style: TextStyle(
                              fontFamily: 'ProximaNova',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: slide.accentColor == AppTheme.primaryYellow && !isDark
                                  ? const Color(0xFFD97706)
                                  : slide.accentColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Title
                        Text(
                          slide.title,
                          style: TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Description
                        Text(
                          slide.description,
                          style: TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 14,
                            height: 1.45,
                            color: subtextColor,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Highlights
                        ...slide.highlights.map((h) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Iconsax.tick_circle5,
                                    size: 16,
                                    color: slide.accentColor == AppTheme.primaryYellow && !isDark
                                        ? const Color(0xFFD97706)
                                        : slide.accentColor,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      h,
                                      style: TextStyle(
                                        fontFamily: 'ProximaNova',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Navigation & Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page Indicators
                  Row(
                    children: List.generate(_slides.length, (i) {
                      final isActive = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 6),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppTheme.primaryYellow
                              : (isDark ? Colors.white24 : Colors.black12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  // Next / Get Started Button
                  BouncingButton(
                    onTap: _onNext,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryYellow,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryYellow.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentPage == _slides.length - 1
                                ? 'Get Started'
                                : 'Next',
                            style: const TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Iconsax.arrow_right_3,
                            size: 16,
                            color: Colors.black,
                          ),
                        ],
                      ),
                    ),
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
