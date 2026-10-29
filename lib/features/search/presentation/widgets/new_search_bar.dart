import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class NewSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool readOnly;
  final bool autofocus;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final VoidCallback? onVoiceTap;
  final String? staticHintText;
  final List<String>? customHints;
  final EdgeInsetsGeometry? margin;
  final double height;
  final double borderRadius;
  final bool showShadow;
  final bool showSearchIcon;

  const NewSearchBar({
    super.key,
    this.controller,
    this.focusNode,
    this.readOnly = false,
    this.autofocus = false,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.onVoiceTap,
    this.staticHintText,
    this.customHints,
    this.margin,
    this.height = 52.0,
    this.borderRadius = 16.0,
    this.showShadow = true,
    this.showSearchIcon = false,
  });

  @override
  State<NewSearchBar> createState() => _NewSearchBarState();
}

class _NewSearchBarState extends State<NewSearchBar>
    with SingleTickerProviderStateMixin {
  late final List<String> _hints;
  int _currentHintIndex = 0;
  Timer? _hintTimer;
  late final TextEditingController _internalController;
  bool _isInternalController = false;

  @override
  void initState() {
    super.initState();
    _hints = widget.customHints ??
        const [
          "Try 'Hostels in Diwancheruvu'",
          "Try '2 BHK Flat'",
          "Try 'Boys Hostel'",
          "Try 'Furnished Room'",
          "Try 'Villa on Appa Rao Road'",
          "Try 'Girls PG'",
          "Try 'AC Room in Rajahmundry'",
          "Try 'Single Room near RTC'",
        ];

    if (widget.controller == null) {
      _internalController = TextEditingController();
      _isInternalController = true;
    } else {
      _internalController = widget.controller!;
    }

    _internalController.addListener(_onTextChange);

    // Subtle cycling animation for placeholder hint every 2.6 seconds
    _hintTimer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (mounted && _internalController.text.isEmpty) {
        setState(() {
          _currentHintIndex = (_currentHintIndex + 1) % _hints.length;
        });
      }
    });
  }

  void _onTextChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _internalController.removeListener(_onTextChange);
    if (_isInternalController) {
      _internalController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasText = _internalController.text.isNotEmpty;

    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final hintColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final micColor = isDark ? Colors.white : const Color(0xFF18181B); // Black mic per user request

    return Container(
      margin: widget.margin ?? EdgeInsets.zero,
      height: widget.height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: widget.showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          onTap: widget.readOnly ? widget.onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Search Icon (Left, optional) ────────────────────────
                if (widget.showSearchIcon) ...[
                  Icon(
                    CupertinoIcons.search,
                    size: 20,
                    color: hintColor,
                  ),
                  const SizedBox(width: 10),
                ] else ...[
                  const SizedBox(width: 4),
                ],

                // ── Text Input / Animated Rotating Placeholder ──────────
                Expanded(
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Rotating animated hint (visible when empty)
                      if (!hasText)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) {
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.0, 0.4),
                                end: Offset.zero,
                              ).animate(animation),
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            widget.staticHintText ?? _hints[_currentHintIndex],
                            key: ValueKey<int>(_currentHintIndex),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w400,
                              color: hintColor,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),

                      // Actual TextField (clickable or editable)
                      TextField(
                        controller: _internalController,
                        focusNode: widget.focusNode,
                        readOnly: widget.readOnly,
                        autofocus: widget.autofocus,
                        onTap: widget.readOnly ? widget.onTap : null,
                        onChanged: widget.onChanged,
                        onSubmitted: widget.onSubmitted,
                        cursorColor: micColor,
                        cursorWidth: 1.8,
                        cursorHeight: 20,
                        style: GoogleFonts.dmSans(
                          fontSize: 15.0,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          letterSpacing: -0.2,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Clear 'X' Button (when text is typed, Screenshot 2 style) ──
                if (hasText && !widget.readOnly) ...[
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _internalController.clear();
                      if (widget.onClear != null) {
                        widget.onClear!();
                      } else if (widget.onChanged != null) {
                        widget.onChanged!('');
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],

                // ── Vertical Divider (|) ────────────────────────────────
                Container(
                  height: 20,
                  width: 1.0,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),

                // ── Black Microphone Icon ───────────────
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (widget.onVoiceTap != null) {
                      widget.onVoiceTap!();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 2, 8),
                    child: Icon(
                      Icons.mic_rounded,
                      size: 22,
                      color: micColor,
                    ),
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
