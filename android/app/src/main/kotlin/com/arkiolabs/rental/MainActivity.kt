package com.arkiolabs.rental

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterActivity() {

    /**
     * Register the square native ad factory so the Flutter plugin can call
     * our custom Kotlin-side layout when [factoryId] = "rentalSquareNative".
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "rentalSquareNative",
            RentalNativeAdFactory(this)
        )
    }

    /**
     * Unregister the factory to avoid memory leaks when the engine is torn down.
     */
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(
            flutterEngine,
            "rentalSquareNative"
        )
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
