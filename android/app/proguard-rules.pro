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

# flutter_local_notifications loads scheduled notifications through Gson.
# R8 strips the generic signature and cancel() then crashes with
# "Missing type parameter" inside loadScheduledNotifications.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-dontwarn com.google.gson.**

# Ignore warnings for missing Play Core classes (used by Flutter's deferred components feature, not active here)
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**