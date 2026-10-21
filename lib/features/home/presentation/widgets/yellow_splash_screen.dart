import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class YellowSplashScreen extends StatefulWidget {
  final bool isLocating;
  final String? city;
  final String? subtext;
  final bool isDenied;
  final VoidCallback? onComplete;

  const YellowSplashScreen({
    super.key,
    required this.isLocating,
    this.city,
    this.subtext,
    this.isDenied = false,
    this.onComplete,
  });

  @override
  State<YellowSplashScreen> createState() => YellowSplashScreenState();
}

class YellowSplashScreenState extends State<YellowSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;

  late final AnimationController _dotsController;
  late final AnimationController _cityFadeController;
  late final Animation<double> _cityFade;

  bool _minLocatingTimeElapsed = false;
  bool _hasTriggeredCityFade = false;
  Timer? _minTimeTimer;

  @override
  void initState() {
    super.initState();

    // 1. Logo pop-in animation (starts immediately, brisk 220ms)
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeIn,
      ),
    );
    _logoController.forward();

    late final AnimationController dotsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat();
    _dotsController = dotsCtrl;

    // 3. City fade controller
    _cityFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _cityFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cityFadeController, curve: Curves.easeIn),
    );

    // Ensure 'finding location...' displays briskly for 480ms before revealing city
    _minTimeTimer = Timer(const Duration(milliseconds: 480), () {
      if (mounted) {
        _minLocatingTimeElapsed = true;
        _checkAndTransitionToCity();
      }
    });
  }

  @override
  void didUpdateWidget(YellowSplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isLocating && widget.city != null) {
      _checkAndTransitionToCity();
    }
  }

  void _checkAndTransitionToCity() {
    if (!_minLocatingTimeElapsed || _hasTriggeredCityFade || !mounted) return;
    if (widget.city != null || !widget.isLocating) {
      _hasTriggeredCityFade = true;
      setState(() {});
      _cityFadeController.forward();

      if (widget.onComplete != null) {
        Timer(const Duration(milliseconds: 320), () {
          if (mounted) widget.onComplete!();
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/icons/logoblack.png'), context);
  }

  @override
  void dispose() {
    _minTimeTimer?.cancel();
    _logoController.dispose();
    _dotsController.dispose();
    _cityFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    child: _buildBottomText(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomText() {
    if (_hasTriggeredCityFade || (widget.city != null && _minLocatingTimeElapsed)) {
      return _buildLocationText();
    }

    return _buildFindingLocationText();
  }

  Widget _buildFindingLocationText() {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, _) {
        final dotCount = (_dotsController.value * 3).floor() + 1;
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

  Widget _buildLocationText() {
    return FadeTransition(
      opacity: _cityFade,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.city != null) ...[
            Text(
              widget.city!,
              style: GoogleFonts.dmSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1A1A),
                letterSpacing: -0.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
          ],
          if (widget.subtext != null && widget.subtext!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                widget.subtext!,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1A1A1A).withValues(alpha: 0.7),
                  letterSpacing: 0.1,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}