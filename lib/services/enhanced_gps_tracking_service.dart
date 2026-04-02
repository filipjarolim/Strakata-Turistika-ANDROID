import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../services/haptic_service.dart';

import '../models/tracking_summary.dart';
import '../config/gps_config.dart';

enum _MotionProfile { stationary, walking, running, driving }

class EnhancedGPSTrackingService {
  static final EnhancedGPSTrackingService _instance = EnhancedGPSTrackingService._internal();
  factory EnhancedGPSTrackingService() => _instance;
  EnhancedGPSTrackingService._internal();

  // Method channel for Android service communication
  static const MethodChannel _methodChannel = MethodChannel('gps_tracking_channel');
  static const EventChannel _eventChannel = EventChannel('gps_location_events');

  // Tracking state
  bool _isTracking = false;
  DateTime? _startTime;
  List<TrackPoint> _trackPoints = [];
  StreamSubscription? _locationEventSubscription;
  
  // Background service state
  bool _backgroundServiceRunning = false;
  
  // Advanced tracking algorithms
  final List<Position> _rawPositions = [];
  final List<Position> _filteredPositions = [];
  Position? _lastValidPosition;
  double? _lastDerivedSpeedMs;
  bool _hasFirstFix = false;
  DateTime? _lastRawAt;
  DateTime? _lastAcceptedAt;
  DateTime? _relaxedUntil;
  
  // Stationary lock / hysteresis to suppress GPS drift when not moving
  bool _stationaryLocked = false;
  Position? _stationaryAnchor;
  DateTime? _stationaryCandidateSince;
  int _consecutiveUnlockEligible = 0;
  
  // Kalman filter parameters - more conservative for better accuracy
  double _processNoise = 0.05; // Reduced from 0.1
  double _measurementNoise = 1.0; // tighter measurement noise for stronger smoothing
  double _kalmanGain = 0.0;
  double _errorCovariance = 1.0;
  
  // Speed and distance calculations
  double _totalDistance = 0.0;
  double _averageSpeed = 0.0;
  double _maxSpeed = 0.0;
  double _totalElevationGain = 0.0;
  double _totalElevationLoss = 0.0;
  double? _minAltitude;
  double? _maxAltitude;
  
  // Notification
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static const int _trackingNotificationId = 1001;
  
  // Periodic location retrieval
  Timer? _periodicLocationTimer;
  Timer? _backgroundCheckTimer;
  StreamSubscription<Position>? _iosPositionSubscription;
  StreamSubscription<Position>? _androidBackupSubscription;
  Timer? _watchdogTimer;
  
  // Speed filtering (reduce jitter when stationary)
  double? _lastFilteredSpeed;
  static const double _stationarySpeedThreshold = GpsConfig.stationarySpeedThresholdMs; // m/s (~1.8 km/h)
  static const double _emaAlpha = GpsConfig.emaAlpha; // exponential moving average factor
  _MotionProfile? _currentProfile;

  /// When true, elapsed time does not increase and new GPS points are not recorded.
  bool _recordingPaused = false;
  DateTime? _pauseStartedAt;
  Duration _pausedBeforeCurrentSegment = Duration.zero;
  
  // Getters
  bool get isTracking => _isTracking;
  bool get isRecordingPaused => _recordingPaused;
  DateTime? get startTime => _startTime;
  double get totalDistance => _totalDistance;
  double get averageSpeed => _averageSpeed;
  double get maxSpeed => _maxSpeed;
  Duration get trackingDuration {
    if (_startTime == null) return Duration.zero;
    final wall = DateTime.now().difference(_startTime!);
    final currentPause = (_recordingPaused && _pauseStartedAt != null)
        ? DateTime.now().difference(_pauseStartedAt!)
        : Duration.zero;
    final active = wall - _pausedBeforeCurrentSegment - currentPause;
    return active.isNegative ? Duration.zero : active;
  }
  List<TrackPoint> get trackPoints => List.unmodifiable(_trackPoints);
  bool get backgroundServiceRunning => _backgroundServiceRunning;
  
  // Get current heading
  double? get currentHeading {
    if (_trackPoints.length < 2) return null;
    final lastPoint = _trackPoints.last;
    return lastPoint.heading;
  }

  /// Pause or resume recording (time and track points). Does nothing if not tracking.
  void setRecordingPaused(bool paused) {
    if (!_isTracking) return;
    final now = DateTime.now();
    if (paused && !_recordingPaused) {
      _recordingPaused = true;
      _pauseStartedAt = now;
    } else if (!paused && _recordingPaused) {
      if (_pauseStartedAt != null) {
        _pausedBeforeCurrentSegment += now.difference(_pauseStartedAt!);
      }
      _pauseStartedAt = null;
      _recordingPaused = false;
    }
  }

  void _resetRecordingPauseState() {
    _recordingPaused = false;
    _pauseStartedAt = null;
    _pausedBeforeCurrentSegment = Duration.zero;
  }

  // Force add a position for testing (useful when GPS is not working)
  void forceAddPosition(Position position) {
    if (_isTracking && !_recordingPaused) {
      // Ensure previous reference is set so statistics use a realistic baseline
      if (_trackPoints.isNotEmpty) {
        final prev = _trackPoints.last;
        _lastValidPosition = Position(
          latitude: prev.latitude,
          longitude: prev.longitude,
          timestamp: prev.timestamp,
          accuracy: prev.accuracy,
          altitude: prev.altitude ?? 0.0,
          altitudeAccuracy: prev.verticalAccuracy ?? 0.0,
          heading: prev.heading ?? 0.0,
          headingAccuracy: 0.0,
          speed: prev.speed,
          speedAccuracy: 0.0,
        );
      }

      final trackPoint = TrackPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: position.timestamp,
        speed: position.speed,
        accuracy: position.accuracy,
        heading: position.heading,
        altitude: position.altitude,
        verticalAccuracy: position.altitudeAccuracy,
      );
      
      _trackPoints.add(trackPoint);
      _updateStatistics(position);
      // Update last valid position so next point uses this one for distance/time
      _lastValidPosition = position;
    }
  }
  
  // Get elevation statistics
  double get totalElevationGain => _totalElevationGain;
  double get totalElevationLoss => _totalElevationLoss;

  // Initialize the service
  Future<void> initialize() async {
    await _initializeNotifications();
    await _setupEventChannel();
  }
  
  // Setup event channel for receiving location updates from Android service
  Future<void> _setupEventChannel() async {
    _locationEventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          _handleLocationFromService(event);
        }
      },
      onError: (error) {
        print('GPS Event Channel Error: $error');
        FirebaseCrashlytics.instance.log('GPS Event Channel Error: $error');
      },
    );
  }
  
  // Handle location updates from Android background service
  void _handleLocationFromService(Map<dynamic, dynamic> locationData) {
    if (!_isTracking) return;
    
    final position = Position(
      latitude: locationData['latitude']?.toDouble() ?? 0.0,
      longitude: locationData['longitude']?.toDouble() ?? 0.0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(locationData['timestamp'] ?? 0),
      accuracy: locationData['accuracy']?.toDouble() ?? 0.0,
      altitude: locationData['altitude']?.toDouble(),
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: locationData['speed']?.toDouble() ?? 0.0,
      speedAccuracy: 0.0,
    );
    
    onPositionUpdate(position);
  }
  
  // Request location permissions with battery optimization
  Future<bool> _requestPermissions() async {
    // print('GPS: Requesting all necessary permissions...');
    
    // First check if location service is enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('GPS: Location service is not enabled');
      return false;
    }
    
    // Step 1: Use Geolocator directly to request location permission
    // This triggers Android's native permission dialog more reliably
    // print('GPS: Checking location permission status...');
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      print('GPS: Location permission denied, requesting...');
      permission = await Geolocator.requestPermission();
      
      if (permission == LocationPermission.denied) {
        print('GPS: Location permission denied by user');
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      print('GPS: Location permission permanently denied - user needs to go to settings');
      return false;
    }
    
    // print('GPS: Basic location permission granted ✓ (${permission.name})');
    
    // Step 2: Request background location permission
    // This must be done AFTER basic permission is granted
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      // Give Android time to process the foreground permission
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // print('GPS: Now requesting background location permission...');
      var locationAlwaysStatus = await Permission.locationAlways.status;
      
      if (!locationAlwaysStatus.isGranted) {
        print('GPS: Requesting background location (Always)...');
        
        // Request background location - Android will show system dialog
        locationAlwaysStatus = await Permission.locationAlways.request();
        
        if (!locationAlwaysStatus.isGranted) {
          print('GPS: Background location permission denied');
          print('GPS: WARNING - Tracking may not work reliably when screen is locked!');
          // Continue anyway - we'll show a warning dialog
        } else {
          // print('GPS: Background location permission granted ✓');
        }
      } else {
        // print('GPS: Background location permission already granted ✓');
      }
    }
    
    // Step 3: Request battery optimization exemption for better reliability
    var batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    if (!batteryStatus.isGranted) {
      print('GPS: Requesting battery optimization exemption...');
      batteryStatus = await Permission.ignoreBatteryOptimizations.request();
      
      if (batteryStatus.isGranted) {
        // print('GPS: Battery optimization exemption granted ✓');
      } else {
        print('GPS: Battery optimization exemption denied - tracking may be interrupted');
      }
    } else {
      // print('GPS: Battery optimization already exempted ✓');
    }
    
    // Summary
    final locationAlwaysStatus = await Permission.locationAlways.status;
    
    // Return true if we have at least basic location permission
    return permission == LocationPermission.whileInUse || permission == LocationPermission.always;
  }
  
  // Start tracking with enhanced background support
  Future<bool> startTracking() async {
    if (_isTracking) return false;
    
    final hasPermissions = await _requestPermissions();
    
    // Provide haptic feedback for tracking start
    await HapticService.trackingStart();
    if (!hasPermissions) {
      FirebaseCrashlytics.instance.log('GPS Tracking failed: No location permissions');
      return false;
    }
    
    _isTracking = true;
    _startTime = DateTime.now();
    _trackPoints.clear();
    _rawPositions.clear();
    _filteredPositions.clear();
    _totalDistance = 0.0;
    _averageSpeed = 0.0;
    _maxSpeed = 0.0;
    _totalElevationGain = 0.0;
    _totalElevationLoss = 0.0;
    _minAltitude = null;
    _maxAltitude = null;
    _lastValidPosition = null;
    _lastDerivedSpeedMs = null;
    _stationaryLocked = false;
    _stationaryAnchor = null;
    _stationaryCandidateSince = null;
    _consecutiveUnlockEligible = 0;
    _resetRecordingPauseState();
    
    FirebaseCrashlytics.instance.log('Enhanced GPS Tracking started');
    
    // Start Android background service
    await _startBackgroundService();
    // Apply initial adaptive settings based on default assumption (walking)
    await _applyAdaptiveSettingsForPlatform(_MotionProfile.walking);
    
    // Start periodic location retrieval as backup
    _startPeriodicLocationRetrieval();
    
    // Start background service monitoring
    _startBackgroundServiceMonitoring();
    
    // Show persistent notification only when not using native Android foreground service
    if (!(Platform.isAndroid && _backgroundServiceRunning)) {
      await _showTrackingNotification();
      _startNotificationUpdates();
    }
    
    // Start iOS position stream when on iOS
    if (Platform.isIOS) {
      _startOrUpdateIosStream(_MotionProfile.walking);
    }
    
    // Kick off fast-first-fix bootstrap to quickly display user's approximate location
    // This runs fire-and-forget and will relax accuracy thresholds only for the first fix
    // ignore: discarded_futures
    _bootstrapFirstFix();
    // Start reliability watchdog (stale detection, auto-relax, backups)
    _startReliabilityWatchdog();
    
    return true;
  }
  
  // Start Android background service
  Future<void> _startBackgroundService() async {
    try {
      final result = await _methodChannel.invokeMethod('startGPSTracking');
      _backgroundServiceRunning = result == true;
      // print('GPS: Background service started: $_backgroundServiceRunning');
      // After starting, push current settings if already profiled
      if (_currentProfile != null) {
        await _applyAdaptiveSettingsForPlatform(_currentProfile!);
      }
    } catch (e) {
      print('GPS: Failed to start background service: $e');
      FirebaseCrashlytics.instance.log('Failed to start background service: $e');
      _backgroundServiceRunning = false;
    }
  }
  
  // Start periodic location retrieval as backup
  void _startPeriodicLocationRetrieval() {
    _periodicLocationTimer?.cancel();
    final initialInterval = _hasFirstFix
        ? GpsConfig.periodicFallbackInterval
        : GpsConfig.fallbackUntilFirstFixInterval;
    _periodicLocationTimer = Timer.periodic(initialInterval, (timer) async {
      if (_isTracking && !_backgroundServiceRunning) {
        // If background service is not working, get location manually
        try {
          final bool wantFast = !_hasFirstFix;
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: wantFast ? LocationAccuracy.low : LocationAccuracy.high,
            timeLimit: wantFast ? GpsConfig.firstFixLowAccuracyTimeout : const Duration(seconds: 4),
          );
          onPositionUpdate(position);
        } catch (e) {
          print('GPS: Periodic location retrieval failed: $e');
        }
      }
    });
  }

  // Attempt to quickly establish the first location fix by racing last-known and a quick low-accuracy read,
  // followed by a bounded high-accuracy attempt.
  Future<void> _bootstrapFirstFix() async {
    if (!_isTracking) return;
    try {
      // 1) Use last known location if reasonably fresh and within relaxed accuracy
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (!_hasFirstFix && lastKnown != null) {
        final isFresh = DateTime.now().difference(lastKnown.timestamp) <= GpsConfig.firstFixMaxAge;
        final isAccOk = lastKnown.accuracy <= GpsConfig.firstFixRelaxedAccuracyMeters;
        if (isFresh && isAccOk) {
          onPositionUpdate(lastKnown);
        }
      }
      
      if (_hasFirstFix) return;
      
      // 2) Quick low-accuracy read with short timeout
      try {
        final quick = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: GpsConfig.firstFixLowAccuracyTimeout,
        );
        if (!_hasFirstFix) {
          onPositionUpdate(quick);
        }
      } catch (_) {
        // ignore quick attempt failures
      }
      
      if (_hasFirstFix) return;
      
      // 3) Escalate to a bounded high-accuracy attempt
      try {
        final precise = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: GpsConfig.firstFixHighAccuracyTimeout,
        );
        if (!_hasFirstFix) {
          onPositionUpdate(precise);
        }
      } catch (_) {}
    } catch (e) {
      print('GPS: bootstrapFirstFix failed: $e');
    }
  }

  void _startReliabilityWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!_isTracking) {
        timer.cancel();
        return;
      }
      final now = DateTime.now();
      final rawStale = _lastRawAt == null || now.difference(_lastRawAt!) > GpsConfig.staleUpdateThreshold;
      final acceptedStale = _lastAcceptedAt == null || now.difference(_lastAcceptedAt!) > GpsConfig.staleUpdateThreshold;
      
      if (rawStale) {
        // print('GPS: Watchdog detected stale RAW updates; enabling backup stream and restarting service');
        if (Platform.isAndroid) {
          _ensureAndroidBackupStream();
          await _startBackgroundService();
          if (_currentProfile != null) {
            await _applyAdaptiveSettingsForPlatform(_currentProfile!);
          }
        }
      } else if (acceptedStale) {
        // Raw is coming but filters might be too strict → relax briefly and nudge settings faster
        _relaxedUntil = now.add(const Duration(seconds: 20));
        // print('GPS: Watchdog relaxing filters for 20s due to no accepted positions');
        if (Platform.isAndroid) {
          await _applyAdaptiveSettingsForPlatform(_MotionProfile.running);
          _ensureAndroidBackupStream();
        }
      }
    });
  }
  
  void _stopReliabilityWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }
  
  bool _inRelaxedMode() {
    return _relaxedUntil != null && DateTime.now().isBefore(_relaxedUntil!);
  }
  
  void _ensureAndroidBackupStream() {
    if (!Platform.isAndroid) return;
    if (_androidBackupSubscription != null) return;
    final settings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,
    );
    _androidBackupSubscription = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        if (_isTracking) {
          onPositionUpdate(pos);
        }
      },
      onError: (e) {
        print('GPS: Android backup stream error: $e');
        _androidBackupSubscription?.cancel();
        _androidBackupSubscription = null;
      },
    );
    // print('GPS: Android backup stream started');
  }
  
  void _stopAndroidBackupStream() {
    _androidBackupSubscription?.cancel();
    _androidBackupSubscription = null;
  }
  
  // Monitor background service status
  void _startBackgroundServiceMonitoring() {
    _backgroundCheckTimer?.cancel();
    _backgroundCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_isTracking) {
        try {
          final isRunning = await _methodChannel.invokeMethod('isGPSTracking');
          _backgroundServiceRunning = isRunning == true;
          
          if (!_backgroundServiceRunning) {
            print('GPS: Background service stopped, restarting...');
            await _startBackgroundService();
          }
        } catch (e) {
          print('GPS: Background service check failed: $e');
          _backgroundServiceRunning = false;
        }
      } else {
        timer.cancel();
      }
    });
  }
  
  // Stop tracking with enhanced cleanup
  Future<void> stopTracking() async {
    if (!_isTracking) return;
    
    // Provide haptic feedback for tracking stop
    await HapticService.trackingStop();
    
    _isTracking = false;
    // Include any in-progress pause in totals so final stats omit paused time
    if (_recordingPaused && _pauseStartedAt != null) {
      _pausedBeforeCurrentSegment += DateTime.now().difference(_pauseStartedAt!);
    }
    _recordingPaused = false;
    _pauseStartedAt = null;
    
    // Stop Android background service
    await _stopBackgroundService();
    
    // Stop timers
    _periodicLocationTimer?.cancel();
    _backgroundCheckTimer?.cancel();
    _stopReliabilityWatchdog();
    _stopAndroidBackupStream();
    await _iosPositionSubscription?.cancel();
    _iosPositionSubscription = null;
    
    // Hide notification
    await _notifications.cancel(_trackingNotificationId);
    
    // Calculate final statistics
    _calculateFinalStatistics();
    

  }
  
  // Stop Android background service
  Future<void> _stopBackgroundService() async {
    try {
      await _methodChannel.invokeMethod('stopGPSTracking');
      _backgroundServiceRunning = false;
      print('GPS: Background service stopped');
    } catch (e) {
      print('GPS: Failed to stop background service: $e');
      FirebaseCrashlytics.instance.log('Failed to stop background service: $e');
    }
  }
  

  
  // Advanced position processing with Kalman filtering
  void onPositionUpdate(Position position) {
    if (_recordingPaused) return;
    _rawPositions.add(position);
    _lastRawAt = DateTime.now();
    
    // Apply Kalman filter for noise reduction
    final filteredPosition = _applyKalmanFilter(position);
    _filteredPositions.add(filteredPosition);
    
    // Apply additional filters
    if (_isValidPosition(filteredPosition)) {
      // Use previous lastValidPosition for distance/stat calculations, then update it
      _addTrackPoint(filteredPosition);
      _updateStatistics(filteredPosition);
      _lastValidPosition = filteredPosition;
      // After accepting a point, manage stationary lock engagement
      _maybeEngageStationaryLock(filteredPosition);
      if (!_hasFirstFix) {
        _hasFirstFix = true;
        // After first fix, restart periodic fallback with normal interval if needed
        if (_periodicLocationTimer != null) {
          _startPeriodicLocationRetrieval();
        }
      }
      _lastAcceptedAt = DateTime.now();
      // Ensure notification reflects fresh stats
      // ignore: discarded_futures
      _updateTrackingNotification();
      // Adapt settings based on current motion state
      _maybeUpdateAdaptiveSettings(filteredPosition);
    } else {
    }
  }
  
  // Kalman filter implementation for GPS noise reduction
  Position _applyKalmanFilter(Position position) {
    if (_lastValidPosition == null) {
      _errorCovariance = _measurementNoise;
      return position;
    }
    
    // Prediction step
    final predictedPosition = _predictPosition(_lastValidPosition!);
    _errorCovariance += _processNoise;
    
    // Update step
    _kalmanGain = _errorCovariance / (_errorCovariance + _measurementNoise);
    
    // Calculate filtered position
    final filteredLat = predictedPosition.latitude + _kalmanGain * (position.latitude - predictedPosition.latitude);
    final filteredLng = predictedPosition.longitude + _kalmanGain * (position.longitude - predictedPosition.longitude);
    
    _errorCovariance = (1 - _kalmanGain) * _errorCovariance;
    
    return Position(
      latitude: filteredLat,
      longitude: filteredLng,
      timestamp: position.timestamp,
      accuracy: position.accuracy,
      altitude: position.altitude,
      altitudeAccuracy: position.altitudeAccuracy,
      heading: position.heading,
      headingAccuracy: position.headingAccuracy,
      speed: position.speed,
      speedAccuracy: position.speedAccuracy,
    );
  }

  // Decide motion profile from current speed (m/s)
  _MotionProfile _selectMotionProfile(double speedMs) {
    if (speedMs < 0.6) return _MotionProfile.stationary; // ~2.2 km/h
    if (speedMs < 2.2) return _MotionProfile.walking;    // ~8 km/h
    if (speedMs < 6.5) return _MotionProfile.running;    // ~23.4 km/h
    return _MotionProfile.driving;
  }

  // Update native/iOS settings when profile changes
  Future<void> _maybeUpdateAdaptiveSettings(Position position) async {
    final profile = _selectMotionProfile(
      position.speed.isFinite && position.speed >= 0 ? position.speed : (_lastFilteredSpeed ?? 0.0),
    );
    if (_currentProfile == profile) return;
    _currentProfile = profile;
    await _applyAdaptiveSettingsForPlatform(profile);
  }

  Future<void> _applyAdaptiveSettingsForPlatform(_MotionProfile profile) async {
    // Android: push settings to foreground service
    if (Platform.isAndroid) {
      try {
        final settings = _androidSettingsFor(profile);
        await _methodChannel.invokeMethod('updateGPSSettings', settings);
        // print('GPS: Android settings updated for profile: $profile');
      } catch (e) {
        print('GPS: Failed to update Android GPS settings: $e');
      }
    }
    // iOS: restart position stream with new settings
    if (Platform.isIOS) {
      _startOrUpdateIosStream(profile);
    }
  }

  Map<String, dynamic> _androidSettingsFor(_MotionProfile profile) {
    switch (profile) {
      case _MotionProfile.stationary:
        return {
          'intervalMs': 10000,
          'fastestIntervalMs': 5000,
          'maxWaitTimeMs': 15000,
          'smallestDisplacementM': 8.0,
          'priority': 102, // BALANCED_POWER
        };
      case _MotionProfile.walking:
        return {
          'intervalMs': 4000,
          'fastestIntervalMs': 2000,
          'maxWaitTimeMs': 6000,
          'smallestDisplacementM': 3.0,
          'priority': 100, // HIGH_ACCURACY
        };
      case _MotionProfile.running:
        return {
          'intervalMs': 2000,
          'fastestIntervalMs': 1000,
          'maxWaitTimeMs': 3000,
          'smallestDisplacementM': 2.0,
          'priority': 100,
        };
      case _MotionProfile.driving:
        return {
          'intervalMs': 1000,
          'fastestIntervalMs': 500,
          'maxWaitTimeMs': 1500,
          'smallestDisplacementM': 5.0,
          'priority': 100,
        };
    }
  }

  void _startOrUpdateIosStream(_MotionProfile profile) {
    // Build generic iOS stream settings compatible with current Geolocator
    int distanceFilter;
    LocationAccuracy accuracy;
    switch (profile) {
      case _MotionProfile.stationary:
        distanceFilter = 8;
        accuracy = LocationAccuracy.best;
        break;
      case _MotionProfile.walking:
        distanceFilter = 3;
        accuracy = LocationAccuracy.bestForNavigation;
        break;
      case _MotionProfile.running:
        distanceFilter = 2;
        accuracy = LocationAccuracy.bestForNavigation;
        break;
      case _MotionProfile.driving:
        distanceFilter = 5;
        accuracy = LocationAccuracy.bestForNavigation;
        break;
    }
    final settings = LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
    );
    // Restart subscription only if needed
    _iosPositionSubscription?.cancel();
    _iosPositionSubscription = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        if (_isTracking) {
          onPositionUpdate(pos);
        }
      },
      onError: (e) {
        print('GPS: iOS position stream error: $e');
      },
    );
  }
  
  // Predict next position based on current speed and heading
  Position _predictPosition(Position current) {
    if (current.speed <= 0 || current.heading == null) return current;
    
    const earthRadius = 6371000.0; // meters
    final distance = current.speed * 1.0; // 1 second prediction
    
    final lat1 = current.latitude * pi / 180;
    final lng1 = current.longitude * pi / 180;
    final bearing = current.heading! * pi / 180;
    
    final lat2 = asin(sin(lat1) * cos(distance / earthRadius) + cos(lat1) * sin(distance / earthRadius) * cos(bearing));
    final lng2 = lng1 + atan2(sin(bearing) * sin(distance / earthRadius) * cos(lat1), cos(distance / earthRadius) - sin(lat1) * sin(lat2));
    
    return Position(
      latitude: lat2 * 180 / pi,
      longitude: lng2 * 180 / pi,
      timestamp: current.timestamp,
      accuracy: current.accuracy,
      altitude: current.altitude,
      altitudeAccuracy: current.altitudeAccuracy,
      heading: current.heading,
      headingAccuracy: current.headingAccuracy,
      speed: current.speed,
      speedAccuracy: current.speedAccuracy,
    );
  }
  
  // Validate position quality with strict filtering
  bool _isValidPosition(Position position) {
    // Check accuracy - relaxed for first fix and during watchdog relax window
    final bool relaxed = !_hasFirstFix || _inRelaxedMode();
    final maxAcc = relaxed ? GpsConfig.firstFixRelaxedAccuracyMeters : GpsConfig.maxAccuracyMeters;
    if (position.accuracy > maxAcc) {
      print('GPS: Position rejected - accuracy too poor: ${position.accuracy}m');
      return false;
    }
    
    // Check for unrealistic speed (more than 50 m/s = 180 km/h) - much stricter
    if (position.speed > GpsConfig.maxSpeedMs) {
      print('GPS: Position rejected - unrealistic speed: ${position.speed}m/s');
      return false;
    }
    
    // Check for unrealistic position changes - much stricter
    if (_lastValidPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastValidPosition!.latitude,
        _lastValidPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      
      // If distance is too large for the time difference, it's likely a GPS error
      final timeDiff = position.timestamp.difference(_lastValidPosition!.timestamp).inSeconds;
      if (timeDiff > 0) {
        // Maximum realistic speed: 50 m/s (180 km/h)
        if (distance / timeDiff > GpsConfig.maxSpeedMs) {
          print('GPS: Position rejected - unrealistic movement: ${distance}m in ${timeDiff}s (${(distance/timeDiff).toStringAsFixed(1)} m/s)');
          return false;
        }
        // Stationary lock gating: keep rejecting tiny drift until clear unlock
        final derivedSpeed = distance / timeDiff; // m/s
        if (_stationaryLocked && _stationaryAnchor != null) {
          final distFromAnchor = Geolocator.distanceBetween(
            _stationaryAnchor!.latitude,
            _stationaryAnchor!.longitude,
            position.latitude,
            position.longitude,
          );
          final bool unlockEligible = distFromAnchor >= GpsConfig.stationaryUnlockDistance || derivedSpeed >= GpsConfig.stationaryUnlockSpeedMs;
          if (unlockEligible) {
            _consecutiveUnlockEligible++;
          } else {
            _consecutiveUnlockEligible = 0;
          }
          if (_consecutiveUnlockEligible < GpsConfig.stationaryUnlockConsecutive) {
            print('GPS: Rejected - stationary lock active (distFromAnchor=${distFromAnchor.toStringAsFixed(2)}m, speed=${derivedSpeed.toStringAsFixed(2)} m/s)');
            return false;
          } else {
            // Unlock and allow this position to pass further checks
            _stationaryLocked = false;
            _stationaryAnchor = null;
            _consecutiveUnlockEligible = 0;
            print('GPS: Stationary lock released');
          }
        }
        // Minimum movement threshold: ignore tiny drift, dynamic based on accuracy
        final double avgAcc = ((_lastValidPosition!.accuracy) + (position.accuracy)) / 2.0;
        final double dynMin = max(
          relaxed ? 0.8 : GpsConfig.minMovementMeters,
          GpsConfig.dynamicMinMoveAccuracyFactor * avgAcc,
        );
        final double minMove = dynMin;
        if (distance < minMove) {
          print('GPS: Position rejected - too small movement: ${distance}m (< $minMove m)');
          return false;
        }
        // Derived speed and acceleration checks
        // Accuracy gating at very low speeds; skip when relaxed
        if (!relaxed) {
          if (derivedSpeed < 0.3 && position.accuracy > GpsConfig.stationaryAccuracyCap) {
            print('GPS: Rejected - stationary but accuracy ${position.accuracy}m worse than ${GpsConfig.stationaryAccuracyCap}m');
            return false;
          }
          if (derivedSpeed < 1.0 && position.accuracy > GpsConfig.slowAccuracyCap) {
            print('GPS: Rejected - slow movement requires <${GpsConfig.slowAccuracyCap}m accuracy (got ${position.accuracy}m)');
            return false;
          }
        }
        // Acceleration spike filter (profile-aware)
        if (_lastDerivedSpeedMs != null) {
          final accel = (derivedSpeed - _lastDerivedSpeedMs!) / timeDiff; // m/s^2
          double accelLimit;
          switch (_currentProfile) {
            case _MotionProfile.stationary:
              accelLimit = GpsConfig.accelStationary; // small bumps only
              break;
            case _MotionProfile.walking:
              accelLimit = GpsConfig.accelWalking;
              break;
            case _MotionProfile.running:
              accelLimit = GpsConfig.accelRunning;
              break;
            case _MotionProfile.driving:
              accelLimit = GpsConfig.accelDriving;
              break;
            default:
              accelLimit = GpsConfig.accelRunning;
          }
          if (accel.abs() > accelLimit) {
            print('GPS: Rejected - acceleration spike ${accel.toStringAsFixed(1)} m/s^2 > ${accelLimit}');
            return false;
          }
        }
        // Update last derived speed for next validation if we accept later
        _lastDerivedSpeedMs = derivedSpeed;
      }
    }
    
    print('GPS: Position accepted - lat: ${position.latitude}, lon: ${position.longitude}, accuracy: ${position.accuracy}m');
    return true;
  }

  // Engage stationary lock after sustained near-zero movement window
  void _maybeEngageStationaryLock(Position current) {
    if (_lastValidPosition == null) return;
    if (_stationaryLocked) return;
    final seconds = current.timestamp.difference(_lastValidPosition!.timestamp).inMilliseconds / 1000.0;
    if (seconds <= 0) return;
    final distance = Geolocator.distanceBetween(
      _lastValidPosition!.latitude,
      _lastValidPosition!.longitude,
      current.latitude,
      current.longitude,
    );
    final derivedSpeed = distance / seconds;
    final double avgAcc = ((_lastValidPosition!.accuracy) + (current.accuracy)) / 2.0;
    final double dynMin = max(
      GpsConfig.minMovementMeters,
      GpsConfig.dynamicMinMoveAccuracyFactor * avgAcc,
    );
    final bool nearZeroMovement = derivedSpeed < GpsConfig.stationarySpeedThresholdMs && distance < dynMin;
    if (nearZeroMovement) {
      _stationaryCandidateSince ??= current.timestamp;
      if (current.timestamp.difference(_stationaryCandidateSince!) >= GpsConfig.stationaryLockWindow) {
        _stationaryLocked = true;
        _stationaryAnchor = current;
        _consecutiveUnlockEligible = 0;
        print('GPS: Stationary lock engaged');
      }
    } else {
      _stationaryCandidateSince = null;
    }
  }
  
  // Add track point with advanced processing
  void _addTrackPoint(Position position) {
    // Calculate heading from movement if available
    double? heading;
    if (_trackPoints.isNotEmpty && position.speed > 0.5) { // Reduced threshold for more sensitive heading
      final lastPoint = _trackPoints.last;
      heading = _calculateHeading(
        lastPoint.latitude, lastPoint.longitude,
        position.latitude, position.longitude,
      );
    }
    
    // Derive speed from distance/time for robustness
    double computedSpeed = 0.0;
    if (_lastValidPosition != null) {
      final seconds = position.timestamp.difference(_lastValidPosition!.timestamp).inMilliseconds / 1000.0;
      if (seconds > 0) {
        final distance = Geolocator.distanceBetween(
          _lastValidPosition!.latitude,
          _lastValidPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        computedSpeed = distance / seconds; // m/s
      }
    }
    // Prefer computed speed when present; otherwise fallback to reported
    double rawSpeed = computedSpeed > 0 ? computedSpeed : (position.speed.isFinite ? position.speed : 0.0);
    // If speedAccuracy is poor, trust computed speed when available
    if (position.speedAccuracy.isFinite && position.speedAccuracy > 1.5 && computedSpeed > 0) {
      rawSpeed = computedSpeed;
    }
    // Apply EMA smoothing and snap small speeds to zero
    final emaSpeed = _lastFilteredSpeed == null
        ? rawSpeed
        : (_emaAlpha * rawSpeed + (1 - _emaAlpha) * _lastFilteredSpeed!);
    _lastFilteredSpeed = emaSpeed;
    final filteredSpeed = emaSpeed < _stationarySpeedThreshold ? 0.0 : emaSpeed;
    
    final trackPoint = TrackPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp,
      speed: filteredSpeed,
      accuracy: position.accuracy,
      heading: heading,
      altitude: position.altitude,
      verticalAccuracy: position.altitudeAccuracy,
    );
    
    _trackPoints.add(trackPoint);
    
    // Update notification
    _updateTrackingNotification();
  }
  
  // Calculate heading between two points in degrees
  double _calculateHeading(double lat1, double lon1, double lat2, double lon2) {
    final dLon = (lon2 - lon1) * (pi / 180);
    final lat1Rad = lat1 * (pi / 180);
    final lat2Rad = lat2 * (pi / 180);
    
    final y = sin(dLon) * cos(lat2Rad);
    final x = cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLon);
    
    var heading = atan2(y, x) * (180 / pi);
    heading = (heading + 360) % 360; // Normalize to 0-360
    
    return heading;
  }
  
  // Update tracking statistics with improved accuracy
  void _updateStatistics(Position position) {
    if (_lastValidPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastValidPosition!.latitude,
        _lastValidPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      
      // Only add distance if it's realistic (not GPS noise)
      final double avgAcc = ((_lastValidPosition!.accuracy) + (position.accuracy)) / 2.0;
      final double dynMin = max(
        GpsConfig.minMovementMeters,
        GpsConfig.dynamicMinMoveAccuracyFactor * avgAcc,
      );
      if (distance >= dynMin) { // Avoid GPS noise with dynamic threshold
        _totalDistance += distance;
        print('GPS: Distance added: ${distance.toStringAsFixed(2)}m, total: ${_totalDistance.toStringAsFixed(2)}m');
      } else {
        print('GPS: Distance too small, ignoring: ${distance.toStringAsFixed(2)}m');
      }
      
      // Update speed statistics using derived speed where possible
      double derivedSpeed = 0.0;
      final seconds = position.timestamp.difference(_lastValidPosition!.timestamp).inMilliseconds / 1000.0;
      if (seconds > 0) {
        derivedSpeed = distance / seconds;
      }
      final candidateSpeed = derivedSpeed > 0 ? derivedSpeed : (position.speed.isFinite ? position.speed : 0.0);
      if (candidateSpeed > 0 && candidateSpeed <= GpsConfig.maxSpeedMs) { // Max cap
        _maxSpeed = max(_maxSpeed, candidateSpeed);
        
        // Calculate average speed
        final totalTime = trackingDuration.inSeconds;
        if (totalTime > 0) {
          _averageSpeed = _totalDistance / totalTime;
        }
      }
      
      // Update elevation statistics
      if (position.altitude != null && _lastValidPosition!.altitude != null) {
        final elevationChange = position.altitude! - _lastValidPosition!.altitude!;
        if (elevationChange > 0) {
          _totalElevationGain += elevationChange;
        } else {
          _totalElevationLoss += elevationChange.abs();
        }
      }
      
      // Update min/max altitude
      if (position.altitude != null) {
        _minAltitude = _minAltitude == null ? position.altitude! : min(_minAltitude!, position.altitude!);
        _maxAltitude = _maxAltitude == null ? position.altitude! : max(_maxAltitude!, position.altitude!);
      }
    }
  }
  
  // Calculate final statistics with improved accuracy
  void _calculateFinalStatistics() {
    if (_trackPoints.length < 2) return;
    
    // Recalculate total distance using all track points with filtering
    _totalDistance = 0.0;
    for (int i = 1; i < _trackPoints.length; i++) {
      final distance = Geolocator.distanceBetween(
        _trackPoints[i - 1].latitude,
        _trackPoints[i - 1].longitude,
        _trackPoints[i].latitude,
        _trackPoints[i].longitude,
      );
      
      // Only add realistic distances (filter out GPS noise)
      if (distance >= GpsConfig.minMovementMeters) {
        _totalDistance += distance;
      }
    }
    
    // Calculate final average speed
    final totalTime = trackingDuration.inSeconds;
    if (totalTime > 0) {
      _averageSpeed = _totalDistance / totalTime;
    }
    
    print('GPS: Final statistics - Total distance: ${_totalDistance.toStringAsFixed(2)}m, Average speed: ${_averageSpeed.toStringAsFixed(2)} m/s');
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
    
    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'gps_tracking',
      'Strakatá turistika',
      description: 'Zobrazuje aktuální stav a statistiky sledování',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );
    
    await _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(androidChannel);
  }
  
  // Show persistent tracking notification
  Future<void> _showTrackingNotification() async {
    // Skip Flutter notification if Android native foreground service is already showing one
    if (Platform.isAndroid && _backgroundServiceRunning) {
      return;
    }
    const androidDetails = AndroidNotificationDetails(
      'gps_tracking',
      'Strakatá turistika',
      channelDescription: 'Zobrazuje aktuální stav a statistiky sledování',
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
    
    await _notifications.show(
      _trackingNotificationId,
      'Strakatá turistika',
      'Klepněte pro zobrazení detailů sledování',
      notificationDetails,
      payload: 'gps_tracking_page',
    );
  }
  
  // Start notification updates
  void _startNotificationUpdates() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_isTracking) {
        _updateTrackingNotification();
      } else {
        timer.cancel();
      }
    });
  }
  
  // Update tracking notification with current stats
  Future<void> _updateTrackingNotification() async {
    if (!_isTracking) return;
    // Skip updates if Android native foreground service is active to avoid duplicates
    if (Platform.isAndroid && _backgroundServiceRunning) {
      return;
    }
    
    final duration = trackingDuration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    final distanceKm = _totalDistance / 1000;
    final speedKmh = _averageSpeed * 3.6; // Convert m/s to km/h
    
    final title = 'Strakatá turistika';
    final body = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} • ${distanceKm.toStringAsFixed(2)} km • ${speedKmh.toStringAsFixed(1)} km/h';
    
    const androidDetails = AndroidNotificationDetails(
      'gps_tracking',
      'Strakatá turistika',
      channelDescription: 'Zobrazuje aktuální stav a statistiky sledování',
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
    
    await _notifications.show(
      _trackingNotificationId,
      title,
      body,
      notificationDetails,
      payload: 'gps_tracking_page',
    );
  }
  
  // Get tracking summary
  TrackingSummary getSummary() {
    return TrackingSummary(
      isTracking: _isTracking,
      startTime: _startTime,
      duration: trackingDuration,
      totalDistance: _totalDistance,
      averageSpeed: _averageSpeed,
      maxSpeed: _maxSpeed,
      totalElevationGain: _totalElevationGain,
      totalElevationLoss: _totalElevationLoss,
      minAltitude: _minAltitude,
      maxAltitude: _maxAltitude,
      trackPoints: _trackPoints,
    );
  }
  
  // Clear tracking data
  void clearData() {
    _trackPoints.clear();
    _rawPositions.clear();
    _filteredPositions.clear();
    _totalDistance = 0.0;
    _averageSpeed = 0.0;
    _maxSpeed = 0.0;
    _totalElevationGain = 0.0;
    _totalElevationLoss = 0.0;
    _minAltitude = null;
    _maxAltitude = null;
    _lastValidPosition = null;
  }
  
  // Dispose resources
  void dispose() {
    _locationEventSubscription?.cancel();
    _periodicLocationTimer?.cancel();
    _backgroundCheckTimer?.cancel();
  }
} 