# Flutter rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Disable aggressive R8 bytecode optimization to ensure reflection/Room stability
-dontoptimize

# WorkManager & Room Database (CRITICAL: Fixes crash "Failed to create an instance of androidx.work.impl.WorkDatabase")
-keep class androidx.work.** { *; }
-keep class androidx.work.impl.** { *; }
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keepclassmembers class androidx.work.impl.WorkDatabase_Impl {
    <init>(...);
    *;
}
-keep class * extends androidx.room.RoomDatabase {
    <init>(...);
    *;
}
-keepclassmembers class * extends androidx.room.RoomDatabase {
    <init>(...);
    *;
}
-keep class * extends androidx.work.InputMerger {
    <init>(...);
    *;
}
-dontwarn androidx.work.**
-dontwarn androidx.room.**

# AndroidX Startup / InitializationProvider
-keep class androidx.startup.** { *; }
-dontwarn androidx.startup.**

# Play Core (In-App Updates & In-App Reviews)
-keep class com.google.android.play.core.appupdate.** { *; }
-keep class com.google.android.play.core.review.** { *; }
-keep class com.google.android.play.core.install.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-keep class com.google.android.play.core.common.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-dontwarn com.google.android.play.core.**

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# Keep MainActivity and Custom Native Ad Factory
-keep class com.arkiolabs.rental.** { *; }

# Google Mobile Ads
-keep public class com.google.android.gms.ads.** { *; }
-keep public class com.google.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Firebase Messaging & Core
-keepattributes *Annotation*
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# uCrop
-dontwarn com.yalantis.ucrop**
-keep class com.yalantis.ucrop** { *; }
-keep interface com.yalantis.ucrop** { *; }
