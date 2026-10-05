import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_config.dart';

/// Displays a square (1:1) native image ad on the Property Detail page.
///
/// Behaviour:
///  - Loads once on first build; never reloads on rebuild.
///  - Shows a subtle shimmer placeholder while loading.
///  - Collapses completely (zero height) on load failure or when ads are off.
///  - Disposes the [NativeAd] when removed from the tree.
class PropertyNativeAdWidget extends StatefulWidget {
  const PropertyNativeAdWidget({super.key});

  @override
  State<PropertyNativeAdWidget> createState() => _PropertyNativeAdWidgetState();
}

class _PropertyNativeAdWidgetState extends State<PropertyNativeAdWidget> {
  NativeAd? _nativeAd;

  /// true  = ad loaded and ready to show
  /// false = still loading (show shimmer)
  /// null  = collapsed (failed or disabled)
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

    final unitId = nativeAdUnitId;
    if (unitId == null) {
      // Ads disabled or real ID not set — stay collapsed.
      return;
    }

    setState(() => _adReady = false); // show shimmer

    _nativeAd = NativeAd(
      adUnitId: unitId,
      // factoryId must match the id registered in MainActivity.kt
      factoryId: 'rentalSquareNative',
      request: const AdRequest(),
      nativeAdOptions: NativeAdOptions(
        mediaAspectRatio: MediaAspectRatio.landscape, // Better for videos
        adChoicesPlacement: AdChoicesPlacement.topRightCorner,
        videoOptions: VideoOptions(
          startMuted: true,
          customControlsRequested: true,
        ),
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (kDebugMode) debugPrint('[AdMob] Native ad loaded: ${ad.adUnitId}');
          if (mounted) setState(() => _adReady = true);
        },
        onAdFailedToLoad: (ad, error) {
          if (kDebugMode) {
            debugPrint('[AdMob] Native ad failed: code=${error.code} '
                'message=${error.message}');
          }
          ad.dispose();
          _nativeAd = null;
          // Collapse the slot — do NOT retry in a loop.
          if (mounted) setState(() => _adReady = null);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Collapsed: failed, disabled, or not yet triggered
    if (_adReady == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // While loading — square shimmer placeholder so the page does not jump
    if (_adReady == false) {
      return _AdShimmer(isDark: isDark);
    }

    // Ad is ready — render in a square container
    return _AdContainer(
      isDark: isDark,
      child: AdWidget(ad: _nativeAd!),
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
