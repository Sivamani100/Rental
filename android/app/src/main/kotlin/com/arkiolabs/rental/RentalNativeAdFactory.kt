package com.arkiolabs.rental

import android.content.Context
import android.view.LayoutInflater
import android.widget.Button
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.NativeAdFactory

/**
 * Native ad factory for the square layout (factoryId = "rentalSquareNative").
 *
 * Registered in [MainActivity.configureFlutterEngine] and unregistered in
 * [MainActivity.cleanUpFlutterEngine] to prevent memory leaks.
 *
 * Policy notes:
 *  - MediaView, headline, and call_to_action are all wired to [NativeAdView]
 *    so clicks are tracked correctly by the SDK.
 *  - AdChoices overlay is placed automatically by the SDK at top-right.
 *  - No custom click listeners are added on top of ad views.
 */
class RentalNativeAdFactory(private val context: Context) : NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val adView = LayoutInflater.from(context)
            .inflate(R.layout.native_ad_square, null) as NativeAdView

        // ── Mandatory: register views with NativeAdView ────────────────────
        val mediaView = adView.findViewById<MediaView>(R.id.ad_media)
        adView.mediaView = mediaView

        val headlineView = adView.findViewById<TextView>(R.id.ad_headline)
        adView.headlineView = headlineView
        headlineView.text = nativeAd.headline ?: ""

        val ctaView = adView.findViewById<Button>(R.id.ad_call_to_action)
        adView.callToActionView = ctaView
        ctaView.text = nativeAd.callToAction ?: "Learn More"
        ctaView.visibility = if (nativeAd.callToAction != null)
            android.view.View.VISIBLE else android.view.View.GONE

        // ── Optional but shown ────────────────────────────────────────────
        val bodyView = adView.findViewById<TextView>(R.id.ad_body)
        adView.bodyView = bodyView
        bodyView.text = nativeAd.body ?: ""

        // Bind the NativeAd object LAST (after all child views are set).
        adView.setNativeAd(nativeAd)
        return adView
    }
}
