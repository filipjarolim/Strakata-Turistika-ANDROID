import 'dart:async';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'enhanced_gps_tracking_service.dart';
import '../models/tracking_summary.dart';

class TrackingStateService {
  static final TrackingStateService _instance = TrackingStateService._internal();
  factory TrackingStateService() => _instance;
  TrackingStateService._internal();

  final EnhancedGPSTrackingService _trackingService = EnhancedGPSTrackingService();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  bool _isTracking = false;
  Timer? _updateTimer;
  static const int _trackingNotificationId = 2001;
  
  // Stream controllers for state changes
  final StreamController<bool> _trackingStateController = StreamController<bool>.broadcast();
  final StreamController<String> _trackingInfoController = StreamController<String>.broadcast();
  
  // Getters
  bool get isTracking => _isTracking;
  Stream<bool> get trackingStateStream => _trackingStateController.stream;
  Stream<String> get trackingInfoStream => _trackingInfoController.stream;
  
  // Initialize the service
  Future<void> initialize() async {
    await _initializeNotifications();
    await _trackingService.initialize();
    
    // Check if tracking was already active (e.g., from app restart)
    final summary = _trackingService.getSummary();
    if (summary.isTracking) {
      _isTracking = true;
      _trackingStateController.add(true);
      _startTrackingUpdates();
      // Avoid duplicate system notifications on Android; native service already shows one
      if (!Platform.isAndroid) {
        _showTrackingNotification();
      }
    }
  }
  
  // Initialize notifications
  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(initSettings);
    
    // Create notification channel for tracking status
    const androidChannel = AndroidNotificationChannel(
      'tracking_status',
      'Tracking Status',
      description: 'Shows tracking status across all pages',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );
    
    await _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(androidChannel);
  }
  
  // Start tracking
  Future<bool> startTracking() async {
    final success = await _trackingService.startTracking();
    if (success) {
      _isTracking = true;
      _trackingStateController.add(true);
      _startTrackingUpdates();
      if (!Platform.isAndroid) {
        _showTrackingNotification();
      }
    }
    return success;
  }
  
  // Stop tracking
  Future<void> stopTracking() async {
    await _trackingService.stopTracking();
    _isTracking = false;
    _trackingStateController.add(false);
    _stopTrackingUpdates();
    _hideTrackingNotification();
  }
  
  // Start periodic updates
  void _startTrackingUpdates() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_isTracking) {
        final summary = _trackingService.getSummary();
        final duration = summary.duration;
        final distance = summary.totalDistance / 1000;
        final speed = summary.averageSpeed * 3.6;
        
        final hours = duration.inHours;
        final minutes = duration.inMinutes % 60;
        final seconds = duration.inSeconds % 60;
        
        final info = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} • ${distance.toStringAsFixed(2)} km • ${speed.toStringAsFixed(1)} km/h';
        
        _trackingInfoController.add(info);
        _updateTrackingNotification(info);
      } else {
        timer.cancel();
      }
    });
  }
  
  // Stop periodic updates
  void _stopTrackingUpdates() {
    _updateTimer?.cancel();
  }
  
  // Show tracking notification
  Future<void> _showTrackingNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'tracking_status',
      'Tracking Status',
      channelDescription: 'Shows tracking status across all pages',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      enableLights: false,
      playSound: false,
      enableVibration: false,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );
    
    const notificationDetails = NotificationDetails(android: androidDetails);
    
    // Disabled persistent tracking notification title per request
  }
  
  // Update tracking notification
  Future<void> _updateTrackingNotification(String info) async {
    if (!_isTracking) return;
    if (Platform.isAndroid) return; // Skip on Android to prevent duplicates
    
    const androidDetails = AndroidNotificationDetails(
      'tracking_status',
      'Tracking Status',
      channelDescription: 'Shows tracking status across all pages',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      enableLights: false,
      playSound: false,
      enableVibration: false,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );
    
    const notificationDetails = NotificationDetails(android: androidDetails);
    
    // Disabled tracking notification update per request
  }
  
  // Hide tracking notification
  Future<void> _hideTrackingNotification() async {
    await _notifications.cancel(_trackingNotificationId);
  }
  
  // Get tracking summary
  TrackingSummary getSummary() {
    return _trackingService.getSummary();
  }
  
  // Force add position (for testing)
  void forceAddPosition(Position position) {
    _trackingService.forceAddPosition(position);
  }
  
  // Dispose resources
  void dispose() {
    _updateTimer?.cancel();
    _trackingStateController.close();
    _trackingInfoController.close();
    _trackingService.dispose();
  }
} 