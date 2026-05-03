# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# RevenueCat
-keep class com.revenuecat.purchases.** { *; }
-keep class com.revenuecat.purchases.common.** { *; }
-keep class com.revenuecat.purchases.hybridcommon.** { *; }
-keep class com.revenuecat.purchases_flutter.** { *; }
-dontwarn com.revenuecat.purchases.**

# Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Image Picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# Share Plus
-keep class dev.fluttercommunity.plus.share.** { *; }

# URL Launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# App Links
-keep class com.llfbandit.app_links.** { *; }

# Shared Preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# SQLite / sqflite
-keep class com.tekartik.sqflite.** { *; }

# Keep generic metadata used by reflection / JSON
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
