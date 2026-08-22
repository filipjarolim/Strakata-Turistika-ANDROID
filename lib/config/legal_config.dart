import 'public_web_url.dart';

/// In-app legal identity and public URLs required for store production
/// (privacy policy in-app, terms, support contact, copyright).
class LegalConfig {
  LegalConfig._();

  static const String appName = 'Strakatá Turistika';
  static const String publisherName = 'Strakatá Turistika';
  static const String supportEmail = 'jarolimfilip07@gmail.com';
  static const String shortDescription =
      'Aplikace pro GPS turistiku a soutěž Strakatá turistika.';

  static String get websiteUrl => publicWebBaseUrl();
  static String get privacyUrl => '${publicWebBaseUrl()}/privacy';
  static String get termsUrl => '${publicWebBaseUrl()}/terms';
  static String get rulesUrl => '${publicWebBaseUrl()}/pravidla';

  static String get legalese =>
      '© ${DateTime.now().year} $copyrightHolder. Všechna práva vyhrazena.';

  static const String copyrightHolder = publisherName;

  static Uri get supportMailtoUri => Uri(
        scheme: 'mailto',
        path: supportEmail,
        queryParameters: {
          'subject': '$appName – podpora',
        },
      );
}
