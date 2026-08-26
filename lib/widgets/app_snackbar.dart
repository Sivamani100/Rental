import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

/// Global premium snackbar system.
///
/// A single, unified floating pill notification used across the entire app.
/// Features an icon on the left and a message beside it.
class AppSnackbar {
  AppSnackbar._();

  static const _successDuration = Duration(seconds: 2);
  static const _errorDuration = Duration(milliseconds: 3500);

  static const _bgColor = Color(0xFF1E1E1E);
  static const _pillRadius = 28.0;
  static const _logoSize = 22.0;
  static const _horizontalPadding = 20.0;
  static const _verticalPadding = 14.0;
  static const _logoTextGap = 14.0;

  static void success(BuildContext context, String message, {Duration duration = _successDuration}) {
    _display(context, message, duration, true);
  }

  static void error(BuildContext context, String message) {
    _display(context, message, _errorDuration, false);
  }

  static void _display(BuildContext context, String message, Duration duration, bool isSuccess) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: _PremiumSnackbarContent(message: message, isSuccess: isSuccess),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: 96,
        ),
        duration: duration,
        dismissDirection: DismissDirection.down,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_pillRadius),
        ),
      ),
    );
  }
}

class _PremiumSnackbarContent extends StatelessWidget {
  final String message;
  final bool isSuccess;

  const _PremiumSnackbarContent({required this.message, required this.isSuccess});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.80,
          minHeight: 52,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSnackbar._horizontalPadding,
            vertical: AppSnackbar._verticalPadding,
          ),
          decoration: BoxDecoration(
            color: AppSnackbar._bgColor,
            borderRadius: BorderRadius.circular(AppSnackbar._pillRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 6),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon (mimicking app logo / whatsapp style)
              Container(
                width: AppSnackbar._logoSize,
                height: AppSnackbar._logoSize,
                decoration: BoxDecoration(
                  color: isSuccess ? Colors.green : Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSuccess ? Iconsax.tick_circle : Iconsax.warning_2,
                  color: Colors.white,
                  size: 14,
                ),
              ),
              const SizedBox(width: AppSnackbar._logoTextGap),
              // Message text
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
