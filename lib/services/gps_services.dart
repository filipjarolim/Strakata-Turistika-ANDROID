import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:latlong2/latlong.dart';
import '../services/tracking_state_service.dart';
import '../services/haptic_service.dart';
import '../services/logging_service.dart';
import '../widgets/ui/app_toast.dart';
import '../utils/gps_utils.dart';
import '../models/tracking_summary.dart';
import '../services/auth_service.dart';
import '../services/live_track_checkpoint_service.dart';
import '../services/route_backup_service.dart';
import '../models/visit_data.dart';

class GpsServices {
  static Future<Map<String, bool>> checkPermissionsStatus() async {
    final location = await Permission.location.status;
    final background = await Permission.locationAlways.status;
    // Battery optimization exemption exists only on Android.
    final battery = Platform.isAndroid
        ? await Permission.ignoreBatteryOptimizations.status
        : PermissionStatus.granted;

    return {
      'location': location.isGranted,
      'background': background.isGranted,
      // On iOS always true so tracking start isn't blocked.
      'battery_granted': Platform.isIOS || battery.isGranted,
    };
  }

  static void showGPSDisabledDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.red),
            SizedBox(width: 12),
            Text('GPS je vypnuto'),
          ],
        ),
        content: const Text(
          'Pro trackování trasy musíte zapnout GPS služby na vašem zařízení. '
          'Přejděte do nastavení a zapněte polohu.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zrušit'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Geolocator.openLocationSettings();
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF4CAF50),
            ),
            child: const Text('Otevřít nastavení'),
          ),
        ],
      ),
    );
  }

  static Future<void> initializeNotifications() async {
    try {
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
      
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings();
      
      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      
      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload == 'gps_tracking_page') {
            // Navigation will be handled by main.dart
          }
        },
      );
    } catch (e) {
      LoggingService().log('Notification initialization failed: $e', level: 'ERROR');
    }
  }

  static Future<void> initializeEnhancedGPSTracking(TrackingStateService trackingStateService) async {
    try {
      await trackingStateService.initialize();
      // print('Tracking State Service initialized');
    } catch (e) {
      LoggingService().log('Tracking State Service initialization failed: $e', level: 'ERROR');
    }
  }

  static Future<void> initializeCompass({
    required Function(double?) setDeviceHeading,
    required Function(StreamSubscription?) setCompassSubscription,
  }) async {
    try {
      // Get initial heading
      final currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      setDeviceHeading(currentPosition.heading);
      
      // Start listening to compass updates
      final compassSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
          timeLimit: Duration(seconds: 8),
        ),
      ).listen(
        (Position position) {
          setDeviceHeading(position.heading);
        },
        onError: (error) {
          print('Compass error: $error');
        },
      );
      
      setCompassSubscription(compassSubscription);
      // print('Compass initialized');
    } catch (e) {
      print('Failed to initialize compass: $e');
    }
  }

  static Future<void> startTracking({
    required TrackingStateService trackingStateService,
    required BuildContext context,
    required VoidCallback onSuccess,
  }) async {
    try {
      // Note: GPS service check is now done in gps_page.dart before calling this
      
      // Start tracking (permissions will be requested inside)
      final success = await trackingStateService.startTracking();
      if (success) {
        HapticService.lightImpact();
        onSuccess();
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        AppToast.showError(context, 'Chyba při spuštění sledování: Služba se nespustila');
      }
    } catch (e) {
      LoggingService().log('Failed to start tracking: $e', level: 'ERROR');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      AppToast.showError(context, 'Chyba při spuštění sledování: $e');
    }
  }

  static Future<void> stopTracking({
    required TrackingStateService trackingStateService,
    required BuildContext context,
    required VoidCallback onSuccess,
    required void Function(TrackingSummary summary, VisitData? draftVisit) showTrackingSummary,
  }) async {
    try {
      await trackingStateService.stopTracking();
      
      HapticService.mediumImpact();
      onSuccess();
      
      final trackingSummary = trackingStateService.getSummary();
      if (trackingSummary.trackPoints.isNotEmpty) {
        // Trasa se nejdřív zálohuje lokálně — kdyby zápis do DB selhal
        // (výpadek sítě, chyba serveru), data zůstanou v telefonu.
        await RouteBackupService().saveBackup(trackingSummary, active: false);
        await RouteBackupService().markInactive();

        try {
          final draftVisit = await LiveTrackCheckpointService().saveDraft(
            trackingSummary,
            clearLocalOnSuccess: true,
          );
          if (draftVisit == null && AuthService.currentUser == null) {
            print('⚠️ Draft se do DB neuložil — uživatel není přihlášen. Zůstává lokální záloha.');
          }
          showTrackingSummary(trackingSummary, draftVisit);
        } catch (e) {
          print('Error autosaving draft: $e');
          showTrackingSummary(trackingSummary, null);
        }
      }
      
      // Stop toast removed per request
    } catch (e) {
      LoggingService().log('Failed to stop tracking: $e', level: 'ERROR');
    }
  }

  static Future<void> checkGPSStatus(BuildContext context) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        AppToast.showInfo(context, 'GPS služby jsou vypnuté. Zapněte GPS v nastavení.');
      }
    } catch (e) {
      LoggingService().log('GPS status check failed: $e', level: 'ERROR');
    }
  }

  static Future<void> forceLocationUpdate({
    required TrackingStateService trackingStateService,
    required Function(LatLng?, double?, double?, double?) setLocationData,
    required Function(LatLng) moveMap,
  }) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // Add position to tracking service if tracking is active
      if (trackingStateService.isTracking) {
        trackingStateService.forceAddPosition(position);
      }
      
      final location = LatLng(position.latitude, position.longitude);
      setLocationData(location, position.speed, position.altitude, position.heading);
      moveMap(location);
    } catch (e) {
      LoggingService().log('Location update failed: $e', level: 'ERROR');
    }
  }

  static Future<void> addTestTrackPoint(TrackingStateService trackingStateService) async {
    try {
      final position = await Geolocator.getCurrentPosition();
      trackingStateService.forceAddPosition(position);
      HapticService.lightImpact();
    } catch (e) {
      LoggingService().log('Failed to add test point: $e', level: 'ERROR');
    }
  }

  static Future<void> addDebugTrackPoints({
    required TrackingStateService trackingStateService,
    required BuildContext context,
  }) async {
    try {
      // Create a smart route with smooth curves and direction changes
      final List<LatLng> debugPoints = GpsUtils.generateSmartRoute();
      
      // Add each point to the tracking service
      for (final point in debugPoints) {
        final position = Position(
          latitude: point.latitude,
          longitude: point.longitude,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 200.0,
          altitudeAccuracy: 5.0,
          heading: 90.0,
          headingAccuracy: 5.0,
          speed: 5.0,
          speedAccuracy: 1.0,
        );
        
        trackingStateService.forceAddPosition(position);
        await Future.delayed(const Duration(milliseconds: 100)); // Small delay between points
      }
      
      HapticService.lightImpact();
      AppToast.showSuccess(context, 'Smart route with smooth curves added');
    } catch (e) {
      LoggingService().log('Failed to add debug track points: $e', level: 'ERROR');
    }
  }

  static Future<void> restartTracking(TrackingStateService trackingStateService) async {
    try {
      await trackingStateService.stopTracking();
      final success = await trackingStateService.startTracking();
      if (success) {
        HapticService.mediumImpact();
      }
    } catch (e) {
      LoggingService().log('Failed to restart tracking: $e', level: 'ERROR');
    }
  }

  static void checkTrackingStatus(TrackingStateService trackingStateService) {
    // print('Tracking Status: isTracking=${trackingStateService.isTracking}');
  }

  static Future<void> testCompass({
    required Function(double?) setDeviceHeading,
  }) async {
    try {
      print('Testing compass detection...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setDeviceHeading(position.heading);
      print('Updated device heading to: ${position.heading}°');
    } catch (e) {
      print('Compass test failed, trying alternative method: $e');
      try {
        final orientation = await Geolocator.getLastKnownPosition();
        if (orientation != null) {
          setDeviceHeading(orientation.heading);
          print('Updated device heading from last known position: ${orientation.heading}°');
        }
      } catch (err) {
        print('Alternative compass method failed: $err');
      }
    }
  }
} 