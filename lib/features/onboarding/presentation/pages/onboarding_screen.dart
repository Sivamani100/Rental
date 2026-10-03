import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:lottie/lottie.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/core/widgets/bouncing_button.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rental/features/home/presentation/pages/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  // ── Splash / Loading phase ────────────────────────────────────────────────
  bool _showSplash = true;

  // Location state on splash
  bool _isLocating = true;          // still fetching
  String? _locationCity;            // e.g. "Palacherla"
  String? _locationSubtext;         // e.g. "Palacherla, Andhra Pradesh, India"
  bool _locationDenied = false;     // permission denied

  // ── Onboarding page control ───────────────────────────────────────────────
  
  Color get accentTextColor {
    final isAccentDark = ThemeData.estimateBrightnessForColor(AppTheme.swiggyOrange) == Brightness.dark;
    return isAccentDark ? Colors.white : const Color(0xFF1A1A1A);
  }

  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 2;

  Timer? _notifTimer;
  int _currentNotifIndex = 0;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // ── Splash logo bounce / fade ─────────────────────────────────────────────
  late final AnimationController _splashLogoController;
  late final Animation<double> _splashLogoScale;
  late final Animation<double> _splashLogoFade;

  // ── Location found: fade-in of city text ─────────────────────────────────
  late final AnimationController _cityFadeController;
  late final Animation<double> _cityFade;

  // ── "Locating" dot pulse ──────────────────────────────────────────────────
  late final AnimationController _locatingController;

  // ── Icon Cycling ──────────────────────────────────────────────────
  Timer? _iconCycleTimer;
  int _iconCycleIndex = 0;
  late AnimationController _iconSlideController;
  late Animation<Offset> _iconSlide;
  late Animation<double> _iconFade;
  static const List<String> _splashIcons = [
    'assets/icons/home.png',
    'assets/icons/stall.png',
    'assets/icons/cot.png',
    'assets/icons/snag.png',
    'assets/icons/logoblack.png',
  ];


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

    // Splash logo pop-in animation
    _splashLogoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _splashLogoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _splashLogoController, curve: Curves.elasticOut),
    );
    _splashLogoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _splashLogoController, curve: const Interval(0, 0.4)),
    );

    // City name fade-in after location found
    _cityFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cityFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cityFadeController, curve: Curves.easeIn),
    );

    // "Locating" pulsing dots
    _locatingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);


    // Icon slide-up animation (plays on each cycle)
    _iconSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _iconSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _iconSlideController,
      curve: Curves.easeOutCubic,
    ));
    _iconFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _iconSlideController, curve: const Interval(0, 0.6)),
    );
    _iconSlideController.forward();

    // Icon cycling timer — switches icon every 1.1s
    _iconCycleTimer = Timer.periodic(const Duration(milliseconds: 1100), (_) {
      if (mounted) {
        _iconSlideController.reset();
        setState(() {
          _iconCycleIndex = (_iconCycleIndex + 1) % _splashIcons.length;
        });
        _iconSlideController.forward();
      }
    });

    // Play logo animation immediately
    _splashLogoController.forward();

    // Request location permission directly on splash but force 3s max timeout
    Future.any([
      _requestLocationOnSplash(),
      Future.delayed(const Duration(seconds: 3)).then((_) {
        if (mounted) _handleLocationError();
      }),
    ]);

    // Permission pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  /// Requests location permission during the splash screen,
  /// reverse-geocodes the result, displays it, then transitions.
  Future<void> _requestLocationOnSplash() async {
    try {
      // 1. Request permission via permission_handler first
      if (!kIsWeb) {
        final status = await Permission.locationWhenInUse.request();
        if (status.isPermanentlyDenied) {
          _handleLocationDenied();
          return;
        }
      }

      // 2. Double-check via Geolocator
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        _handleLocationDenied();
        return;
      }

      // 3. Try last known position first (instant)
      Position? position;
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      // 4. If no cached position, get a fresh one with a STRICT 5s timeout
      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 5),
            ),
          );
        } catch (_) {
          // Immediately fail gracefully instead of wasting 8 more seconds.
          _handleLocationError();
          return;
        }
      }

      if (position == null) {
        // Couldn't get position at all, proceed gracefully
        _handleLocationError();
        return;
      }

      // 5. Reverse geocode
      String city = 'Your Location';
      String subtext = '';
      try {
        final placemarks = await Geocoding()
            .placemarkFromCoordinates(position.latitude, position.longitude)
            .timeout(const Duration(seconds: 5));
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          city = p.subLocality?.isNotEmpty == true
              ? p.subLocality!
              : p.locality?.isNotEmpty == true
                  ? p.locality!
                  : p.administrativeArea ?? 'Your Location';

          final parts = <String>[
            if (p.subLocality?.isNotEmpty == true) p.subLocality!,
            if (p.locality?.isNotEmpty == true && p.locality != p.subLocality)
              p.locality!,
            if (p.administrativeArea?.isNotEmpty == true) p.administrativeArea!,
            if (p.country?.isNotEmpty == true) p.country!,
          ];
          subtext = parts.join(', ');
        }
      } catch (_) {
        // Geocoding failed, do NOT falsely claim it was found
        subtext = 'Location unreadable. Tap to select.';
      }

      // 6. Show location on splash
      if (mounted) {
        setState(() {
          _isLocating = false;
          _isLocationGranted = true;
          _locationCity = city;
          _locationSubtext = subtext;
        });
        _cityFadeController.forward();
      }

      // 7. Hold for 300ms so user can read location
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      _handleLocationError();
      return;
    }

    _transitionFromSplash();
  }

  void _handleLocationDenied() {
    if (mounted) {
      setState(() {
        _isLocating = false;
        _locationDenied = true;
      });
      _cityFadeController.forward();
    }
    Future.delayed(const Duration(milliseconds: 300)).then((_) => _transitionFromSplash());
  }

  void _handleLocationError() {
    if (mounted) {
      setState(() {
        _isLocating = false;
        _locationCity = 'Your Location';
        _locationSubtext = 'Nearby properties loading...';
      });
      _cityFadeController.forward();
    }
    Future.delayed(const Duration(milliseconds: 300)).then((_) => _transitionFromSplash());
  }

  bool _hasTransitioned = false;

  void _transitionFromSplash() {
    if (!mounted || _hasTransitioned) return;
    _hasTransitioned = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(
        initialLocationCity: _locationCity,
        initialLocationSubtext: _locationSubtext,
      )),
    );
  }

  void _startNotifTimer() {
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
      if (!kIsWeb) await Permission.locationWhenInUse.request();
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        if (mounted) setState(() { _isLocationGranted = true; _isRequestingLocation = false; });
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
      if (!kIsWeb) await Permission.notification.request();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', true);
      if (mounted) setState(() { _isNotificationGranted = true; _isRequestingNotification = false; });
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
    _iconCycleTimer?.cancel();
    _iconSlideController.dispose();
    _notifTimer?.cancel();
    _pulseController.dispose();
    _splashLogoController.dispose();
    _cityFadeController.dispose();
    _locatingController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) return _buildSwiggyStyleSplash();
    return _buildOnboarding();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SWIGGY-STYLE SPLASH SCREEN — Yellow bg, icon + location name centered
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSwiggyStyleSplash() {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFFFD600),
        child: SafeArea(
          child: Stack(
            children: [
              // ── Centered content ───────────────────────────────────
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Icon with slide-up + fade-in animation ───────
                    SizedBox(
                      height: 88,
                      child: Center(
                        child: FadeTransition(
                          opacity: _iconFade,
                          child: SlideTransition(
                            position: _iconSlide,
                            child: Transform.rotate(
                              angle: _splashIcons[_iconCycleIndex].contains('logo') ? 0 : -10 * math.pi / 180,
                              child: Builder(
                                builder: (context) {
                                  final isLogo = _splashIcons[_iconCycleIndex].contains('logo');
                                  return Image.asset(
                                    _splashIcons[_iconCycleIndex],
                                    width: isLogo ? 160 : 64,
                                    height: isLogo ? null : 64,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.medium,
                                  );
                                }
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 32),

                    // ── Location text ────────────────────────────────
                    if (_isLocating)
                      _buildLocatingText()
                    else
                      FadeTransition(
                        opacity: _cityFade,
                        child: Column(
                          children: [
                            Text(
                              _locationDenied
                                  ? 'Location Access'
                                  : (_locationCity ?? 'Your Location'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.dmSans(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1A1A1A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _locationDenied
                                  ? 'Enable location for better results'
                                  : (_locationSubtext ?? ''),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF1A1A1A).withValues(alpha: 0.65),
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocatingText() {
    return Text(
      'finding location...',
      style: GoogleFonts.dmSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1A1A1A),
        letterSpacing: 0.2,
      ),
    );
  }



  // ═══════════════════════════════════════════════════════════════════════════
  // ONBOARDING SLIDES
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildOnboarding() {
    final isAccentDark = ThemeData.estimateBrightnessForColor(AppTheme.swiggyOrange) == Brightness.dark;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffold : Colors.white,
      body: Stack(
        children: [
          // Swiggy orange top strip
          Positioned(
            top: 0, left: 0, right: 0, height: 4,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.swiggyOrange, AppTheme.swiggyYellow],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBrand(isDark),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) => setState(() => _currentPage = index),
                    children: [
                      _buildPermissionSlide(
                        isDark: isDark,
                        graphicWidget: _buildLocationGraphic(isDark),
                        title: 'Find Homes Near You',
                        description: 'Allow location access to discover verified rentals, PGs and properties closest to you.',
                        isGranted: _isLocationGranted,
                        isLoading: _isRequestingLocation,
                        grantedLabel: 'Location Permission Granted',
                        pendingLabel: 'Accurate to within a few meters',
                        grantedIcon: CupertinoIcons.location_solid,
                        accentColor: AppTheme.swiggyOrange,
                      ),
                      _buildPermissionSlide(
                        isDark: isDark,
                        graphicWidget: _buildNotificationGraphic(isDark),
                        title: 'Never Miss a Deal',
                        description: 'Get instant alerts on new verified rentals in your area, price drops and property inquiries.',
                        isGranted: _isNotificationGranted,
                        isLoading: _isRequestingNotification,
                        grantedLabel: 'Notifications Enabled',
                        pendingLabel: 'Real-time property alerts',
                        grantedIcon: CupertinoIcons.bell_fill,
                        accentColor: AppTheme.swiggyOrange,
                      ),
                    ],
                  ),
                ),

                // Dot indicators — Swiggy orange style
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_totalPages, (index) {
                      final isSelected = _currentPage == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isSelected ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.swiggyOrange
                              : (isDark ? AppTheme.darkBorder : const Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    }),
                  ),
                ),

                // Swiggy-style CTA button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
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
                          gradient: LinearGradient(
                            colors: [AppTheme.swiggyOrange, Color(0xFFFF9A3C)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.swiggyOrange.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: _isRequestingLocation || _isRequestingNotification
                            ? SizedBox(
                                width: 22,
                                height: 22,child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: accentTextColor,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _currentPage == 0
                                        ? (_isLocationGranted ? 'Continue' : 'Allow Location Access')
                                        : (_isNotificationGranted ? 'Get Started' : 'Allow Notifications'),
                                    style: TextStyle(fontFamily: 'ProximaNova', 
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: accentTextColor,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(
                                    _currentPage == 0
                                        ? CupertinoIcons.location_solid
                                        : (_currentPage == 1 && _isNotificationGranted
                                            ? CupertinoIcons.chevron_right
                                            : CupertinoIcons.bell_fill),
                                    size: 18,
                                    color: accentTextColor,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),

                // Skip link
                if (!(_currentPage == 1 && _isNotificationGranted))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: BouncingButton(
                      onTap: () async {
                        if (_currentPage == 0) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 380),
                            curve: Curves.easeInOutCubic,
                          );
                        } else {
                          await _completeOnboarding();
                        }
                      },
                      child: Text(
                        'Skip for now',
                        style: TextStyle(fontFamily: 'ProximaNova', 
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          decoration: TextDecoration.underline,
                          decorationColor: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBrand(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.swiggyOrange, Color(0xFFFF9A3C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 26,
                  height: 26,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    CupertinoIcons.house_fill,
                    color: const Color(0xFF1A1A1A),
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Rental App',
            style: TextStyle(fontFamily: 'ProximaNova', 
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppTheme.lightTextPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionSlide({
    required bool isDark,
    required Widget graphicWidget,
    required String title,
    required String description,
    required bool isGranted,
    required bool isLoading,
    required String grantedLabel,
    required String pendingLabel,
    required IconData grantedIcon,
    required Color accentColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    graphicWidget,
                    const SizedBox(height: 40),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'ProximaNova', 
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppTheme.lightTextPrimary,
                        letterSpacing: -0.5,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        description,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'ProximaNova', 
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: isGranted
                            ? AppTheme.swiggyGreen.withValues(alpha: 0.12)
                            : (isDark ? AppTheme.darkCard : AppTheme.lightOrangeSurface),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: isGranted
                              ? AppTheme.swiggyGreen.withValues(alpha: 0.4)
                              : AppTheme.swiggyOrange.withValues(alpha: 0.3),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLoading)
                            SizedBox(
                              width: 14,
                              height: 14,child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: accentColor,
                              ),
                            )
                          else
                            Icon(
                              isGranted ? CupertinoIcons.checkmark_alt : grantedIcon,
                              size: 15,
                              color: isGranted ? AppTheme.swiggyGreen : AppTheme.swiggyOrange,
                            ),
                          SizedBox(width: 8),
                          Text(
                            isGranted ? grantedLabel : pendingLabel,
                            style: TextStyle(fontFamily: 'ProximaNova', 
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isGranted ? AppTheme.swiggyGreen : AppTheme.swiggyOrange,
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

  Widget _buildLocationGraphic(bool isDark) {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppTheme.swiggyOrange.withValues(alpha: 0.15),
              AppTheme.swiggyOrange.withValues(alpha: 0.05),
              Colors.transparent,
            ],
          ),
        ),
        child: Center(
          child: SizedBox(
            height: 180,
            width: 240,
            child: ColorFiltered(
              colorFilter: isDark
                  ? const ColorFilter.matrix([-1, 0, 0, 0, 255, 0, -1, 0, 0, 255, 0, 0, -1, 0, 255, 0, 0, 0, 1, 0])
                  : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
              child: Lottie.asset(
                'assets/animations/location.json',
                fit: BoxFit.contain,
                repeat: true,
                errorBuilder: (_, __, ___) => Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.swiggyOrange, Color(0xFFFF9A3C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.swiggyOrange.withValues(alpha: 0.35),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(CupertinoIcons.location_solid, size: 52, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationGraphic(bool isDark) {
    final currentText = _notificationVariants[_currentNotifIndex % _notificationVariants.length];
    return Center(
      child: SizedBox(
        width: double.infinity,
        height: 120,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 700),
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, -0.25),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Container(
            key: ValueKey<int>(_currentNotifIndex),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.swiggyOrange, Color(0xFFFF9A3C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          CupertinoIcons.house_fill,
                          color: const Color(0xFF1A1A1A),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Rental App',
                            style: TextStyle(fontFamily: 'ProximaNova', 
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppTheme.lightTextPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.swiggyOrange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                color: const Color(0xFF1A1A1A),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        currentText,
                        style: TextStyle(fontFamily: 'ProximaNova', 
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          height: 1.4,
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

// ═══════════════════════════════════════════════════════════════════════════════
// SWIGGY "S" PIN-DROP LOGO PAINTER
// ═══════════════════════════════════════════════════════════════════════════════
class _SwiggyLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Draw a pin-drop teardrop shape
    final path = Path();

    // Top circle center
    final cx = w / 2;
    final cy = w / 2; // Circle height = width
    final r = w / 2;

    // Teardrop: semicircle on top + triangle pointing down
    path.addArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      3.14, // π  = left side
      3.14, // π  = top semicircle
    );

    // Right side of top circle going down to point
    path.lineTo(cx, h);
    path.lineTo(cx - r, cy);
    path.close();

    // Draw full circle on top
    final circlePath = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));

    // Combined pin-drop path
    final fullPath = Path.combine(PathOperation.union, circlePath, path);
    canvas.drawPath(fullPath, paint);

    // Draw "S" letter cutout in orange
    final sPaint = Paint()
      ..color = const Color(0xFFFC8019)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.095
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Draw stylized S using bezier curves centered in the circle
    final sPath = Path();
    final sc = Offset(cx, cy);
    final sr = r * 0.42;

    // Top arc of S (going left)
    sPath.moveTo(sc.dx + sr * 0.7, sc.dy - sr * 0.55);
    sPath.cubicTo(
      sc.dx + sr * 0.7, sc.dy - sr * 1.1,  // control1
      sc.dx - sr * 0.7, sc.dy - sr * 1.1,  // control2
      sc.dx - sr * 0.7, sc.dy - sr * 0.55, // end
    );
    sPath.cubicTo(
      sc.dx - sr * 0.7, sc.dy - sr * 0.0,  // control1
      sc.dx + sr * 0.7, sc.dy - sr * 0.0,  // control2
      sc.dx + sr * 0.7, sc.dy + sr * 0.55, // end
    );
    sPath.cubicTo(
      sc.dx + sr * 0.7, sc.dy + sr * 1.1,  // control1
      sc.dx - sr * 0.7, sc.dy + sr * 1.1,  // control2
      sc.dx - sr * 0.7, sc.dy + sr * 0.55, // end
    );

    canvas.drawPath(sPath, sPaint);
  }

  @override
  bool shouldRepaint(_SwiggyLogoPainter oldDelegate) => false;
}
