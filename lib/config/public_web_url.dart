import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Veřejná URL webu (registrace / právní texty). Volitelně `PUBLIC_WEB_URL` v `.env`.
String publicWebBaseUrl() {
  final u = dotenv.env['PUBLIC_WEB_URL']?.trim();
  if (u != null && u.isNotEmpty) {
    return u.replaceAll(RegExp(r'/+$'), '');
  }
  return 'https://strakata.cz';
}
