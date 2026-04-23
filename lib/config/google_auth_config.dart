import 'package:flutter_dotenv/flutter_dotenv.dart';

// Google OAuth Configuration
// Reads credentials from .env file (same as Next.js app)

class GoogleAuthConfig {
  static String get clientId => dotenv.env['GOOGLE_CLIENT_ID']?.trim() ?? '';

  static String get clientSecret => dotenv.env['GOOGLE_CLIENT_SECRET']?.trim() ?? '';

  static const List<String> scopes = ['email', 'profile'];

  static bool get isConfigured => clientId.isNotEmpty;
} 