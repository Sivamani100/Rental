import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_config.dart';

import 'package:rental/app/theme/app_theme.dart';

/// Displays a square (1:1) native image ad on the Property Detail page.
///
/// Behaviour:
///  - Loads once on first build; never reloads on rebuild.
///  - Shows a subtle shimmer placeholder while loading.
///  - On web or fallback, displays a high-fidelity native sponsored card.
///  - Disposes the [NativeAd] when removed from the tree.
class PropertyNativeAdWidget extends StatefulWidget {
  const PropertyNativeAdWidget({super.key});

  @override
  State<PropertyNativeAdWidget> createState() => _PropertyNativeAdWidgetState();
}

class _PropertyNativeAdWidgetState extends State<PropertyNativeAdWidget> {
  NativeAd? _nativeAd;
  AdWidget? _adWidget;

  /// true  = ad ready (real ad or web card)
  /// false = still loading (show shimmer)
  /// null  = collapsed
  bool? _adReady;

  bool _loadStarted = false;

  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  void _startLoad() {
    if (_loadStarted) return;
    _loadStarted = true;

    if (!adsEnabled) {
      if (mounted) setState(() => _adReady = null);
      return;
    }

    if (kIsWeb) {
      // On Web, AdMob mobile native plugin is unsupported.
      // Show responsive native sponsored card.
      if (mounted) setState(() => _adReady = true);
      return;
    }

    final unitId = propertyNativeAdUnitId;
    if (unitId == null) {
      if (mounted) setState(() => _adReady = true);
      return;
    }

    setState(() => _adReady = false); // show shimmer

    _nativeAd = NativeAd(
      adUnitId: unitId,
      factoryId: 'rentalSquareNative',
      request: const AdRequest(),
      nativeAdOptions: NativeAdOptions(
        mediaAspectRatio: MediaAspectRatio.any,
        adChoicesPlacement: AdChoicesPlacement.topRightCorner,
        videoOptions: VideoOptions(
          startMuted: true,
          customControlsRequested: false,
        ),
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (kDebugMode) debugPrint('[AdMob] Native ad loaded: ${ad.adUnitId}');
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _nativeAd = ad as NativeAd;
            _adWidget = AdWidget(
              key: ObjectKey(ad),
              ad: ad,
            );
            _adReady = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          if (kDebugMode) {
            debugPrint('[AdMob] Native ad failed: code=${error.code} message=${error.message}');
          }
          ad.dispose();
          _nativeAd = null;
          _adWidget = null;
          // Fall back to sponsored native ad card so ads are always visible when adsEnabled is true
          if (mounted) setState(() => _adReady = true);
        },
        onAdImpression: (ad) {
          if (kDebugMode) debugPrint('[AdMob] Native ad impression.');
        },
        onAdClicked: (ad) {
          if (kDebugMode) debugPrint('[AdMob] Native ad clicked.');
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
    if (_adReady == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_adReady == false) {
      return _AdShimmer(isDark: isDark);
    }

    if (kIsWeb || _nativeAd == null || _adWidget == null) {
      return _buildWebAdCard(isDark);
    }

    return _AdContainer(
      isDark: isDark,
      child: _adWidget!,
    );
  }

  Widget _buildWebAdCard(bool isDark) {
    return _AdContainer(
      isDark: isDark,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryYellow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.verified_rounded,
                      color: Color(0xFFE5A900),
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryYellow,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Ad',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Rental Verified Plus',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Direct owner listings with zero brokerage and verified security deposit safety.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: AppTheme.primaryYellow,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Explore Zero Brokerage Deals',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shimmer placeholder — maintains page layout while ad loads
// ---------------------------------------------------------------------------
class _AdShimmer extends StatefulWidget {
  final bool isDark;
  const _AdShimmer({required this.isDark});

  @override
  State<_AdShimmer> createState() => _AdShimmerState();
}

class _AdShimmerState extends State<_AdShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => _AdContainer(
        isDark: widget.isDark,
        child: Container(
          color: widget.isDark
              ? Color.lerp(const Color(0xFF2C2C2E), const Color(0xFF3A3A3C), _anim.value)!
              : Color.lerp(const Color(0xFFEEEEEE), const Color(0xFFF8F8F8), _anim.value)!,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared square container + "Ad" badge
// ---------------------------------------------------------------------------
class _AdContainer extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const _AdContainer({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // No divider here, just inheriting the gap from the previous section


        // Section Heading: "Advertisement" with "In-App Ads" badge on the right
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.campaign_rounded,
                  color: isDark ? const Color(0xFFFFD600) : const Color(0xFFFF9500),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Advertisement',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'In-App Ads',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Video / Image card
        AspectRatio(
          aspectRatio: 16 / 11, // A nice slightly rectangular proportion for video + text
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7), // Match app card surfaces
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            // The ad fills the container. No overlapping "Ad" badge needed since the section heading handles attribution cleanly.
            child: child,
          ),
        ),

        // Nice clean gap before the nearby transport section begins
        const SizedBox(height: 24),
      ],
    );
  }
}
