import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:rental/app/theme/app_theme.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────
// SETTINGS SCREEN
// ─────────────────────────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _emailAlerts = false;
  bool _locationServices = true;

  Color _selectedLogoColor = AppTheme.primaryAccent;

  final List<Color> _availableColors = [
    const Color(0xFF1A1A1A),
    const Color(0xFF0A2342),
    const Color(0xFF5E0B15),
    const Color(0xFF0B421A),
    const Color(0xFF3B154D),
    const Color(0xFF5E2B0B),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = colorScheme.surface;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final borderColor = Theme.of(context).dividerColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Settings',
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.black, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [

          // ── Developer Profile ────────────────────────────────────
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => const _DeveloperProfileScreen(),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  // Developer Photo
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.transparent,
                    backgroundImage: AssetImage('assets/images/Developer.jpeg'),
                  ),
                  const SizedBox(width: 14),
                  // Developer Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sivamanikanta Mallipurapu',
                          style: TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Developer of the rental app',
                          style: TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── App Theme ─────────────────────────────────────────
          _buildSectionHeader('APP THEME'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 56,
                    height: 56,
                    color: _selectedLogoColor,
                    colorBlendMode: BlendMode.color,
                  ),
                ),
                const SizedBox(width: 16),
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
                                await FlutterDynamicIconPlus.setAlternateIconName(
                                  iconName: '.MainActivityColor$i',
                                );
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

          // ── Notifications ─────────────────────────────────────
          _buildSectionHeader('NOTIFICATIONS'),
          _buildTileGroup([
            _buildSwitchTile(
              icon: _iconBox(Colors.blue, CupertinoIcons.bell_fill),
              label: 'Push Notifications',
              value: _pushNotifications,
              onChanged: (val) => setState(() => _pushNotifications = val),
            ),
            _buildSwitchTile(
              icon: _iconBox(Colors.orange, CupertinoIcons.mail_solid),
              label: 'Email Alerts',
              value: _emailAlerts,
              onChanged: (val) => setState(() => _emailAlerts = val),
            ),
            _buildSwitchTile(
              icon: _iconBox(Colors.green, CupertinoIcons.location_solid),
              label: 'Location Services',
              value: _locationServices,
              onChanged: (val) => setState(() => _locationServices = val),
            ),
          ]),
          const SizedBox(height: 24),

          // ── Support & About ───────────────────────────────────
          _buildSectionHeader('SUPPORT & ABOUT'),
          _buildTileGroup([
            _buildNavTile(
              icon: _iconBox(Colors.purple, CupertinoIcons.question_circle_fill),
              label: 'Help Center',
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(context, CupertinoPageRoute(builder: (_) => const _HelpCenterScreen()));
              },
            ),
            _buildNavTile(
              icon: _iconBox(Colors.teal, CupertinoIcons.shield_fill),
              label: 'Privacy Policy',
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(context, CupertinoPageRoute(builder: (_) => const _PrivacyPolicyScreen()));
              },
            ),

            _buildNavTile(
              icon: _iconBox(const Color(0xFFFFCC00), CupertinoIcons.star_fill),
              label: 'Rate the App',
              onTap: () {
                HapticFeedback.selectionClick();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Thank you! Rating coming soon on the App Store.')),
                );
              },
            ),
          ]),

          // ── App version ───────────────────────────────────────
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32, top: 8),
              child: Text(
                'Rental v1.1.10  •  Made with ♥ in India',
                style: TextStyle(
                  fontFamily: 'ProximaNova',
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBox(Color bg, IconData icon) {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Icon(icon, color: Colors.white, size: 16),
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
  Widget _buildTileGroup(List<Widget> tiles) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: tiles.asMap().entries.map((entry) {
          final i = entry.key;
          final tile = entry.value;
          final isLast = i == tiles.length - 1;
          return Column(
            children: [
              tile,
              if (!isLast)
                Divider(height: 1, thickness: 1, indent: 56, color: Colors.grey.shade100),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSwitchTile({
    required Widget icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeColor: _selectedLogoColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'ProximaNova',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, size: 16, color: Color(0xFFC7C7CC)),
          ],
        ),
      ),
    );
  }
}

// DEVELOPER PROFILE SCREEN
// ─────────────────────────────────────────────────────────────
class _DeveloperProfileScreen extends StatelessWidget {
  const _DeveloperProfileScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F7F7);
    final cardBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF1A1A1A),
            leading: IconButton(
              icon: const Icon(CupertinoIcons.back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: const Color(0xFF1A1A1A),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    const CircleAvatar(
                      radius: 56,
                      backgroundColor: Colors.transparent,
                    backgroundImage: AssetImage('assets/images/Developer.jpeg'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Sivamanikanta Mallipurapu',
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Developer of the rental app',
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // About card
                  _infoCard(
                    cardBg: cardBg,
                    title: 'About Me',
                    icon: CupertinoIcons.person_fill,
                    iconColor: const Color(0xFF5856D6),
                    textColor: textColor,
                    content:
                        "I am a passionate developer who built this end-to-end rental ecosystem to simplify property discovery and management. I specialize in building scalable, modern, and user-centric mobile applications using Flutter. If you're interested in collaborating or learning more about my work, please feel free to reach out below.",
                  ),



                  const SizedBox(height: 16),

                  // Skills/Stack card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Iconsax.code, color: Colors.green, size: 16),
                            ),
                            const SizedBox(width: 10),
                            Text('Tech Stack', style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            )),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            'Flutter', 'Dart', 'Supabase', 'PostgreSQL',
                            'Firebase', 'REST APIs', 'Figma', 'Git',
                          ].map((tech) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryYellow.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.primaryYellow.withValues(alpha: 0.3)),
                            ),
                            child: Text(tech, style: const TextStyle(
                              fontFamily: 'ProximaNova',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryYellow,
                            )),
                          )).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text('Connect with Me', style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  )),
                  const SizedBox(height: 16),
                  _buildSocialLink(
                    context, 
                    title: 'LinkedIn', 
                    subtitle: 'linkedin.com/in/sivamanikanta-mallipurapu', 
                    url: 'https://linkedin.com/in/sivamanikanta-mallipurapu', 
                    icon: FontAwesomeIcons.linkedin, 
                    color: const Color(0xFF0077B5),
                    cardBg: cardBg,
                    textColor: textColor,
                  ),
                  _buildSocialLink(
                    context, 
                    title: 'Behance', 
                    subtitle: 'behance.net/mallipurapu', 
                    url: 'https://www.behance.net/mallipurapu', 
                    icon: FontAwesomeIcons.behance, 
                    color: const Color(0xFF1769FF),
                    cardBg: cardBg,
                    textColor: textColor,
                  ),
                  _buildSocialLink(
                    context, 
                    title: 'GitHub', 
                    subtitle: 'github.com/Sivamani100', 
                    url: 'https://github.com/Sivamani100', 
                    icon: FontAwesomeIcons.github, 
                    color: isDark ? Colors.white : Colors.black,
                    cardBg: cardBg,
                    textColor: textColor,
                  ),
                  _buildSocialLink(
                    context, 
                    title: 'Instagram', 
                    subtitle: '@the_only_one_siva', 
                    url: 'https://instagram.com/the_only_one_siva', 
                    icon: FontAwesomeIcons.instagram, 
                    color: const Color(0xFFE1306C),
                    cardBg: cardBg,
                    textColor: textColor,
                  ),
                  _buildSocialLink(
                    context, 
                    title: 'Email', 
                    subtitle: 'mallipurapusiva@gmail.com', 
                    url: 'mailto:mallipurapusiva@gmail.com', 
                    icon: FontAwesomeIcons.envelope, 
                    color: const Color(0xFFEA4335),
                    cardBg: cardBg,
                    textColor: textColor,
                  ),
                  _buildSocialLink(
                    context, 
                    title: 'WhatsApp', 
                    subtitle: '+91 9849497911', 
                    url: 'https://wa.me/919849497911', 
                    icon: FontAwesomeIcons.whatsapp, 
                    color: const Color(0xFF25D366),
                    cardBg: cardBg,
                    textColor: textColor,
                  ),
                  const SizedBox(height: 40),
Center(
                    child: Text(
                      'Built with passion in India 🇮🇳',
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  
  Widget _buildSocialLink(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String url,
    required dynamic icon,
    required Color color,
    required Color cardBg,
    required Color textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: ListTile(
        onTap: () async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: FaIcon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontFamily: 'ProximaNova',
            fontSize: 12,
            color: textColor.withValues(alpha: 0.7),
          ),
        ),
        trailing: Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.grey.shade400),
      ),
    );
  }

  Widget _infoCard({
    required Color cardBg,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color textColor,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textColor,
              )),
            ],
          ),
          const SizedBox(height: 12),
          Text(content, style: TextStyle(
            fontFamily: 'ProximaNova',
            fontSize: 13.5,
            height: 1.6,
            color: textColor.withValues(alpha: 0.75),
          )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HELP CENTER SCREEN
// ─────────────────────────────────────────────────────────────
class _HelpCenterScreen extends StatelessWidget {
  const _HelpCenterScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F7F7);
    final cardBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    final faqs = [
      ('How do I post a property?', 'Tap the + icon in the bottom navigation bar to open the posting screen. Fill in all required details and submit.'),
      ('How do I contact an owner?', 'Open any property listing and tap the Call or WhatsApp button on the property details page.'),
      ('Is the app free to use?', 'Yes! RentalEco is completely free for tenants. Property owners can list their properties at no charge.'),
      ('How do I save a property?', 'Tap the heart icon on any property card or inside the property detail page to save it to your list.'),
      ('Can I edit my listing?', 'Go to your profile, find your active listings, and tap the Edit button on any listing.'),
      ('How accurate is the location?', 'We use your device GPS and Google Maps geocoding for high accuracy. Make sure location permissions are enabled.'),
    ];

    return Scaffold(
      backgroundColor: bg,
      appBar: CupertinoNavigationBar(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        middle: const Text('Help Center'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Text('Frequently Asked Questions',
              style: TextStyle(fontFamily: 'DMSans', fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
          const SizedBox(height: 16),
          ...faqs.map((faq) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
            ),
            child: ExpansionTile(
              title: Text(faq.$1, style: TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              )),
              iconColor: AppTheme.primaryYellow,
              collapsedIconColor: Colors.grey,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(faq.$2, style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 13.5,
                    height: 1.6,
                    color: textColor.withValues(alpha: 0.7),
                  )),
                ),
              ],
            ),
          )),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryYellow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(CupertinoIcons.mail_solid, color: Colors.black),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Still need help?', style: TextStyle(
                        fontFamily: 'DMSans', fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black,
                      )),
                      Text('Contact us at support@rentaleco.in', style: TextStyle(
                        fontFamily: 'ProximaNova', fontSize: 12, color: Colors.black87,
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PRIVACY POLICY SCREEN
// ─────────────────────────────────────────────────────────────
class _PrivacyPolicyScreen extends StatelessWidget {
  const _PrivacyPolicyScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F7F7);
    final textColor = isDark ? Colors.white : Colors.black;

    const sections = [
      ('1. Data We Collect', 'We collect basic information such as your name, phone number, and location to provide our rental discovery services. We do not sell your personal data to third parties.'),
      ('2. Location Data', 'RentalEco uses your device location to show relevant nearby listings. Location access is optional and can be disabled at any time from your device settings.'),
      ('3. Property Listings', 'Property data submitted by owners is stored securely on our servers. Owners are responsible for the accuracy of information they provide.'),
      ('4. Cookies & Analytics', 'We use anonymized analytics to improve app performance and user experience. No personally identifiable data is shared with analytics providers.'),
      ('5. Data Security', 'We use industry-standard encryption (TLS/SSL) for all data transfers. Your credentials are securely stored using bcrypt hashing.'),
      ('6. Third-Party Services', 'RentalEco integrates with Google Maps, Supabase, and Razorpay for maps, storage, and payments respectively. Each service has its own privacy policy.'),
      ('7. Your Rights', 'You have the right to access, edit, or delete your personal data at any time by contacting us at privacy@rentaleco.in.'),
      ('8. Contact', 'For any privacy-related concerns, please reach out to us at:\nprivacy@rentaleco.in'),
    ];

    return Scaffold(
      backgroundColor: bg,
      appBar: CupertinoNavigationBar(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        middle: const Text('Privacy Policy'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Text('Privacy Policy',
              style: TextStyle(fontFamily: 'DMSans', fontSize: 22, fontWeight: FontWeight.w800, color: textColor)),
          const SizedBox(height: 4),
          Text('Last updated: September 2026',
              style: TextStyle(fontFamily: 'ProximaNova', fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 20),
          ...sections.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.$1, style: TextStyle(
                  fontFamily: 'DMSans', fontSize: 14, fontWeight: FontWeight.w700, color: textColor,
                )),
                const SizedBox(height: 6),
                Text(s.$2, style: TextStyle(
                  fontFamily: 'ProximaNova', fontSize: 13.5, height: 1.65,
                  color: textColor.withValues(alpha: 0.7),
                )),
              ],
            ),
          )),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

