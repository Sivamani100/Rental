import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/core/widgets/bouncing_button.dart';
import 'ad_config.dart';

/// A custom-styled, policy-compliant Banner Ad Card designed specifically for
/// the Property Details page, positioned right after the Monthly Rent card.
class PropertyBannerAdCard extends StatefulWidget {
  const PropertyBannerAdCard({super.key});

  @override
  State<PropertyBannerAdCard> createState() => _PropertyBannerAdCardState();
}

class _PropertyBannerAdCardState extends State<PropertyBannerAdCard> {
  BannerAd? _bannerAd;
  AdWidget? _adWidget;
  bool _adLoaded = false;
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadBanner();
  }

  Future<void> _loadBanner() async {
    if (_loadStarted) return;
    _loadStarted = true;

    if (!adsEnabled || kIsWeb) return;

    final unitId = bannerAdUnitId;
    if (unitId == null) return;

    // Available width on screen (20dp padding on each side of the screen)
    final screenWidth = MediaQuery.sizeOf(context).width;
    final targetWidth = (screenWidth - 40).truncate().clamp(300, 728);

    // Request a sleek Anchored Adaptive Banner size matching device width (reduced sleek height: ~50-60dp)
    AdSize adSize = AdSize.banner;
    try {
      // ignore: deprecated_member_use
      final adaptiveSize =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(targetWidth);
      if (adaptiveSize != null) {
        adSize = adaptiveSize;
      }
    } catch (e) {
      debugPrint('[PropertyBannerAd] Error getting adaptive size: $e');
    }

    if (!mounted) return;

    debugPrint(
        '[PropertyBannerAd] Loading banner ad with size: ${adSize.width}x${adSize.height} for target width: $targetWidth with unit ID: $unitId');

    _bannerAd = BannerAd(
      adUnitId: unitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          final banner = ad as BannerAd;
          debugPrint(
              '[PropertyBannerAd] Google Test Banner loaded successfully! (${banner.size.width}x${banner.size.height})');
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = banner;
            _adWidget = AdWidget(
              key: ObjectKey(banner),
              ad: banner,
            );
            _adLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
              '[PropertyBannerAd] Failed to load banner: ${error.message} (code: ${error.code})');
          ad.dispose();
          _bannerAd = null;
          _adWidget = null;
          if (mounted) setState(() => _adLoaded = false);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _adWidget = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!adsEnabled) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section Header styled like "Room & Occupancy Details"
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryYellow.withValues(alpha: isDark ? 0.15 : 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    CupertinoIcons.sparkles,
                    size: 16,
                    color: isDark ? AppTheme.primaryYellow : Colors.black,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Sponsored',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: AppTheme.primaryAccent,
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text(
                'Ad',
                style: TextStyle(
                  fontFamily: 'ProximaNova',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Banner Ad Card Container (clean 18dp rounded frame without excessive whitespace)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : const Color(0xFFFAFAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
              width: 1.2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: (_adLoaded && _adWidget != null && !kIsWeb)
              ? Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: _bannerAd?.size.width.toDouble() ?? 320,
                      height: _bannerAd?.size.height.toDouble() ?? 50,
                      child: _adWidget!,
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(10),
                  child: _buildSponsoredFallback(isDark),
                ),
        ),
      ],
    );
  }

  Widget _buildSponsoredFallback(bool isDark) {
    return BouncingButton(
      onTap: () {
        HapticFeedback.lightImpact();
        _showPartnerOfferModal(context, isDark);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF222228) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.25 : 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(
                  CupertinoIcons.money_dollar_circle_fill,
                  color: Color(0xFF10B981),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instant Home Loan & Deposit Advance',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Low interest from 8.35% • Paperless 10-min approval',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Apply',
                style: TextStyle(
                  fontFamily: 'ProximaNova',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPartnerOfferModal(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
            Text(
              'Pre-Approved Home Loan & Rent Deposit Advance',
              style: TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Need deposit assistance for this property? Get instant pre-approval from top partner banks with zero processing fees and flexible tenure.',
              style: TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 13.5,
                height: 1.4,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
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
                    const SnackBar(
                      content: Text('Checking loan & deposit eligibility...'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text(
                  'Check Eligibility Online',
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 14.5,
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
