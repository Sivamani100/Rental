import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:rental/app/theme/app_theme.dart';

class NotFoundPage extends StatelessWidget {
  final VoidCallback onReturnHome;

  const NotFoundPage({Key? key, required this.onReturnHome}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CupertinoNavigationBar(
        border: null,
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.question_circle, size: 100, color: AppTheme.lightBorder),
              const SizedBox(height: 32),
              const Text(
                "Looks like you're lost",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                "The page or item you are looking for does not exist or has been removed.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
              ),
              const SizedBox(height: 40),
              CupertinoButton(
                color: AppTheme.primaryDark,
                borderRadius: BorderRadius.circular(24),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                onPressed: onReturnHome,
                child: const Text("Return to Home", style: TextStyle(fontWeight: FontWeight.w600)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
