import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:iconsax/iconsax.dart';
import '../theme/app_theme.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';
import 'package:flutter/services.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Appearance state
  bool _pushNotifications = true;
  bool _emailAlerts = false;
  bool _locationServices = true;

  // Logo color state
  Color _selectedLogoColor = const Color(0xFF0067FF); // Default Blue

  final List<Color> _availableColors = [
    const Color(0xFF1A1A1A), // Pure Dark / Black
    const Color(0xFF0A2342), // Deep Navy Blue
    const Color(0xFF5E0B15), // Deep Crimson
    const Color(0xFF0B421A), // Deep Forest Green
    const Color(0xFF3B154D), // Deep Purple
    const Color(0xFF5E2B0B), // Deep Brown/Orange
  ];

  @override
  Widget build(BuildContext context) {
    // Force light mode colors for a clean look
    const backgroundColor = Color(0xFFF2F2F7);
    const cardColor = Colors.white;
    const textColor = Color(0xFF1C1C1E);
    const borderColor = Color(0xFFE5E5EA);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: textColor, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          // ── App Branding Section ──────────────────────────────
          _buildSectionHeader('APP THEME'),
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Display Logo
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/logo.png',
                    width: 56,
                    height: 56,
                    color: _selectedLogoColor,
                    colorBlendMode: BlendMode.color,
                  ),
                ),
                const SizedBox(width: 16),
                // Color Picker
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _availableColors.asMap().entries.map((entry) {
                        final i = entry.key;
                        final color = entry.value;
                        final isSelected = _selectedLogoColor == color;
                        return GestureDetector(
                          onTap: () async {
                            setState(() => _selectedLogoColor = color);
                            try {
                              if (await FlutterDynamicIconPlus.supportsAlternateIcons) {
                                await FlutterDynamicIconPlus.setAlternateIconName('.MainActivityColor$i');
                              }
                            } on PlatformException catch (e) {
                              debugPrint("Failed to change app icon: ${e.message}");
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 12),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? textColor : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white, size: 16)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Notifications Section ─────────────────────────────
          _buildSectionHeader('NOTIFICATIONS'),
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                _buildSwitchRow('Push Notifications', Iconsax.notification, _pushNotifications, (val) => setState(() => _pushNotifications = val), Colors.blue),
                _buildDivider(),
                _buildSwitchRow('Email Alerts', Iconsax.sms, _emailAlerts, (val) => setState(() => _emailAlerts = val), Colors.orange),
                _buildDivider(),
                _buildSwitchRow('Location Services', Iconsax.location, _locationServices, (val) => setState(() => _locationServices = val), Colors.green, isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Support Section ───────────────────────────────────
          _buildSectionHeader('SUPPORT & ABOUT'),
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                _buildLinkRow('Help Center', Iconsax.message_question, Colors.purple),
                _buildDivider(),
                _buildLinkRow('Privacy Policy', Iconsax.shield_tick, Colors.teal),
                _buildDivider(),
                _buildLinkRow('About Rental App', Iconsax.info_circle, Colors.indigo, isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'ProximaNova',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF8E8E93),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 48),
      child: Divider(height: 1, thickness: 1, color: Color(0xFFE5E5EA)),
    );
  }

  Widget _buildSwitchRow(String title, IconData icon, bool value, ValueChanged<bool> onChanged, Color iconBgColor, {bool isLast = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1C1C1E),
              ),
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: CupertinoSwitch(
              value: value,
              activeColor: _selectedLogoColor,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkRow(String title, IconData icon, Color iconBgColor, {bool isLast = false}) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'ProximaNova',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1C1C1E),
                ),
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, color: Color(0xFFC7C7CC), size: 18),
          ],
        ),
      ),
    );
  }
}
