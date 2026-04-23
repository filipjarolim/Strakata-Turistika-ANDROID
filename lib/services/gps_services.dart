import 'dart:async';
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
import '../repositories/visit_repository.dart';
import '../services/auth_service.dart';
import '../models/visit_data.dart';

class GpsServices {
  static Future<Map<String, bool>> checkPermissionsStatus() async {
    final location = await Permission.location.status;
    final background = await Permission.locationAlways.status;
    final battery = await Permission.ignoreBatteryOptimizations.status;
    
    return {
      'location': location.isGranted,
      'background': background.isGranted,
      'battery_granted': battery.isGranted, 
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
      if (currentPosition.heading != null) {
        setDeviceHeading(currentPosition.heading);
        // print('Initial compass heading: ${currentPosition.heading}°');
      }
      
      // Start listening to compass updates
      final compassSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
          timeLimit: Duration(seconds: 8),
        ),
      ).listen(
        (Position position) {
          if (position.heading != null) {
            setDeviceHeading(position.heading);
            // print('Compass heading: ${position.heading}°');
          }
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
        // Offer: Save as draft now or fill details now
        // Default: save as DRAFT immediately for safety
        try {
          final currentUser = AuthService.currentUser;
          final now = DateTime.now();
          
          final visit = VisitData(
            id: '', // Repo will assign
            userId: currentUser?.id,
            user: currentUser != null ? {'name': currentUser.name, 'email': currentUser.email, 'image': currentUser.image} : null,
            seasonId: null,
            year: now.year,
            visitDate: trackingSummary.startTime,
            createdAt: now,
            state: VisitState.DRAFT,
            points: 0,
            routeTitle: 'Trasa ${now.day}.${now.month}.${now.year}',
            routeDescription: 'GPS trasa',
            visitedPlaces: '', // Empty for draft
            dogName: currentUser?.dogName,
            dogNotAllowed: null,
            photos: [],
            places: [],
            route: {
              'duration': trackingSummary.duration.inSeconds,
              'totalDistance': trackingSummary.totalDistance,
              'averageSpeed': trackingSummary.averageSpeed,
              'maxSpeed': trackingSummary.maxSpeed,
              'trackPoints': trackingSummary.trackPoints.map((p) => p.toJson()).toList(),
            },
            extraData: {},
            extraPoints: {
              'source': 'gps_tracking',
            },
          );

          final repo = VisitRepository();
          final savedId = await repo.saveVisit(visit);
          VisitData? draftVisit;
          if (savedId != null) {
            draftVisit = visit.copyWith(id: savedId);
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
      final permission = await Geolocator.checkPermission();
      
      // print('GPS Status:');
      // print('Service enabled: $serviceEnabled');
      // print('Permission: $permission');
      
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
      
      if (location != null) {
        moveMap(location);
      }
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
    final summary = trackingStateService.getSummary();
    // print('Tracking Status:');
    // print('Is tracking: ${trackingStateService.isTracking}');
    // print('Background service running: ${summary.isTracking}');
    // print('Track points: ${summary.trackPoints.length}');
    // print('Total distance: ${summary.totalDistance}m');
    // print('Duration: ${summary.duration}');
  }

  static Future<void> testCompass({
    required Function(double?) setDeviceHeading,
  }) async {
    try {
      print('Testing compass detection...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      if (position.heading != null) {
        setDeviceHeading(position.heading);
        print('Updated device heading to: ${position.heading}°');
      } else {
        print('No heading data available - trying alternative method');
        // Try to get heading from device orientation
        try {
          final orientation = await Geolocator.getLastKnownPosition();
          if (orientation?.heading != null) {
            setDeviceHeading(orientation!.heading);
            print('Updated device heading from last known position: ${orientation!.heading}°');
          }
        } catch (e) {
          print('Alternative compass method failed: $e');
        }
      }
    } catch (e) {
      print('Compass test failed: $e');
    }
  }
} 