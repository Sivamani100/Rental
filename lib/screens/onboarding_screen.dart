import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:lottie/lottie.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/bouncing_button.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 2;

  Timer? _notifTimer;
  int _currentNotifIndex = 0;

  final List<String> _notificationVariants = const [
    'Look at this gorgeous 3BHK home with spacious balcony in Danavaipeta',
    'Thinking of buying a dream house? Gated villa on AV Appa Rao Road',
    'New 2 BHK flat available 650m away near Morampudi Junction',
    'Rent reduced by ₹2,000! Price dropped on Prakash Nagar home',
    'Deluxe AC room just opened in Tadithota near Kotipalli stand',
  ];

  bool _isLocationGranted = false;
  bool _isRequestingLocation = false;

  bool _isNotificationGranted = false;
  bool _isRequestingNotification = false;

  @override
  void initState() {
    super.initState();
    _checkInitialPermissions();
    _notifTimer = Timer.periodic(const Duration(milliseconds: 4500), (_) {
      if (mounted) {
        setState(() {
          _currentNotifIndex = (_currentNotifIndex + 1) % _notificationVariants.length;
        });
      }
    });
  }

  Future<void> _checkInitialPermissions() async {
    try {
      final locStatus = await Permission.locationWhenInUse.status;
      if (locStatus.isGranted) {
        if (mounted) setState(() => _isLocationGranted = true);
      }

      final notifStatus = await Permission.notification.status;
      if (notifStatus.isGranted) {
        if (mounted) setState(() => _isNotificationGranted = true);
      }
    } catch (_) {}
  }

  Future<void> _requestLocationPermission() async {
    setState(() => _isRequestingLocation = true);
    try {
      if (!kIsWeb) {
        await Permission.locationWhenInUse.request();
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        if (mounted) {
          setState(() {
            _isLocationGranted = true;
            _isRequestingLocation = false;
          });
        }
      } else {
        if (mounted) setState(() => _isRequestingLocation = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isRequestingLocation = false);
    }
    if (mounted) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _requestNotificationPermission() async {
    setState(() => _isRequestingNotification = true);
    try {
      if (!kIsWeb) {
        await Permission.notification.request();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', true);
      if (mounted) {
        setState(() {
          _isNotificationGranted = true;
          _isRequestingNotification = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isRequestingNotification = false);
    }
    await _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffold : Colors.white,
      body: SafeArea(
        child: Column(
          children: [


            // Page View with Exactly 2 Permission Screens
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  // Screen 1: Location Access
                  _buildPermissionCardSlide(
                    isDark: isDark,
                    mutedColor: mutedColor,
                    graphicWidget: _buildLocationGraphicCard(isDark),
                    title: 'Find Nearby Homes & PGs',
                    description:
                        'Allow location access to calculate exact walking & driving distances and discover properties closest to you.',
                    isGranted: _isLocationGranted,
                    isLoading: _isRequestingLocation,
                    grantedLabel: 'Location Permission Granted',
                    pendingLabel: 'Accurate to within a few meters',
                    grantedIcon: Iconsax.location,
                  ),

                  // Screen 2: Push Notifications Access
                  _buildPermissionCardSlide(
                    isDark: isDark,
                    mutedColor: mutedColor,
                    graphicWidget: _buildNotificationBannerGraphic(isDark),
                    title: 'Instant Alerts & Price Drops',
                    description:
                        'Never miss a new verified rental in your area, price drop alerts, or direct inquiries from property owners.',
                    isGranted: _isNotificationGranted,
                    isLoading: _isRequestingNotification,
                    grantedLabel: 'Notifications Enabled',
                    pendingLabel: 'Real-time property alerts',
                    grantedIcon: Iconsax.notification,
                  ),
                ],
              ),
            ),

            // Page Indicator Dots
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalPages, (index) {
                  final isSelected = _currentPage == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isSelected ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryYellow
                          : (isDark ? AppTheme.darkBorder : Colors.black.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  );
                }),
              ),
            ),

            // Bottom CTA Action Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 60),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: BouncingButton(
                  onTap: () {
                    if (_currentPage == 0) {
                      _requestLocationPermission();
                    } else {
                      _requestNotificationPermission();
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white : const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentPage == 0
                              ? (_isLocationGranted ? 'Continue' : 'Enable Location Access')
                              : (_isNotificationGranted ? 'Get Started' : 'Enable Notifications & Start'),
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.black : Colors.white,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _currentPage == 0
                              ? Iconsax.location5
                              : (_currentPage == 1 && _isNotificationGranted
                                  ? Iconsax.arrow_right_3
                                  : Iconsax.notification5),
                          size: 17,
                          color: isDark ? Colors.black : Colors.white,
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
    );
  }

  Widget _buildPermissionCardSlide({
    required bool isDark,
    required Color mutedColor,
    required Widget graphicWidget,
    required String title,
    required String description,
    required bool isGranted,
    required bool isLoading,
    required String grantedLabel,
    required String pendingLabel,
    required IconData grantedIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Centered Group: Animation + Title + Description + Status Badge
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Graphic Animation
                    graphicWidget,
                    const SizedBox(height: 40),

                    // Title Headline
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                        letterSpacing: -0.8,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Description Subtitle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        description,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: mutedColor,
                          height: 1.4,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Permission Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isGranted
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : (isDark ? AppTheme.darkCardElevated : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isGranted
                              ? const Color(0xFF10B981).withValues(alpha: 0.3)
                              : (isDark ? AppTheme.darkBorder : Colors.black.withValues(alpha: 0.06)),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLoading)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryYellow),
                            )
                          else
                            Icon(
                              isGranted ? Iconsax.tick_circle5 : grantedIcon,
                              size: 15,
                              color: isGranted
                                  ? const Color(0xFF10B981)
                                  : (isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                            ),
                          const SizedBox(width: 8),
                          Text(
                            isGranted ? grantedLabel : pendingLabel,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isGranted
                                  ? const Color(0xFF10B981)
                                  : (isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationGraphicCard(bool isDark) {
    return SizedBox(
      width: 270,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ColorFiltered(
            colorFilter: isDark
                ? const ColorFilter.matrix([-1, 0, 0, 0, 255, 0, -1, 0, 0, 255, 0, 0, -1, 0, 255, 0, 0, 0, 1, 0])
                : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
            child: Lottie.asset(
              'assets/location.json',
              fit: BoxFit.contain,
              repeat: true,
              errorBuilder: (_, _, _) => Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.primaryYellow.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Iconsax.location5,
                    size: 56,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBannerGraphic(bool isDark) {
    final currentText = _notificationVariants[_currentNotifIndex % _notificationVariants.length];

    return Center(
      child: SizedBox(
        width: double.infinity,
        height: 120,
        child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 1000),
                switchInCurve: Curves.easeInOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                transitionBuilder: (child, animation) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, -0.2),
                      end: Offset.zero,
                    ).animate(animation),
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  key: ValueKey<int>(_currentNotifIndex),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCardElevated : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.darkBorder
                          : Colors.black.withValues(alpha: 0.08),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.10),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Brand Logo Container
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/logo.png',
                              width: 32,
                              height: 32,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.auto_awesome,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Notification Text Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Rental App',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              currentText,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : const Color(0xFF4B5563),
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
  }
}
