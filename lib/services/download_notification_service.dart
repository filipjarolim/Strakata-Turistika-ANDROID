import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_channels.dart';

class DownloadNotificationService {
  static const int _downloadProgressId = 1001;
  static const int _downloadCompletedId = 1002;
  static const int _downloadFailedId = 1003;

  static FlutterLocalNotificationsPlugin? _notificationsPlugin;

  static Future<void> initialize() async {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _notificationsPlugin!.initialize(initializationSettings);
    await NotificationChannels.ensureCreated(_notificationsPlugin!);
  }

  static Future<void> showDownloadProgress({
    required String title,
    required int progress,
    required int total,
  }) async {
    if (_notificationsPlugin == null) return;

    final percentage = ((progress / total) * 100).round();

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          NotificationChannels.downloads,
          'Stahovani map',
          channelDescription: 'Prubeh a vysledek stahovani offline map',
          importance: Importance.low,
          priority: Priority.low,
          showProgress: true,
          maxProgress: 100,
          progress: percentage,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin!.show(
      _downloadProgressId,
      title,
      'Downloading... $percentage%',
      platformChannelSpecifics,
      payload: 'download_progress',
    );
  }

  static Future<void> showDownloadCompleted({
    required String title,
    required String message,
  }) async {
    if (_notificationsPlugin == null) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          NotificationChannels.downloads,
          'Stahovani map',
          channelDescription: 'Prubeh a vysledek stahovani offline map',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin!.show(
      _downloadCompletedId,
      title,
      message,
      platformChannelSpecifics,
      payload: 'download_completed',
    );
  }

  static Future<void> showDownloadFailed({
    required String title,
    required String message,
  }) async {
    if (_notificationsPlugin == null) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          NotificationChannels.downloads,
          'Stahovani map',
          channelDescription: 'Prubeh a vysledek stahovani offline map',
          importance: Importance.high,
          priority: Priority.high,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin!.show(
      _downloadFailedId,
      title,
      message,
      platformChannelSpecifics,
      payload: 'download_failed',
    );
  }

  static Future<void> cancelProgressNotification() async {
    if (_notificationsPlugin == null) return;
    await _notificationsPlugin!.cancel(_downloadProgressId);
  }
}
