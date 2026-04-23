import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_item.dart';
import 'notification_channels.dart';

class NotificationsService {
  static final NotificationsService _instance =
      NotificationsService._internal();
  factory NotificationsService() => _instance;
  NotificationsService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const String _storageKey = 'notifications_list_v1';
  List<NotificationItem> _items = [];

  List<NotificationItem> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((n) => !n.read).length;

  Future<void> initialize() async {
    // Local notifications init
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        _handleLocalTap(response.payload);
      },
    );
    await NotificationChannels.ensureCreated(_local);

    // Request FCM permissions (iOS/macOS); on Android it's granted by default
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Load stored notifications
    await _loadStored();

    // Get token (could be sent to backend for targeting)
    await _messaging.getToken();

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final item = _fromMessage(message);
      if (item != null) {
        _addAndPersist(item);
        _showLocal(item);
      }
    });

    // Taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final item = _fromMessage(message);
      if (item != null) {
        _addAndPersist(item);
        _handleDeepLink(item);
      }
    });

    // App opened from terminated by tapping a notification
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      final item = _fromMessage(initial);
      if (item != null) {
        _addAndPersist(item);
        _handleDeepLink(item);
      }
    }
  }

  NotificationItem? _fromMessage(RemoteMessage message) {
    final id =
        message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString();
    final title = message.notification?.title ?? message.data['title'] ?? '';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    if (title.isEmpty && body.isEmpty) return null;
    return NotificationItem(
      id: id,
      title: title,
      body: body,
      type: message.data['type'] ?? 'generic',
      timestamp: message.sentTime ?? DateTime.now(),
      data: message.data.isNotEmpty
          ? Map<String, dynamic>.from(message.data)
          : null,
      read: false,
    );
  }

  Future<void> _showLocal(NotificationItem item) async {
    final androidDetails = AndroidNotificationDetails(
      _channelFor(item),
      _channelNameFor(item),
      channelDescription: _channelDescriptionFor(item),
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    await _local.show(
      item.hashCode,
      item.title,
      item.body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode({
        'id': item.id,
        'type': item.type,
        'data': item.data,
      }),
    );
  }

  String _channelFor(NotificationItem item) {
    return NotificationChannels.general;
  }

  String _channelNameFor(NotificationItem item) {
    return 'Obecne aktuality';
  }

  String _channelDescriptionFor(NotificationItem item) {
    return 'Bezne notifikace aplikace';
  }

  Future<void> _handleLocalTap(String? payload) async {
    if (payload == null) return;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final id = map['id'] as String?;
      if (id != null) {
        markAsRead(id);
      }
      // Optionally deep link
    } catch (_) {}
  }

  Future<void> _loadStored() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? [];
    _items =
        raw
            .map(
              (s) => NotificationItem.fromMap(
                jsonDecode(s) as Map<String, dynamic>,
              ),
            )
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _storageKey,
      _items.map((e) => jsonEncode(e.toMap())).toList(),
    );
  }

  void _addAndPersist(NotificationItem item) {
    _items.removeWhere((n) => n.id == item.id);
    _items.insert(0, item);
    _persist();
  }

  Future<void> markAllRead() async {
    for (final n in _items) {
      n.read = true;
    }
    await _persist();
  }

  Future<void> markAsRead(String id) async {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _items[idx].read = true;
      await _persist();
    }
  }

  Future<void> clearAll() async {
    _items.clear();
    await _persist();
  }

  void _handleDeepLink(NotificationItem item) {
    // TODO: Add explicit route handling for notification types.
  }
}

// Background handler (must be a top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // We keep it minimal; local storage will be handled on next app resume.
}
