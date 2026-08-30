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
  static const int _totalPages = 5;

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

  bool _isPhotosGranted = false;
  bool _isRequestingPhotos = false;

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

      final photoStatus = await Permission.photos.status;
      final cameraStatus = await Permission.camera.status;
      if (photoStatus.isGranted || cameraStatus.isGranted) {
        if (mounted) setState(() => _isPhotosGranted = true);
      }
    } catch (_) {}
  }

  Future<void> _requestLocationPermission() async {
    setState(() => _isRequestingLocation = true);
    try {
      if (!kIsWeb) {
        final status = await Permission.locationWhenInUse.request();
        if (status.isGranted) {
          if (mounted) setState(() => _isLocationGranted = true);
        }
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
          _autoAdvance(1);
        }
      } else {
        if (mounted) setState(() => _isRequestingLocation = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isRequestingLocation = false);
    }
  }

  Future<void> _requestNotificationPermission() async {
    setState(() => _isRequestingNotification = true);
    try {
      if (!kIsWeb) {
        final status = await Permission.notification.request();
        if (status.isGranted) {
          if (mounted) setState(() => _isNotificationGranted = true);
        }
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', true);

      if (mounted) {
        setState(() {
          _isNotificationGranted = true;
          _isRequestingNotification = false;
        });
        _autoAdvance(2);
      }
    } catch (_) {
      if (mounted) setState(() => _isRequestingNotification = false);
    }
  }

  Future<void> _requestPhotosPermission() async {
    setState(() => _isRequestingPhotos = true);
    try {
      if (!kIsWeb) {
        await [
          Permission.camera,
          Permission.photos,
          Permission.storage,
        ].request();
      }

      if (mounted) {
        setState(() {
          _isPhotosGranted = true;
          _isRequestingPhotos = false;
        });
        _autoAdvance(3);
      }
    } catch (_) {
      if (mounted) setState(() => _isRequestingPhotos = false);
    }
  }

  void _autoAdvance(int pageIndex) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _currentPage == pageIndex) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
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

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffold : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Back and Skip Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button (shown on slides > 0)
                  if (_currentPage > 0)
                    IconButton(
                      icon: Icon(
                        Iconsax.arrow_left_2,
                        color: isDark ? Colors.white : Colors.black87,
                        size: 22,
                      ),
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    )
                  else
                    const SizedBox(width: 48, height: 48),

                  // Skip Button (shown before final slide)
                  if (_currentPage < _totalPages - 1)
                    TextButton(
                      onPressed: _completeOnboarding,
                      style: TextButton.styleFrom(
                        foregroundColor:
                            isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        textStyle: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Skip'),
                    )
                  else
                    const SizedBox(width: 48, height: 48),
                ],
              ),
            ),

            // Page View with All Onboarding & Permission Slides
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  // Slide 1: Discover Properties
                  _buildSlide(
                    isDark: isDark,
                    animationAsset: 'assets/rental.json',
                    animationScale: 1.40,
                    title: 'Find Genuine Homes & PGs',
                    description:
                        'Explore 100% verified houses, rooms, and properties for sale directly from owners with zero broker fees.',
                  ),

                  // Slide 2: Location Access
                  _buildPermissionSlide(
                    isDark: isDark,
                    animationAsset: 'assets/location.json',
                    animationScale: 1.05,
                    title: 'Nearby Distance & Discovery',
                    description:
                        'We use your location to calculate exact walking and driving distances to properties and show listings closest to you.',
                    isGranted: _isLocationGranted,
                    isLoading: _isRequestingLocation,
                    grantedLabel: 'Location Permission Granted',
                    pendingLabel: 'Accurate to within a few meters',
                    grantedIcon: Iconsax.location,
                  ),

                  // Slide 3: Notifications Access
                  _buildPermissionSlide(
                    isDark: isDark,
                    customWidget: _buildNotificationBannerGraphic(isDark),
                    title: 'Instant Updates & Alerts',
                    description:
                        'Never miss a new verified rental in your area, price drop alerts, or direct inquiries from property owners.',
                    isGranted: _isNotificationGranted,
                    isLoading: _isRequestingNotification,
                    grantedLabel: 'Notifications Enabled',
                    pendingLabel: 'Real-time property alerts',
                    grantedIcon: Iconsax.notification,
                  ),

                  // Slide 4: Camera & Photo Gallery Access
                  _buildPermissionSlide(
                    isDark: isDark,
                    animationAsset: 'assets/photos.json',
                    animationScale: 1.05,
                    title: 'Photos & Camera Access',
                    description:
                        'Allow camera and gallery access to take and upload high-quality room, bath, and kitchen photos when listing.',
                    isGranted: _isPhotosGranted,
                    isLoading: _isRequestingPhotos,
                    grantedLabel: 'Camera & Photos Access Granted',
                    pendingLabel: 'High-res property uploads',
                    grantedIcon: Iconsax.camera,
                  ),

                  // Slide 5: Post & Connect
                  _buildSlide(
                    isDark: isDark,
                    animationAsset: 'assets/buyorsell.json',
                    animationScale: 1.65,
                    title: 'List & Manage in Minutes',
                    description:
                        'Post your house, PG, or property for sale effortlessly with instant photo positioning and direct owner inquiries.',
                  ),
                ],
              ),
            ),
            // Bottom Navigation Area with Action Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: BouncingButton(
                  onTap: () {
                    if (_currentPage == 1 && !_isLocationGranted) {
                      _requestLocationPermission();
                    } else if (_currentPage == 2 && !_isNotificationGranted) {
                      _requestNotificationPermission();
                    } else if (_currentPage == 3 && !_isPhotosGranted) {
                      _requestPhotosPermission();
                    } else if (_currentPage < _totalPages - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _completeOnboarding();
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white : Colors.black,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentPage == _totalPages - 1
                              ? 'Get Started'
                              : (_currentPage == 1 && !_isLocationGranted
                                  ? 'Allow Location Access'
                                  : (_currentPage == 2 && !_isNotificationGranted
                                      ? 'Enable Notifications'
                                      : (_currentPage == 3 && !_isPhotosGranted
                                          ? 'Allow Camera & Photos'
                                          : 'Continue'))),
                          style: GoogleFonts.inter(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.black : Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          _currentPage == _totalPages - 1
                              ? Iconsax.arrow_right_3
                              : (_currentPage == 1 && !_isLocationGranted
                                  ? Iconsax.location
                                  : (_currentPage == 2 && !_isNotificationGranted
                                      ? Iconsax.notification
                                      : (_currentPage == 3 && !_isPhotosGranted
                                          ? Iconsax.camera
                                          : Iconsax.arrow_right_3))),
                          size: 19,
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

  Widget _buildSlide({
    required bool isDark,
    required String animationAsset,
    required String title,
    required String description,
    double animationScale = 1.0,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 240,
            width: double.infinity,
            alignment: Alignment.center,
            child: Transform.scale(
              scale: animationScale,
              child: SizedBox(
                width: 240,
                height: 240,
                child: Lottie.asset(
                  animationAsset,
                  fit: BoxFit.contain,
                  repeat: true,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCard : const Color(0xFFF3F4F6),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Iconsax.building_3,
                            size: 56,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: -0.6,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 38), // Balances the status pill height of permission slides
        ],
      ),
    );
  }

  Widget _buildNotificationBannerGraphic(bool isDark) {
    final currentText = _notificationVariants[_currentNotifIndex % _notificationVariants.length];

    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      child: SizedBox(
        width: 345,
        height: 135,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            // Deepest stacked background card 4 (bottom-most deck layer)
            Positioned(
              top: 30,
              child: Container(
                width: 275,
                height: 74,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : const Color(0xFFDCE0E5),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),

            // Stacked background card 3
            Positioned(
              top: 20,
              child: Container(
                width: 300,
                height: 78,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : const Color(0xFFE5E8EB),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),
            ),

            // Stacked background card 2 (middle deck layer)
            Positioned(
              top: 10,
              child: Container(
                width: 324,
                height: 82,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E24)
                      : const Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),

            // Main Top Active Notification Card with smooth slide-down arrival animation
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 1400),
                switchInCurve: Curves.easeInOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                transitionBuilder: (child, animation) {
                  final isIncoming = child.key == ValueKey<int>(_currentNotifIndex);

                  if (isIncoming) {
                    // New card glides down gently and slowly from above onto the stack
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, -0.28),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeInOutCubic,
                      )),
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.96,
                          end: 1.0,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeInOutCubic,
                        )),
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      ),
                    );
                  } else {
                    // Outgoing card glides down into the stack below slowly
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset.zero,
                        end: const Offset(0.0, 0.28),
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeInOutCubic,
                      )),
                      child: FadeTransition(
                        opacity: Tween<double>(begin: 1.0, end: 0.0).animate(animation),
                        child: child,
                      ),
                    );
                  }
                },
                child: Container(
                  key: ValueKey<int>(_currentNotifIndex),
                  width: 345,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF25252D) : Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Official App Logo Badge
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.asset(
                              'assets/logo.png',
                              width: 30,
                              height: 30,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
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
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              currentText,
                              style: GoogleFonts.inter(
                                fontSize: 12.2,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : const Color(0xFF4B5563),
                                height: 1.35,
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
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionSlide({
    required bool isDark,
    String? animationAsset,
    Widget? customWidget,
    IconData? customIcon,
    required String title,
    required String description,
    required bool isGranted,
    required bool isLoading,
    required String grantedLabel,
    required String pendingLabel,
    required IconData grantedIcon,
    double animationScale = 1.0,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 240,
            width: double.infinity,
            alignment: Alignment.center,
            child: customWidget ??
                (animationAsset != null
                    ? Transform.scale(
                        scale: animationScale,
                        child: SizedBox(
                          width: 240,
                          height: 240,
                          child: Lottie.asset(
                            animationAsset,
                            fit: BoxFit.contain,
                            repeat: true,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: isDark ? AppTheme.darkCard : const Color(0xFFF3F4F6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      customIcon ?? Iconsax.camera5,
                                      size: 56,
                                      color: const Color(0xFFF59E0B),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      )
                    : Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCard : const Color(0xFFF3F4F6),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            customIcon ?? Iconsax.shield_tick5,
                            size: 56,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                      )),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: -0.6,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: isGranted
                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                  : (isDark ? AppTheme.darkCard : const Color(0xFFF3F4F6)),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isGranted
                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    isGranted ? Iconsax.tick_circle : grantedIcon,
                    size: 16,
                    color: isGranted
                        ? const Color(0xFF10B981)
                        : (isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                  ),
                const SizedBox(width: 8),
                Text(
                  isGranted ? grantedLabel : pendingLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
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
    );
  }
}
