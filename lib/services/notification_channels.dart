import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationChannels {
  static const String general = 'general_updates';
  static const String downloads = 'map_downloads';

  static Future<void> ensureCreated(
    FlutterLocalNotificationsPlugin plugin,
  ) async {
    if (!Platform.isAndroid) return;
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        general,
        'Obecne aktuality',
        description: 'Bezne notifikace aplikace',
        importance: Importance.high,
      ),
    );

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        downloads,
        'Stahovani map',
        description: 'Prubeh a vysledek stahovani offline map',
        importance: Importance.defaultImportance,
      ),
    );
  }
}
