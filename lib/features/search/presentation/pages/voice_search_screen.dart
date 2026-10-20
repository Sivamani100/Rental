import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rental/app/theme/app_theme.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:rental/features/search/presentation/pages/unified_search_screen.dart';
import 'package:rental/core/models/property_model.dart';
import 'package:rental/core/widgets/bouncing_button.dart';

class VoiceSearchScreen extends StatefulWidget {
  final List<PropertyModel>? properties;

  const VoiceSearchScreen({
    super.key,
    this.properties,
  });

  @override
  State<VoiceSearchScreen> createState() => _VoiceSearchScreenState();
}

class _VoiceSearchScreenState extends State<VoiceSearchScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;
  
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isInitializing = true;
  bool _hasPermission = true;
  String _recognizedText = '';
  String _statusMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _waveAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );
    
    _checkPermissionAndInit();
  }

  Future<void> _checkPermissionAndInit() async {
    final status = await Permission.microphone.status;
    
    if (!status.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        if (mounted) {
          setState(() {
            _hasPermission = false;
            _isInitializing = false;
            _statusMessage = 'Microphone permission denied';
          });
        }
        return;
      }
    }
    
    _initSpeech();
  }

  void _initSpeech() async {
    try {
      bool available = await _speech.initialize(
        onStatus: (val) {
          debugPrint('Speech status: $val');
          if (mounted) {
            setState(() {
              _isInitializing = false;
              if (val == 'listening') {
                _isListening = true;
                _statusMessage = 'Listening...';
                _pulseController.repeat(reverse: true);
              } else if (val == 'done' || val == 'notListening') {
                _isListening = false;
                _statusMessage = _recognizedText.isNotEmpty ? 'Done!' : 'Tap to try again';
                _pulseController.stop();
                _pulseController.reset();
              } else if (val == 'idle') {
                _isListening = false;
                _statusMessage = 'Tap to speak';
                _pulseController.stop();
                _pulseController.reset();
              }
            });
          }
        },
        onError: (val) {
          debugPrint('Speech error: $val');
          if (mounted) {
            setState(() {
              _isListening = false;
              _isInitializing = false;
              _statusMessage = 'Error: ${val.errorMsg ?? 'Could not recognize speech'}';
              _pulseController.stop();
              _pulseController.reset();
            });
          }
        },
      );
      
      if (available && mounted) {
        setState(() {
          _isInitializing = false;
          _statusMessage = 'Tap to speak';
        });
        
        // Auto-start listening every time the screen opens
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isListening) {
            _startListening();
          }
        });
      } else {
        if (mounted) {
          setState(() {
            _isInitializing = false;
            _statusMessage = 'Speech recognition not available';
          });
        }
      }
    } catch (e) {
      debugPrint('Speech init error: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _statusMessage = 'Failed to initialize speech';
        });
      }
    }
  }

  void _startListening() {
    if (!_hasPermission) {
      _checkPermissionAndInit();
      return;
    }
    
    if (_isListening) {
      _speech.stop();
      return;
    }
    
    setState(() => _statusMessage = 'Listening...');
    _speech.listen(
      onResult: (val) {
        if (mounted) {
          setState(() {
            _recognizedText = val.recognizedWords;
            if (val.finalResult) {
              _statusMessage = 'Done!';
            }
          });
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      localeId: 'en_IN',
      cancelOnError: false,
      listenMode: stt.ListenMode.confirmation,
      onSoundLevelChange: (val) {
        // Could use this for visual feedback
      },
    );
  }

  @override
  void dispose() {
    _speech.stop();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final mutedColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Subtle gradient background
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [
                            const Color(0xFF121212),
                            const Color(0xFF1E1E1E),
                          ]
                        : [
                            Colors.white,
                            const Color(0xFFFAFAFA),
                          ],
                  ),
                ),
              ),
            ),
            
            // Close button
            Positioned(
              top: 16,
              right: 16,
              child: BouncingButton(
                onTap: () {
                  _speech.stop();
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.03),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(CupertinoIcons.clear, color: textColor, size: 20),
                  ),
                ),
              ),
            ),
            
            Column(
              children: [
                const Spacer(flex: 2),
                
                // Recognition text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _recognizedText.isNotEmpty ? _recognizedText : _statusMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: _recognizedText.isNotEmpty ? 26 : 20,
                      color: _recognizedText.isNotEmpty 
                          ? textColor 
                          : mutedColor,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Helper text
                if (_recognizedText.isEmpty && _isListening)
                  Text(
                    "Try saying '2 BHK flats in Hyderabad'",
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 14,
                      color: mutedColor.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                
                const Spacer(flex: 4),
                
                // Animated mic button at bottom
                Center(
                  child: BouncingButton(
                    onTap: _isInitializing ? null : _startListening,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_pulseAnimation, _waveAnimation]),
                      builder: (context, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer pulsing rings (subtle)
                            if (_isListening)
                              ...List.generate(2, (index) {
                                return AnimatedBuilder(
                                  animation: _waveAnimation,
                                  builder: (context, _) {
                                    return Transform.scale(
                                      scale: _waveAnimation.value * (1 + index * 0.15),
                                      child: Container(
                                        width: 100 + (index * 20),
                                        height: 100 + (index * 20),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }),
                            
                            // Main circle
                            Transform.scale(
                              scale: _isListening ? _pulseAnimation.value : 1.0,
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                                  border: Border.all(
                                    color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.08),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    _isInitializing
                                        ? CupertinoIcons.ellipsis
                                        : _isListening
                                            ? CupertinoIcons.mic_fill
                                            : CupertinoIcons.mic,
                                    color: isDark ? AppTheme.primaryYellow : Colors.black,
                                    size: 44,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Bottom action buttons (when recognized text exists)
                if (_recognizedText.isNotEmpty && !_isListening)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Search button (primary)
                        BouncingButton(
                          onTap: () {
                            Navigator.pop(context);
                            if (mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UnifiedSearchScreen(
                                    initialQuery: _recognizedText,
                                    initialProperties: widget.properties,
                                  ),
                                ),
                              );
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.primaryYellow : Colors.black,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.search,
                                  color: isDark ? Colors.black : Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Search for "${_recognizedText.length > 5 ? _recognizedText.substring(0, 5) + '...' : _recognizedText}"',
                                  style: TextStyle(
                                    fontFamily: 'ProximaNova',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.black : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Try again button (secondary)
                        BouncingButton(
                          onTap: () {
                            setState(() {
                              _recognizedText = '';
                              _statusMessage = 'Tap to speak';
                            });
                            Future.delayed(const Duration(milliseconds: 300), () {
                              if (mounted && !_isListening) {
                                _startListening();
                              }
                            });
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.refresh,
                                  color: isDark ? AppTheme.primaryYellow : Colors.black,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Try again',
                                  style: TextStyle(
                                    fontFamily: 'ProximaNova',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
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
                
                // Permission denied message
                if (!_hasPermission)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        Icon(
                          CupertinoIcons.mic_slash_fill,
                          color: Colors.red.shade400,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Microphone Permission Required',
                          style: TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please enable microphone access in settings to use voice search',
                          style: TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 12,
                            color: mutedColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        BouncingButton(
                          onTap: () {
                            openAppSettings();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.primaryYellow : Colors.black,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Open Settings',
                              style: TextStyle(
                                fontFamily: 'ProximaNova',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
