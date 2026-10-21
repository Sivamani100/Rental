import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/core/widgets/bouncing_button.dart';
import 'ad_config.dart';

/// Rotating high-value local real estate service sponsors for fallback & web.
class _SponsoredFeedItem {
  final String title;
  final String subtitle;
  final String ctaText;
  final IconData icon;
  final Color accentColor;

  const _SponsoredFeedItem({
    required this.title,
    required this.subtitle,
    required this.ctaText,
    required this.icon,
    required this.accentColor,
  });
}

const List<_SponsoredFeedItem> _sponsorVariants = [
  _SponsoredFeedItem(
    title: 'Pre-Approved Home Loans',
    subtitle: 'Lowest interest from 8.35% with zero processing fee for verified listings.',
    ctaText: 'Check Eligibility',
    icon: CupertinoIcons.money_dollar_circle_fill,
    accentColor: Color(0xFF10B981),
  ),
  _SponsoredFeedItem(
    title: 'Instant Packers & Movers',
    subtitle: 'Safe doorstep shifting with free insurance and 20% off for new renters.',
    ctaText: 'Get Free Quote',
    icon: CupertinoIcons.bus,
    accentColor: Color(0xFF3B82F6),
  ),
  _SponsoredFeedItem(
    title: 'Verified Zero Brokerage',
    subtitle: 'Connect directly with certified property owners without paying middlemen.',
    ctaText: 'Explore Direct',
    icon: Icons.verified_user_rounded,
    accentColor: Color(0xFFE5A900),
  ),
  _SponsoredFeedItem(
    title: 'Home Painting & Deep Clean',
    subtitle: 'Full sanitize & fresh paint before moving in. Guaranteed inspection ready.',
    ctaText: 'Book Service',
    icon: CupertinoIcons.sparkles,
    accentColor: Color(0xFF8B5CF6),
  ),
];

/// A premium, policy-compliant Native Ad card designed specifically
/// to integrate seamlessly into property feeds and grid views.
class InFeedGridAdCard extends StatefulWidget {
  final int slotIndex;

  const InFeedGridAdCard({
    super.key,
    this.slotIndex = 0,
  });

  @override
  State<InFeedGridAdCard> createState() => _InFeedGridAdCardState();
}

class _InFeedGridAdCardState extends State<InFeedGridAdCard> {
  NativeAd? _nativeAd;
  AdWidget? _adWidget;
  bool _adLoaded = false;
  bool _loadStarted = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (_loadStarted) return;
    _loadStarted = true;

    if (!adsEnabled || kIsWeb) return;

    final unitId = homeNativeAdUnitId;
    if (unitId == null) return;

    _nativeAd = NativeAd(
      adUnitId: unitId,
      factoryId: 'rentalSquareNative',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _nativeAd = ad as NativeAd;
            _adWidget = AdWidget(key: ObjectKey(ad), ad: ad);
            _adLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _nativeAd = null;
          _adWidget = null;
          if (mounted) setState(() => _adLoaded = false);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    _nativeAd = null;
    _adWidget = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!adsEnabled) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // If real AdMob native ad is ready on mobile, render it
    if (_adLoaded && _adWidget != null && !kIsWeb) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: _adWidget!,
        ),
      );
    }

    // High-fidelity sponsored native card fallback (Web, loading, or fallback)
    final sponsor = _sponsorVariants[widget.slotIndex % _sponsorVariants.length];

    return BouncingButton(
      onTap: () {
        HapticFeedback.lightImpact();
        _showSponsorModal(context, sponsor, isDark);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF222228),
                      const Color(0xFF18181D),
                    ]
                  : [
                      Colors.white,
                      const Color(0xFFF7F7FA),
                    ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF33333E)
                  : Colors.black.withValues(alpha: 0.08),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top row: "Ad" badge & Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryAccent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Ad',
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: sponsor.accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        sponsor.icon,
                        color: sponsor.accentColor,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),

              // Title and Subtitle
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sponsor.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    sponsor.subtitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white60 : Colors.black54,
                      height: 1.25,
                    ),
                  ),
                ],
              ),

              // CTA button at the bottom
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C35) : const Color(0xFFEDEDF2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      sponsor.ctaText,
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 11,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSponsorModal(BuildContext context, _SponsoredFeedItem sponsor, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 34),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardElevated : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryAccent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Sponsored Partner',
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(
                    CupertinoIcons.clear_circled_solid,
                    color: isDark ? Colors.white54 : Colors.black38,
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: sponsor.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Icon(sponsor.icon, color: sponsor.accentColor, size: 28),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sponsor.title,
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Verified ecosystem service',
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 12.5,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              sponsor.subtitle,
              style: TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 14,
                height: 1.4,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryAccent,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Opening ${sponsor.title}...'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Text(
                  sponsor.ctaText,
                  style: const TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
