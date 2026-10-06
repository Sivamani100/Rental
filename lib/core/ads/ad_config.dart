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

/// Official Google test native ad unit ID (Advanced Video).
const String _testNativeUnitId = 'ca-app-pub-3940256099942544/1044960115';

/// Placeholder for your real native ad unit ID.
/// Release builds check for this sentinel and skip loading if it is still set.
const String _realNativeUnitId = 'REPLACE_ME';

/// Returns the correct native ad unit ID for the current build mode.
/// In release mode, returns null if the real ID has not been filled in yet
/// (preventing a broken ad slot in production).
String? get nativeAdUnitId {
  if (!adsEnabled) return null;

  if (kReleaseMode) {
    if (_realNativeUnitId == 'REPLACE_ME') {
      // Real ID not set yet — skip loading to avoid empty/broken ads in prod.
      return null;
    }
    return _realNativeUnitId;
  }

  // Debug / profile mode — always use the test ID.
  return _testNativeUnitId;
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
