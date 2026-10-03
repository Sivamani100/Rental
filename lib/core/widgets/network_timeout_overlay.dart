import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:rental/app/theme/app_theme.dart';

class NetworkTimeoutOverlay extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onManualEntry;

  const NetworkTimeoutOverlay({
    Key? key,
    required this.onRetry,
    required this.onManualEntry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        color: CupertinoColors.systemBackground.resolveFrom(context).withOpacity(0.7),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 64, color: AppTheme.errorRed),
                const SizedBox(height: 24),
                const Text(
                  "Connection timed out",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  "We couldn't reach the servers or locate you in time. Please check your connection.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: onRetry,
                    child: Text("Retry Connection", style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    onPressed: onManualEntry,
                    child: Text("Enter Location Manually", style: TextStyle(color: AppTheme.primaryAccent)),
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
