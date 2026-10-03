import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:rental/app/theme/app_theme.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceSearchScreen extends StatefulWidget {
  const VoiceSearchScreen({super.key});

  @override
  State<VoiceSearchScreen> createState() => _VoiceSearchScreenState();
}

class _VoiceSearchScreenState extends State<VoiceSearchScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _recognizedText = '';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _initSpeech();
  }

  void _initSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (val) {
        if (val == 'done' || val == 'notListening') {
          if (mounted) setState(() => _isListening = false);
          _pulseController.stop();
          if (_recognizedText.isNotEmpty && mounted) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) Navigator.pop(context, _recognizedText);
            });
          }
        }
      },
      onError: (val) {
        if (mounted) setState(() => _isListening = false);
        _pulseController.stop();
      },
    );
    if (available && mounted) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (val) {
          if (mounted) {
            setState(() {
              _recognizedText = val.recognizedWords;
            });
          }
        },
      );
    } else {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF000000); 

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(CupertinoIcons.clear, color: Colors.white, size: 28),
                onPressed: () {
                  _speech.stop();
                  Navigator.pop(context);
                },
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _recognizedText.isNotEmpty ? _recognizedText : 'Listening...',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 28,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Try saying 'Buy Houses in Hyderabad'",
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(flex: 3),
                Center(
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isListening ? _pulseAnimation.value : 1.0,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryYellow.withValues(alpha: 0.2),
                          ),
                          child: Center(
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.primaryYellow,
                              ),
                              child: Icon(
                                _isListening ? CupertinoIcons.mic_fill : CupertinoIcons.mic_off,
                                color: Colors.black,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
