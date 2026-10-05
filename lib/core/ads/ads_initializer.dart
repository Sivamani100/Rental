import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_config.dart';

/// Call once, after [WidgetsFlutterBinding.ensureInitialized].
/// Safe to call multiple times — guarded internally.
/// Non-blocking: the SDK initialises in the background, never delaying
/// the first frame.
class AdsInitializer {
  AdsInitializer._();

  static bool _done = false;

  static void init() {
    if (_done || !adsEnabled) return;
    _done = true;

    // Configure test devices BEFORE initializing the SDK.
    if (testDeviceIds.isNotEmpty) {
      MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: testDeviceIds),
      );
    }

    // Initialize asynchronously — never await in main() so the first frame
    // is not delayed.
    MobileAds.instance.initialize().then((status) {
      if (kDebugMode) {
        debugPrint('[AdMob] SDK initialized. Adapter statuses:');
        status.adapterStatuses.forEach((adapter, adapterStatus) {
          debugPrint('  $adapter: ${adapterStatus.state} '
              '— ${adapterStatus.description}');
        });
      }
    });
  }
}
