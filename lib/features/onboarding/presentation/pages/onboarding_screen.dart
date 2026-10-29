import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:lottie/lottie.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/core/widgets/bouncing_button.dart';
import 'package:rental/core/services/location_helper.dart';
import 'package:rental/core/services/deep_link_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rental/features/home/presentation/pages/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  // ── Splash / Loading phase ──────────────────────────────────────────
  bool _showSplash = true;

  // Location state on splash
  String? _locationCity;
  String? _locationSubtext;
  Position? _locationPosition;
  bool _locationDenied = false;

  // Splash progression flags
  bool _showFindingLocation = true;
  bool _showLocationResult = false;
  bool _minLocatingTimeElapsed = false;
  bool _locationFetchDone = false;
  bool _hasShownLocationResult = false;
  bool _hasTransitioned = false;

  Timer? _minLocatingTimer;
  Timer? _safetyTimeoutTimer;

  // ── Splash logo pop-in animation ─────────────────────────────────────
  late final AnimationController _splashLogoController;
  late final Animation<double> _splashLogoScale;
  late final Animation<double> _splashLogoFade;

  // ── "finding location..." animated dots ──────────────────────────────
  late final AnimationController _locatingDotsController;

  // ── Location found: fade-in of city text ─────────────────────────────
  late final AnimationController _cityFadeController;
  late final Animation<double> _cityFade;

  // ── Onboarding page control ──────────────────────────────────────────
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

  final List<String> _notificationVariants = const [
    'Look at this gorgeous 3BHK home with spacious balcony in Diwancheruvu',
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

    // 1. Splash logo pop-in animation (starts immediately at 0ms, brisk 180ms)
    _splashLogoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _splashLogoScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _splashLogoController, curve: Curves.easeOutCubic),
    );
    _splashLogoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _splashLogoController, curve: Curves.easeIn),
    );
    _splashLogoController.forward();

    // 2. "finding location..." animated dots controller (fast brisk cycle)
    _locatingDotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat();

    // 3. City name fade-in controller
    _cityFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _cityFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cityFadeController, curve: Curves.easeIn),
    );

    // 4. Permission pulse animation for onboarding slides
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 5. Start location detection concurrently in background
    _fetchLocationForSplash();

    // Step 1: "finding location..." is visible immediately from 0ms.
    // Step 2: Keep "finding location..." visible for 480ms, then reveal detected city
    _minLocatingTimer = Timer(const Duration(milliseconds: 480), () {
      if (mounted) {
        _minLocatingTimeElapsed = true;
        _checkAndShowLocationResult();
      }
    });

    // Safety timeout: Swift fallback so user never gets stuck on splash screen
    _safetyTimeoutTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted && !_hasShownLocationResult) {
        _minLocatingTimeElapsed = true;
        _locationFetchDone = true;
        if (_locationCity == null) {
          _locationCity = LocationHelper.defaultCity;
          _locationSubtext = LocationHelper.defaultArea;
        }
        _checkAndShowLocationResult();
      }
    });

    // Hard failsafe timer: Splash NEVER stays on screen longer than 2.8s
    Timer(const Duration(milliseconds: 2800), () {
      if (mounted && !_hasTransitioned) {
        debugPrint("[OnboardingScreen] Failsafe timer fired, forcing transition to HomeScreen");
        _transitionFromSplash();
      }
    });

    if (!_showSplash) {
      _startNotifTimer();
      _checkInitialPermissions();
    }
  }

  /// Requests location permission first thing, grabs accurate GPS coordinates and reverse geocodes locality
  Future<void> _fetchLocationForSplash() async {
    try {
      final result = await LocationHelper.fetchInitialLocation(
        gpsTimeout: kIsWeb ? const Duration(milliseconds: 1500) : const Duration(seconds: 3),
      );
      _locationPosition = result.position;
      _onLocationResolved(
        city: result.city,
        subtext: result.area,
        isDenied: result.isPermissionDenied,
      );
    } catch (_) {
      _onLocationResolved(
        city: LocationHelper.defaultCity,
        subtext: LocationHelper.defaultArea,
        isDenied: false,
      );
    }
  }

  void _onLocationResolved({
    required String city,
    required String subtext,
    required bool isDenied,
  }) {
    if (!mounted) return;
    _safetyTimeoutTimer?.cancel();
    _locationCity = city;
    _locationSubtext = subtext;
    _locationDenied = isDenied;
    _locationFetchDone = true;
    _checkAndShowLocationResult();
  }

  /// Triggers the city name fade-in ONLY after "finding location..." has had its guaranteed display time
  void _checkAndShowLocationResult() {
    if (!_minLocatingTimeElapsed || !_locationFetchDone || _hasShownLocationResult || !mounted) return;
    _hasShownLocationResult = true;

    setState(() {
      _showFindingLocation = false;
      _showLocationResult = true;
    });
    _cityFadeController.forward();

    // Give the user 300ms to appreciate the detected city before transitioning
    Timer(const Duration(milliseconds: 300), () {
      if (mounted) _transitionFromSplash();
    });
  }

  void _transitionFromSplash() async {
    if (!mounted || _hasTransitioned) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_completed_onboarding', true);
    } catch (_) {}

    if (!mounted) return;

    final isDeepLinkActive = DeepLinkService.instance.isHandlingDeepLink;
    if (isDeepLinkActive) {
      debugPrint("[OnboardingScreen] Deep link in progress. Preserving top route.");
      _hasTransitioned = true;
      return;
    }

    _hasTransitioned = true;

    // Use pushAndRemoveUntil with rootNavigator to guarantee HomeScreen is presented cleanly
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => HomeScreen(
          initialLocationCity: _locationCity ?? LocationHelper.defaultCity,
          initialLocationSubtext: _locationSubtext ?? LocationHelper.defaultArea,
          initialPosition: _locationPosition,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
      (route) => false,
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
      if (DeepLinkService.instance.isHandlingDeepLink) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            initialLocationCity: _locationCity ?? LocationHelper.defaultCity,
            initialLocationSubtext: _locationSubtext ?? LocationHelper.defaultArea,
            initialPosition: _locationPosition,
          ),
        ),
        (route) => false,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/icons/logoblack.png'), context);
  }

  @override
  void dispose() {
    _minLocatingTimer?.cancel();
    _safetyTimeoutTimer?.cancel();
    _notifTimer?.cancel();
    _pulseController.dispose();
    _splashLogoController.dispose();
    _locatingDotsController.dispose();
    _cityFadeController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _showSplash ? _buildSwiggyStyleSplash() : _buildOnboarding();
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // SWIGGY-STYLE SPLASH SCREEN â€” Yellow bg, icon + location name centered
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _buildSwiggyStyleSplash() {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFFFFD600),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFFD600),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. Black logo icon — immediately rendered from frame 0 with zero blank frames
                Image.asset(
                  'assets/icons/logoblack.png',
                  width: 52,
                  height: 52,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                    if (wasSynchronouslyLoaded || frame != null) {
                      return child;
                    }
                    return Transform.rotate(
                      angle: 0.6,
                      child: const Icon(
                        Icons.navigation_rounded,
                        size: 46,
                        color: Color(0xFF1A1A1A),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // 2. Animated text below logo
                SizedBox(
                  height: 68,
                  child: Center(
                    child: _buildSplashBottomText(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSplashBottomText() {
    if (_showLocationResult) {
      return FadeTransition(
        opacity: _cityFade,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _locationDenied
                  ? 'Location Access'
                  : (_locationCity ?? 'Your Location'),
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1A1A),
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            if ((_locationSubtext ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _locationDenied
                      ? 'Enable location for better results'
                      : (_locationSubtext ?? ''),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1A1A1A).withValues(alpha: 0.7),
                    letterSpacing: 0.1,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Default from frame 0: Black logo icon with animated "finding location..."
    return AnimatedBuilder(
      animation: _locatingDotsController,
      builder: (context, _) {
        final dotCount = (_locatingDotsController.value * 3).floor() + 1;
        final dots = '.' * dotCount;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'finding location',
              style: GoogleFonts.dmSans(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1A1A),
                letterSpacing: -0.2,
              ),
            ),
            SizedBox(
              width: 22,
              child: Text(
                dots,
                style: GoogleFonts.dmSans(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A1A1A),
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOnboarding() {
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

                // Dot indicators â€” Swiggy orange style
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

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// SWIGGY "S" PIN-DROP LOGO PAINTER
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// (Legacy painter removed)
