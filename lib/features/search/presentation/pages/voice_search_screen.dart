import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:rental/app/theme/app_theme.dart';

class VoiceSearchScreen extends StatefulWidget {
  const VoiceSearchScreen({super.key});

  @override
  State<VoiceSearchScreen> createState() => _VoiceSearchScreenState();
}

class _VoiceSearchScreenState extends State<VoiceSearchScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pure black background for that sleek look
    const bgColor = Color(0xFF000000); 

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Close Button
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(CupertinoIcons.clear, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // Content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                
                // Listening Text
                const Text(
                  'Listening...',
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Suggestion text
                Text(
                  "Try saying 'Buy Houses in Hyderabad'",
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                const Spacer(flex: 3),
                
                // Pulsing Mic Button
                Center(
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
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
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.primaryYellow,
                              ),
                              child: const Icon(
                                CupertinoIcons.mic_fill,
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
