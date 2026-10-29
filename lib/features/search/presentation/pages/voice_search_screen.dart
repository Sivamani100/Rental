import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

import 'package:rental/core/models/property_model.dart';
import 'package:rental/core/widgets/bouncing_button.dart';

class VoiceSearchScreen extends StatefulWidget {
  final List<PropertyModel>? properties;
  final ValueChanged<String>? onResult;

  const VoiceSearchScreen({
    super.key,
    this.properties,
    this.onResult,
  });

  /// Opens the voice search modal with a dimmed transparent overlay
  /// keeping the underlying screen visible beneath.
  static Future<String?> open(
    BuildContext context, {
    List<PropertyModel>? properties,
    ValueChanged<String>? onResult,
  }) {
    return Navigator.push<String>(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        pageBuilder: (context, anim, secAnim) => VoiceSearchScreen(
          properties: properties,
          onResult: onResult,
        ),
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (context, anim, secAnim, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  @override
  State<VoiceSearchScreen> createState() => _VoiceSearchScreenState();
}

class _VoiceSearchScreenState extends State<VoiceSearchScreen>
    with TickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;
  bool _hasError = false;
  bool _hasPermission = true;
  bool _hasCompleted = false;
  String _recognizedText = '';
  double _soundLevel = 0.0;

  late final AnimationController _waveController;
  late final Animation<double> _waveAnimation;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  Timer? _suggestionTimer;
  Timer? _silenceTimer;
  int _currentSuggestionIndex = 0;

  static const List<String> _voiceSuggestions = [
    'Hostels in Diwancheruvu',
    '2 BHK in Rajahmundry',
    'Boys PG near RTC',
    'Furnished Rentals',
    'Girls PG in Diwancheruvu',
    'Commercial Space',
    'AC Rooms in Rajahmundry',
  ];

  static const List<String> _retryChips = [
    'Diwancheruvu',
    'Boys Hostel',
    '2 BHK Flat',
    'Rajahmundry',
  ];

  @override
  void initState() {
    super.initState();

    // Rhythmic waveform oscillation
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat();
    _waveAnimation = CurvedAnimation(
      parent: _waveController,
      curve: Curves.linear,
    );

    // Pulse animation for halo glow ring
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Slide up animation for the bottom sheet and close button
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _fadeAnimation = CurvedAnimation(parent: _slideController, curve: Curves.easeOut);
    _slideController.forward();

    // Rotate suggestions every 2.4 seconds when idle
    _suggestionTimer = Timer.periodic(const Duration(milliseconds: 2400), (_) {
      if (mounted && _recognizedText.isEmpty && !_hasError) {
        setState(() {
          _currentSuggestionIndex =
              (_currentSuggestionIndex + 1) % _voiceSuggestions.length;
        });
      }
    });

    _checkPermissionAndInit();
  }

  @override
  void dispose() {
    _suggestionTimer?.cancel();
    _silenceTimer?.cancel();
    _speech.stop();
    _waveController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionAndInit() async {
    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      final res = await Permission.microphone.request();
      if (!res.isGranted) {
        if (mounted) {
          setState(() {
            _hasPermission = false;
            _hasError = true;
          });
        }
        return;
      }
    }

    _initSpeechAndListen();
  }

  Future<void> _initSpeechAndListen() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted || _hasCompleted) return;
          if (status == 'listening') {
            setState(() {
              _isListening = true;
              _hasError = false;
            });
          } else if (status == 'notListening' || status == 'done') {
            setState(() => _isListening = false);
            if (_recognizedText.trim().isNotEmpty) {
              _completeSearch(_recognizedText);
            } else {
              setState(() => _hasError = true);
            }
          }
        },
        onError: (_) {
          if (!mounted || _hasCompleted) return;
          setState(() {
            _isListening = false;
            _hasError = true;
          });
        },
      );

      if (available && mounted) {
        _startListening();
      } else if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  void _startListening() {
    if (!_hasPermission) {
      _checkPermissionAndInit();
      return;
    }

    setState(() {
      _isListening = true;
      _hasError = false;
      _hasCompleted = false;
      _recognizedText = '';
      _soundLevel = 0.0;
    });

    _silenceTimer?.cancel();
    // 6.5s silence timeout triggers Retry State (Matching Screenshot 1)
    _silenceTimer = Timer(const Duration(milliseconds: 6500), () {
      if (mounted && _isListening && _recognizedText.isEmpty && !_hasCompleted) {
        _speech.stop();
        setState(() {
          _isListening = false;
          _hasError = true;
        });
      }
    });

    try {
      _speech.listen(
        onResult: (result) {
          if (!mounted || _hasCompleted) return;
          _silenceTimer?.cancel();
          setState(() {
            _recognizedText = result.recognizedWords;
          });

          if (result.finalResult && _recognizedText.trim().isNotEmpty) {
            _completeSearch(_recognizedText);
          }
        },
        onSoundLevelChange: _onSoundLevelChange,
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          partialResults: true,
          cancelOnError: false,
        ),
      );
    } catch (_) {
      setState(() {
        _isListening = false;
        _hasError = true;
      });
    }
  }

  void _onSoundLevelChange(double level) {
    if (!mounted || _hasCompleted) return;
    double norm;
    if (level > 0) {
      // Android: level usually 0 to 10+
      norm = (level / 10.0).clamp(0.0, 1.0);
    } else if (level < 0) {
      // iOS: decibels from -60 to 0
      norm = ((level + 50.0) / 50.0).clamp(0.0, 1.0);
    } else {
      norm = 0.0;
    }
    setState(() {
      _soundLevel = norm;
    });
  }

  void _completeSearch(String query) {
    if (_hasCompleted) return;
    final clean = query.trim();
    if (clean.isEmpty) return;

    _hasCompleted = true;
    _silenceTimer?.cancel();
    _speech.stop();
    HapticFeedback.mediumImpact();

    if (widget.onResult != null) {
      widget.onResult!(clean);
    }

    if (mounted) {
      Navigator.pop(context, clean);
    }
  }

  void _closeModal() {
    if (_hasCompleted) return;
    _hasCompleted = true;
    HapticFeedback.selectionClick();
    _silenceTimer?.cancel();
    _speech.stop();
    _slideController.reverse().then((_) {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        _hasCompleted = true;
        _silenceTimer?.cancel();
        _speech.stop();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // ── Dimmed Touch Backdrop (Tap anywhere to dismiss) ──────
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeModal,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),

            // ── Bottom Sheet with Floating Close 'X' Button ──────────
            // Sticks flush to the bottom edge of the screen (matching Screenshots)
            SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Floating Dark Close Button (Exact match to Screenshots)
                      GestureDetector(
                        onTap: _closeModal,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E3238),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. White Curved Bottom Sheet Container sticking flush to bottom
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: sheetBg,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.16),
                              blurRadius: 20,
                              offset: const Offset(0, -6),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.fromLTRB(
                          24,
                          28,
                          24,
                          20 + MediaQuery.of(context).padding.bottom,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          child: _hasError
                              ? _buildRetryContent(isDark)
                              : _buildListeningContent(isDark),
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

  // ── State 1: "Hi, I'm listening. Try saying..." & Mouth Waveform (Screenshots 2 & 3) ──
  Widget _buildListeningContent(bool isDark) {
    final bool isUserSpeaking = _recognizedText.isNotEmpty;

    return Column(
      key: const ValueKey('listening_state'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Subtitle prompt: "Listening..." when voice detected, else "Hi, I'm listening. Try saying..."
        Text(
          isUserSpeaking ? "Listening..." : "Hi, I'm listening. Try saying...",
          style: GoogleFonts.dmSans(
            fontSize: 16.0,
            fontWeight: FontWeight.w400,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),

        // Quoted text: Large bold text (matching Screenshots 2 & 3)
        SizedBox(
          height: 36,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.25),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Text(
                isUserSpeaking
                    ? '"$_recognizedText"'
                    : '"${_voiceSuggestions[_currentSuggestionIndex]}"',
                key: ValueKey<String>(
                  isUserSpeaking
                      ? 'rec_$_recognizedText'
                      : 'sug_$_currentSuggestionIndex',
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: 22.0,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF18181B),
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
        ),
        // Recognized Text Action Button (Tappable to immediately reach the search page)
        if (isUserSpeaking) ...[
          const SizedBox(height: 14),
          BouncingButton(
            onTap: () => _completeSearch(_recognizedText),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              decoration: BoxDecoration(
                color: isDark ? Colors.white : Colors.black,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _recognizedText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 15.0,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    CupertinoIcons.chevron_forward,
                    size: 16,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),

        // Black Circle with Mouth-Speaking Equalizer Waveform Bars
        BouncingButton(
          onTap: _startListening,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer soft glow halo
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, _) {
                  return Container(
                    width: 78 * _pulseAnimation.value,
                    height: 78 * _pulseAnimation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                    ),
                  );
                },
              ),

              // Signature Black Circle (User Request: use black color)
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white : Colors.black,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: _AnimatedWaveform(
                    animation: _waveAnimation,
                    soundLevel: _soundLevel,
                    barColor: isDark ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // ── State 2: "Sorry, I didn't get that. Try saying..." (Screenshot 1) ───
  Widget _buildRetryContent(bool isDark) {
    return Column(
      key: const ValueKey('retry_state'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // If text was detected while speaking, show it as an action button to reach the search page!
        if (_recognizedText.trim().isNotEmpty) ...[
          BouncingButton(
            onTap: () => _completeSearch(_recognizedText),
            child: Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white : Colors.black,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _recognizedText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    CupertinoIcons.chevron_forward,
                    size: 16,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],

        // "Sorry, I didn't get that. Try saying..."
        Text(
          "Sorry, I didn't get that. Try saying...",
          style: GoogleFonts.dmSans(
            fontSize: 16.0,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 18),

        // Horizontal row of suggestion pills (Matching Screenshot 1)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _retryChips.map((chip) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.5),
                child: _buildRetryChip(chip, isDark),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 28),

        // Black Microphone Button
        BouncingButton(
          onTap: _startListening,
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: isDark ? Colors.white : Colors.black,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.mic_rounded,
                color: isDark ? Colors.black : Colors.white,
                size: 30,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // "Tap microphone to try again"
        GestureDetector(
          onTap: _startListening,
          child: Text(
            "Tap microphone to try again",
            style: GoogleFonts.dmSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildRetryChip(String label, bool isDark) {
    return BouncingButton(
      onTap: () => _completeSearch(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8.5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            width: 1.1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }
}

// ── Animated Mouth-Speaking Waveform Bars (Graphic Equalizer) ────
class _AnimatedWaveform extends StatelessWidget {
  final Animation<double> animation;
  final double soundLevel;
  final Color? barColor;

  const _AnimatedWaveform({
    required this.animation,
    required this.soundLevel,
    this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = barColor ?? (Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value * 2 * pi;

        // Amplitude boost when user is speaking from their mouth
        final boost = 1.0 + 1.2 * soundLevel;

        // 5 vertical bars oscillating rhythmically with voice sound boost
        final h1 = (9.0 + 7.0 * (0.5 + 0.5 * sin(t))) * boost;
        final h2 = (14.0 + 10.0 * (0.5 + 0.5 * sin(t + 1.25))) * boost;
        final h3 = (20.0 + 14.0 * (0.5 + 0.5 * sin(t + 2.5))) * boost;
        final h4 = (14.0 + 10.0 * (0.5 + 0.5 * sin(t + 3.75))) * boost;
        final h5 = (9.0 + 7.0 * (0.5 + 0.5 * sin(t + 5.0))) * boost;

        final heights = [
          h1.clamp(6.0, 32.0),
          h2.clamp(8.0, 36.0),
          h3.clamp(12.0, 42.0),
          h4.clamp(8.0, 36.0),
          h5.clamp(6.0, 32.0),
        ];

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: heights.map((h) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.2),
              width: 3.5,
              height: h,
              decoration: BoxDecoration(
                color: effectiveColor,
                borderRadius: BorderRadius.circular(2.2),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
