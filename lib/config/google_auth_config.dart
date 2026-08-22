import 'package:flutter_dotenv/flutter_dotenv.dart';

// Google OAuth Configuration
// WEB client = NextAuth / serverClientId (ID tokens)
// iOS client = native Google Sign-In on iPhone (required; web client cannot use custom schemes)

class GoogleAuthConfig {
  /// Web application OAuth client (Next.js / serverClientId).
  static String get clientId => dotenv.env['GOOGLE_CLIENT_ID']?.trim() ?? '';

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
