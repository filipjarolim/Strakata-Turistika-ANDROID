import 'package:flutter_dotenv/flutter_dotenv.dart';

// Google OAuth Configuration
// WEB client = NextAuth / serverClientId (ID tokens) — project auth-model-415313
// iOS client = native Google Sign-In on iPhone (required; web client cannot use custom schemes)
// Android OAuth clients live in Firebase project strakata-turistika (package + SHA-1).
// Passing the NextAuth web client as serverClientId on Android causes ApiException 10.

class GoogleAuthConfig {
  /// Web application OAuth client (Next.js / iOS serverClientId).
  static String get clientId => dotenv.env['GOOGLE_CLIENT_ID']?.trim() ?? '';

  /// Optional Web client from the SAME GCP project as the Android OAuth client
  /// (Firebase `strakata-turistika`). If empty, Android Sign-In skips requestIdToken.
  static String get androidServerClientId =>
      dotenv.env['GOOGLE_ANDROID_SERVER_CLIENT_ID']?.trim() ?? '';

  static String get clientSecret =>
      dotenv.env['GOOGLE_CLIENT_SECRET']?.trim() ?? '';

  /// iOS OAuth client from Google Cloud Console (type: iOS).
  static String get iosClientId =>
      dotenv.env['GOOGLE_IOS_CLIENT_ID']?.trim() ?? '';

  static const List<String> scopes = ['email', 'profile'];

  static bool get isConfigured => clientId.isNotEmpty;

  static bool get isIosConfigured => iosClientId.isNotEmpty;

  /// Reversed iOS client ID for CFBundleURLSchemes, e.g.
  /// `com.googleusercontent.apps.123-abc`
  static String get iosReversedClientId {
    final id = iosClientId;
    const suffix = '.apps.googleusercontent.com';
    if (!id.endsWith(suffix)) return '';
    final prefix = id.substring(0, id.length - suffix.length);
    return 'com.googleusercontent.apps.$prefix';
  }
}
