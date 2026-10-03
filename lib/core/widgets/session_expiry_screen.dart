import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:rental/app/theme/app_theme.dart';

class SessionExpiryScreen extends StatelessWidget {
  final VoidCallback onLoginPressed;

  const SessionExpiryScreen({Key? key, required this.onLoginPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.lock_shield, size: 80, color: AppTheme.primaryAccent),
              SizedBox(height: 32),
              Text(
                "Session Expired",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                "Your session has been secured for your protection due to inactivity.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, color: CupertinoColors.secondaryLabel.resolveFrom(context), height: 1.4),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  borderRadius: BorderRadius.circular(14),
                  onPressed: onLoginPressed,
                  child: const Text("Log Back In", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
