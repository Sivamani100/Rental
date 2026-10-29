// =============================================================================
// AD CONFIG — SINGLE SOURCE OF TRUTH
// =============================================================================
// To disable ALL ads instantly: set adsEnabled = false.
// To switch to real ads: replace every "REPLACE_ME" placeholder with the real
// ID from your AdMob dashboard (see "SWITCH TO REAL ADS LATER" in the guide).
// =============================================================================

import 'package:flutter/foundation.dart';

/// Kill-switch: set to false to hide every ad slot across the whole app.
const bool adsEnabled = false;

// ---------------------------------------------------------------------------
// Native Ad Unit IDs
// ---------------------------------------------------------------------------

/// Official Google test native ad unit ID (Native Advanced).
const String _testNativeUnitId = 'ca-app-pub-3940256099942544/2247696110';

/// Real Native Ad Unit ID for Home Page feed grid (InFeedGridAdCard).
const String _realHomeNativeUnitId = 'ca-app-pub-3326150138582962/1421267490';

/// Real Native Ad Unit ID for Property Details page (PropertyNativeAdWidget).
const String _realPropertyNativeUnitId = 'ca-app-pub-3326150138582962/1941280317';

/// Returns the native ad unit ID for Home Page feed.
String? get homeNativeAdUnitId {
  if (!adsEnabled) return null;

  if (_realHomeNativeUnitId != 'REPLACE_ME' && _realHomeNativeUnitId.isNotEmpty) {
    return _realHomeNativeUnitId;
  }
  return _testNativeUnitId;
}

/// Returns the native ad unit ID for Property Details page.
String? get propertyNativeAdUnitId {
  if (!adsEnabled) return null;

  if (_realPropertyNativeUnitId != 'REPLACE_ME' && _realPropertyNativeUnitId.isNotEmpty) {
    return _realPropertyNativeUnitId;
  }
  return _testNativeUnitId;
}

/// Backward compatibility getter
String? get nativeAdUnitId => homeNativeAdUnitId;

// ---------------------------------------------------------------------------
// Banner Ad Unit IDs
// ---------------------------------------------------------------------------

/// Official Google test banner unit IDs (Standard Banner 320x50 / Adaptive).
const String _testBannerUnitIdAndroid = 'ca-app-pub-3940256099942544/6300978111';
const String _testBannerUnitIdIOS = 'ca-app-pub-3940256099942544/2934735716';

/// Real Banner Ad Unit ID for Property Details banner (PropertyBannerAdCard).
const String _realBannerUnitId = 'ca-app-pub-3326150138582962/8864643243';

/// Returns the banner ad unit ID.
String? get bannerAdUnitId {
  if (!adsEnabled) return null;

  if (_realBannerUnitId != 'REPLACE_ME' && _realBannerUnitId.isNotEmpty) {
    return _realBannerUnitId;
  }

  // Official Google Test Banner Ad Unit ID
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return _testBannerUnitIdIOS;
  }
  return _testBannerUnitIdAndroid;
}

// ---------------------------------------------------------------------------
// Test Device Configuration
// ---------------------------------------------------------------------------

/// Add your physical device hash here so test ads appear on real hardware.
/// How to find your hash: run the app once in debug mode, then grep logcat for:
///   "Use RequestConfiguration.Builder().setTestDeviceIds(..."
/// Example: ['ABCDE12345ABCDE12345ABCDE12345AB']
///
// TODO: Add your device hash from logcat output here.
const List<String> testDeviceIds = [
  // 'YOUR_DEVICE_HASH_FROM_LOGCAT',
];
