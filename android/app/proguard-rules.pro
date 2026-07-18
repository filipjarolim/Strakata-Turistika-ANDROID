# Keep Flutter classes and wrapper
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase & Google Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Cloudinary
-keep class com.cloudinary.** { *; }

# Local Auth
-keep class androidx.biometric.** { *; }

# Webview
-keep class android.webkit.** { *; }

# Keep App Models & Serialized names (prevent GSON/JSON reflection breakage)
-keep class cz.strakata.turistika.strakataturistikaandroidapp.models.** { *; }
-keep class cz.strakata.turistika.strakataturistikaandroidapp.services.** { *; }
-keep class cz.strakata.turistika.strakataturistikaandroidapp.repositories.** { *; }

# Ignore warnings for missing Play Core classes (used by Flutter's deferred components feature, not active here)
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**