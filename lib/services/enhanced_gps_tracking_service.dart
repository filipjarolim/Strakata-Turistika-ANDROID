import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../services/haptic_service.dart';

import '../models/tracking_summary.dart';
import '../config/gps_config.dart';
import 'gps_battery_profile.dart';
import 'gps_power_mode.dart';
import 'route_backup_service.dart';
import 'package:sensors_plus/sensors_plus.dart';

enum _MotionProfile { stationary, walking, running, driving }

class EnhancedGPSTrackingService with WidgetsBindingObserver {
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
  /// Kotva pro průběžnou vzdálenost. Celá trasa se znovu nesčítá po každém bodu,
  /// jinak je 4h+ záznam kvadratický a žere CPU i baterii.
  TrackPoint? _distanceAnchor;
  Position? _lastValidPosition;
  double? _lastDerivedSpeedMs;
  bool _hasFirstFix = false;
  DateTime? _lastRawAt;
  DateTime? _lastNativeAt;
  DateTime? _lastAcceptedAt;
  DateTime? _relaxedUntil;
  bool _lifecycleObserverAttached = false;
  
  // Stationary lock / hysteresis to suppress GPS drift when not moving
  bool _stationaryLocked = false;
  Position? _stationaryAnchor;
  DateTime? _stationaryCandidateSince;
  int _consecutiveUnlockEligible = 0;
  int _consecutiveJumpRejections = 0;
  Position? _lastJumpCandidate;
  
  // Kalman filter parameters.
  // Pozn.: původní processNoise 0.05 dával ustálený gain ~0.05 — filtrovaná
  // pozice se téměř nehýbala, řezala zatáčky a měřená vzdálenost vycházela
  // výrazně kratší. Gain ~0.6 stále tlumí šum, ale sleduje skutečný pohyb.
  double _processNoise = 1.0;
  double _measurementNoise = 1.0;
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
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  DateTime? _accelStillSince;
  _MotionProfile? _pendingProfile;
  DateTime? _pendingProfileSince;
  DateTime? _lastNotificationAt;
  
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
  /// Testy dlouhého výletu posouvají čas bez čekání. V aplikaci zůstává nástěnné hodiny.
  @visibleForTesting
  DateTime Function()? testClock;

  DateTime _clockNow() => testClock?.call() ?? DateTime.now();

  Duration get trackingDuration {
    if (_startTime == null) return Duration.zero;
    final wall = _clockNow().difference(_startTime!);
    final currentPause = (_recordingPaused && _pauseStartedAt != null)
        ? _clockNow().difference(_pauseStartedAt!)
        : Duration.zero;
    final active = wall - _pausedBeforeCurrentSegment - currentPause;
    return active.isNegative ? Duration.zero : active;
  }
  List<TrackPoint> get trackPoints => List.unmodifiable(_trackPoints);
  DateTime? get lastNativeAt => _lastNativeAt;
  bool get backgroundServiceRunning => _backgroundServiceRunning;

  Future<bool> isNativeServiceRunning() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _methodChannel.invokeMethod('isGPSTracking');
      return result == true;
    } catch (_) {
      return false;
    }
  }
  
  // Get current heading
  double? get currentHeading {
    if (_trackPoints.length < 2) return null;
    final lastPoint = _trackPoints.last;
    return lastPoint.heading;
  }

  /// Pause or resume recording (time and track points). Does nothing if not tracking.
  void setRecordingPaused(bool paused) {
    if (!_isTracking) return;
    final now = _clockNow();
    if (paused && !_recordingPaused) {
      _recordingPaused = true;
      _pauseStartedAt = now;
      unawaited(_commitMotionProfile(_MotionProfile.stationary, immediate: true));
    } else if (!paused && _recordingPaused) {
      if (_pauseStartedAt != null) {
        _pausedBeforeCurrentSegment += now.difference(_pauseStartedAt!);
      }
      _pauseStartedAt = null;
      _recordingPaused = false;
      unawaited(_commitMotionProfile(_MotionProfile.walking, immediate: true));
    }
  }

  Future<void> applyPowerMode(GpsPowerMode mode) async {
    await GpsPowerModeStore().setMode(mode);
    if (_isTracking) {
      await _applyAdaptiveSettingsForPlatform(
        _currentProfile ?? _MotionProfile.walking,
      );
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
      _appendDistancePoint(trackPoint);
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
    if (!_lifecycleObserverAttached) {
      WidgetsBinding.instance.addObserver(this);
      _lifecycleObserverAttached = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isTracking) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(RouteBackupService().saveBackup(getSummary(), active: true));
    }
    if (state == AppLifecycleState.resumed) {
      // App was paused (screenshot, recents, lock). EventChannel drops
      // events while paused; a second GPS stream would zigzag the track.
      _stopAndroidBackupStream();
      unawaited(_ingestNativeBacklog());
    }
  }
  
  // Setup event channel for receiving location updates from Android service
  Future<void> _setupEventChannel() async {
    if (!Platform.isAndroid) return;

    try {
      _locationEventSubscription = _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is Map) {
            _handleLocationFromService(event);
          }
        },
        onError: (error) {
          print('GPS Event Channel Error: $error');
        },
      );
    } on MissingPluginException catch (e) {
      print('GPS Event Channel unavailable: $e');
    }
  }
  
  // Handle location updates from Android background service
  void _handleLocationFromService(Map<dynamic, dynamic> locationData) {
    if (!_isTracking) return;

    _lastNativeAt = DateTime.now();
    // Native service is alive — never keep a parallel Geolocator stream.
    if (_androidBackupSubscription != null) {
      _stopAndroidBackupStream();
    }

    final lat = locationData['latitude']?.toDouble();
    final lng = locationData['longitude']?.toDouble();
    if (!_isPlausibleCoordinate(lat, lng)) {
      print('GPS: Native point rejected — invalid coordinates ($lat, $lng)');
      return;
    }

    final rawTs = locationData['timestamp'];
    final tsMs = rawTs is num ? rawTs.toInt() : 0;
    final timestamp = tsMs > 100000000000
        ? DateTime.fromMillisecondsSinceEpoch(tsMs)
        : DateTime.now();

    final position = Position(
      latitude: lat!,
      longitude: lng!,
      timestamp: timestamp,
      accuracy: locationData['accuracy']?.toDouble() ?? 0.0,
      altitude: locationData['altitude']?.toDouble() ?? 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: locationData['speed']?.toDouble() ?? 0.0,
      speedAccuracy: 0.0,
    );

    onPositionUpdate(position);
  }

  bool _isPlausibleCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (!lat.isFinite || !lng.isFinite) return false;
    if (lat.abs() < 0.001 && lng.abs() < 0.001) return false;
    if (lat.abs() > 90 || lng.abs() > 180) return false;
    return true;
  }
  
  /// Checks location permission only. Never shows the system dialog here —
  /// runtime requests must go through the in-app Prominent Disclosure first.
  Future<bool> _hasLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('GPS: Location service is not enabled');
      return false;
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      print(
        'GPS: Location permission not granted — UI must request it after disclosure',
      );
      return false;
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }
  
  // Start tracking with enhanced background support
  Future<bool> startTracking() async {
    if (_isTracking) return false;
    
    final hasPermissions = await _hasLocationPermission();
    
    // Provide haptic feedback for tracking start
    await HapticService.trackingStart();
    if (!hasPermissions) {
      print('GPS Tracking failed: No location permissions');
      return false;
    }
    
    await RouteBackupService().beginNewSession();

    _isTracking = true;
    _startTime = DateTime.now();
    _trackPoints.clear();
    _resetDistanceAnchor();
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
    _consecutiveJumpRejections = 0;
    _lastJumpCandidate = null;
    _resetRecordingPauseState();
    await GpsPowerModeStore().load();
    _currentProfile = _MotionProfile.walking;
    _pendingProfile = null;
    _accelStillSince = null;
    
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

    _startMotionSensor();
    
    // Kick off fast-first-fix bootstrap to quickly display user's approximate location
    // This runs fire-and-forget and will relax accuracy thresholds only for the first fix
    // ignore: discarded_futures
    _bootstrapFirstFix();
    // Start reliability watchdog (stale detection, auto-relax, backups)
    _startReliabilityWatchdog();
    
    return true;
  }

  /// Obnoví měření z lokální zálohy po pádu / vybití / kill procesu.
  /// Nativní persist soubor se NEmaže — nové body se připojí za stávající.
  Future<bool> resumeTracking(TrackingSummary summary) async {
    if (_isTracking) return true;

    final hasPermissions = await _hasLocationPermission();
    if (!hasPermissions) {
      print('GPS resume failed: No location permissions');
      return false;
    }

    final backup = RouteBackupService();
    backup.adoptSession(
      startTime: summary.startTime ?? backup.sessionStartTime,
    );
    await GpsPowerModeStore().load();

    _isTracking = true;
    _startTime = summary.startTime ??
        backup.sessionStartTime ??
        (summary.trackPoints.isNotEmpty
            ? summary.trackPoints.first.timestamp
            : DateTime.now());
    _trackPoints = List<TrackPoint>.from(summary.trackPoints);
    _rebuildDistanceFromTrack();
    _averageSpeed = summary.averageSpeed;
    _maxSpeed = summary.maxSpeed;
    _totalElevationGain = summary.totalElevationGain;
    _totalElevationLoss = summary.totalElevationLoss;
    _minAltitude = summary.minAltitude;
    _maxAltitude = summary.maxAltitude;
    _lastDerivedSpeedMs = null;
    _stationaryLocked = false;
    _stationaryAnchor = null;
    _stationaryCandidateSince = null;
    _consecutiveUnlockEligible = 0;
    _consecutiveJumpRejections = 0;
    _lastJumpCandidate = null;
    _resetRecordingPauseState();

    if (_trackPoints.isNotEmpty) {
      final last = _trackPoints.last;
      _lastValidPosition = Position(
        latitude: last.latitude,
        longitude: last.longitude,
        timestamp: last.timestamp,
        accuracy: last.accuracy,
        altitude: last.altitude ?? 0.0,
        altitudeAccuracy: last.verticalAccuracy ?? 0.0,
        heading: last.heading ?? 0.0,
        headingAccuracy: 0.0,
        speed: last.speed,
        speedAccuracy: 0.0,
      );
      _hasFirstFix = true;
      _lastAcceptedAt = last.timestamp;
    } else {
      _lastValidPosition = null;
      _hasFirstFix = false;
    }

    FirebaseCrashlytics.instance.log(
      'Enhanced GPS Tracking resumed (${_trackPoints.length} points)',
    );

    await _startBackgroundService(resetPersist: false);
    await _applyAdaptiveSettingsForPlatform(_MotionProfile.walking);
    _startPeriodicLocationRetrieval();
    _startBackgroundServiceMonitoring();
    if (!(Platform.isAndroid && _backgroundServiceRunning)) {
      await _showTrackingNotification();
      _startNotificationUpdates();
    }
    if (Platform.isIOS) {
      _startOrUpdateIosStream(_MotionProfile.walking);
    }
    _startReliabilityWatchdog();
    _startMotionSensor();
    unawaited(_ingestNativeBacklog());
    unawaited(RouteBackupService().saveBackup(getSummary(), active: true));
    return true;
  }
  
  // Start Android background service
  Future<void> _startBackgroundService({bool resetPersist = true}) async {
    try {
      final result = await _methodChannel.invokeMethod('startGPSTracking', {
        'resetPersist': resetPersist,
      });
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
  
  // Start periodic location retrieval
  void _startPeriodicLocationRetrieval() {
    _periodicLocationTimer?.cancel();
    final initialInterval = _hasFirstFix
        ? GpsConfig.periodicUpdateInterval
        : GpsConfig.preFirstFixUpdateInterval;
    _periodicLocationTimer = Timer.periodic(initialInterval, (timer) async {
      if (_isTracking && !_backgroundServiceRunning) {
        // If background service is not running, get location manually
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
      // Last-known can be kilometres away (cached fix from another day).
      // Never record it as a track point — it would add a huge first segment.
      if (_hasFirstFix) return;

      // 1) Quick low-accuracy read with short timeout
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

      // 2) Escalate to a bounded high-accuracy attempt
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
      if (_recordingPaused) return;
      final now = DateTime.now();
      final staleLimit = (_currentProfile == _MotionProfile.stationary)
          ? GpsConfig.staleUpdateThresholdStationary
          : GpsConfig.staleUpdateThreshold;
      final rawStale = _lastRawAt == null || now.difference(_lastRawAt!) > staleLimit;
      final acceptedStale = _lastAcceptedAt == null || now.difference(_lastAcceptedAt!) > staleLimit;

      if (rawStale) {
        if (Platform.isAndroid) {
          try {
            final isRunning = await _methodChannel.invokeMethod('isGPSTracking');
            _backgroundServiceRunning = isRunning == true;
          } catch (_) {}

          if (_backgroundServiceRunning) {
            // Native service is still tracking. Missing Flutter events usually
            // mean the app is paused — starting a second stream zigzags the
            // route and inflates distance (hundreds of km).
            print('GPS: Watchdog: native service alive, not starting backup stream');
            return;
          }

          print('GPS: Watchdog: native service down, restarting');
          await _startBackgroundService();
          if (!_backgroundServiceRunning) {
            _ensureAndroidBackupStream();
          }
        }
      } else if (acceptedStale) {
        // Raw is coming but filters might be too strict → relax briefly
        _relaxedUntil = now.add(const Duration(seconds: 20));
        print('GPS: Watchdog relaxing filters for 20s due to no accepted positions');
        if (Platform.isAndroid && _currentProfile != null) {
          await _applyAdaptiveSettingsForPlatform(_currentProfile!);
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
    if (_backgroundServiceRunning) return;
    if (_androidBackupSubscription != null) return;
    final settings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
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
    print('GPS: Android backup stream started (native service not running)');
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
    unawaited(RouteBackupService().saveBackup(getSummary(), active: false));
    
    // Stop Android background service
    await _stopBackgroundService();
    
    // Stop timers
    _periodicLocationTimer?.cancel();
    _backgroundCheckTimer?.cancel();
    _stopReliabilityWatchdog();
    _stopMotionSensor();
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
    _lastRawAt = DateTime.now();
    if (_recordingPaused) return;
    if (!_isPlausibleCoordinate(position.latitude, position.longitude)) {
      print('GPS: Position rejected — invalid coordinates');
      return;
    }

    _lastRawAt = DateTime.now();

    // Validate the RAW fix first. Kalman must not smear GPS jumps into the track.
    if (!_isValidPosition(position)) {
      return;
    }

    final filteredPosition = _applyKalmanFilter(position);

    _addTrackPoint(filteredPosition);
    _updateStatistics(filteredPosition);
    _lastValidPosition = filteredPosition;
    if (_trackPoints.length == 2 || _trackPoints.length % 10 == 0) {
      if (!testSuppressSideEffects) {
        unawaited(RouteBackupService().saveBackup(getSummary(), active: true));
      }
    }
    _maybeEngageStationaryLock(filteredPosition);
    if (!_hasFirstFix) {
      _hasFirstFix = true;
      if (_periodicLocationTimer != null) {
        _startPeriodicLocationRetrieval();
      }
    }
    _lastAcceptedAt = DateTime.now();
    if (!testSuppressSideEffects) {
      unawaited(_updateTrackingNotification());
      unawaited(_maybeUpdateAdaptiveSettings(filteredPosition));
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

  Future<void> _maybeUpdateAdaptiveSettings(Position position) async {
    final profile = _selectMotionProfile(
      position.speed.isFinite && position.speed >= 0 ? position.speed : (_lastFilteredSpeed ?? 0.0),
    );
    await _commitMotionProfile(profile);
  }

  Future<void> _commitMotionProfile(
    _MotionProfile profile, {
    bool immediate = false,
  }) async {
    if (_currentProfile == profile) {
      _pendingProfile = null;
      _pendingProfileSince = null;
      return;
    }
    if (!immediate) {
      if (_pendingProfile != profile) {
        _pendingProfile = profile;
        _pendingProfileSince = DateTime.now();
        return;
      }
      final dwell = profile == _MotionProfile.stationary
          ? GpsConfig.motionProfileStationaryDwell
          : GpsConfig.motionProfileMovingDwell;
      if (_pendingProfileSince == null ||
          DateTime.now().difference(_pendingProfileSince!) < dwell) {
        return;
      }
    }
    _currentProfile = profile;
    _pendingProfile = null;
    _pendingProfileSince = null;
    print('GPS: Motion profile → $profile');
    await _applyAdaptiveSettingsForPlatform(profile);
  }

  Future<void> _applyAdaptiveSettingsForPlatform(_MotionProfile profile) async {
    // Android: push settings to foreground service
    if (Platform.isAndroid) {
      try {
        final settings = _androidSettingsFor(profile);
        await _methodChannel.invokeMethod('updateGPSSettings', settings);
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
    final saver = GpsPowerModeStore().mode != GpsPowerMode.precise;
    final motion = switch (profile) {
      _MotionProfile.stationary => GpsMotionProfile.stationary,
      _MotionProfile.walking => GpsMotionProfile.walking,
      _MotionProfile.running => GpsMotionProfile.running,
      _MotionProfile.driving => GpsMotionProfile.driving,
    };
    return androidGpsSettings(profile: motion, saver: saver);
  }

  void _startOrUpdateIosStream(_MotionProfile profile) {
    int distanceFilter;
    LocationAccuracy accuracy;
    final saver = GpsPowerModeStore().mode != GpsPowerMode.precise;
    switch (profile) {
      case _MotionProfile.stationary:
        distanceFilter = saver ? 20 : 10;
        accuracy = LocationAccuracy.medium;
        break;
      case _MotionProfile.walking:
        distanceFilter = saver ? 10 : 5;
        accuracy = LocationAccuracy.best;
        break;
      case _MotionProfile.running:
        distanceFilter = 3;
        accuracy = LocationAccuracy.best;
        break;
      case _MotionProfile.driving:
        distanceFilter = 8;
        accuracy = LocationAccuracy.best;
        break;
    }
    final settings = AppleSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
      activityType: ActivityType.fitness,
      pauseLocationUpdatesAutomatically: profile == _MotionProfile.stationary,
      allowBackgroundLocationUpdates: true,
      showBackgroundLocationIndicator: true,
    );
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

  void _startMotionSensor() {
    _stopMotionSensor();
    try {
      _accelSub = userAccelerometerEventStream(
        samplingPeriod: SensorInterval.normalInterval,
      ).listen(_onUserAccel, onError: (_) {
        _stopMotionSensor();
      });
    } catch (_) {}
  }

  void _stopMotionSensor() {
    _accelSub?.cancel();
    _accelSub = null;
    _accelStillSince = null;
  }

  void _onUserAccel(UserAccelerometerEvent event) {
    if (!_isTracking || _recordingPaused) return;
    final mag = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    if (mag < GpsConfig.accelRestMagnitude) {
      _accelStillSince ??= DateTime.now();
      if (DateTime.now().difference(_accelStillSince!) >=
              GpsConfig.accelRestToStationary &&
          _currentProfile != _MotionProfile.stationary) {
        unawaited(_commitMotionProfile(_MotionProfile.stationary, immediate: true));
      }
    } else {
      _accelStillSince = null;
      if (mag > GpsConfig.accelWalkingMagnitude &&
          _currentProfile == _MotionProfile.stationary) {
        unawaited(_commitMotionProfile(_MotionProfile.walking, immediate: true));
      }
    }
  }
  
  // Predict next position based on current speed and heading
  Position _predictPosition(Position current) {
    // Android služba posílá heading vždy 0.0 — predikce by pak posouvala bod
    // na sever a znehodnotila filtr. Bez věrohodného headingu nepredikujeme.
    if (current.speed <= 0 ||
        current.heading == 0.0 ||
        !current.headingAccuracy.isFinite ||
        current.headingAccuracy <= 0) {
      return current;
    }
    
    const earthRadius = 6371000.0; // meters
    final distance = current.speed * 1.0; // 1 second prediction
    
    final lat1 = current.latitude * pi / 180;
    final lng1 = current.longitude * pi / 180;
    final bearing = current.heading * pi / 180;
    
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
    final bool relaxed = !_hasFirstFix || _inRelaxedMode();
    final maxAcc = relaxed ? GpsConfig.firstFixRelaxedAccuracyMeters : GpsConfig.maxAccuracyMeters;
    if (position.accuracy > maxAcc) {
      print('GPS: Position rejected - accuracy too poor: ${position.accuracy}m');
      return false;
    }

    if (position.speed > GpsConfig.maxSpeedMs) {
      print('GPS: Position rejected - unrealistic speed: ${position.speed}m/s');
      return false;
    }

    if (_lastValidPosition == null) {
      print('GPS: Position accepted - lat: ${position.latitude}, lon: ${position.longitude}, accuracy: ${position.accuracy}m');
      return true;
    }

    final distance = Geolocator.distanceBetween(
      _lastValidPosition!.latitude,
      _lastValidPosition!.longitude,
      position.latitude,
      position.longitude,
    );

    final dtMs = position.timestamp
        .difference(_lastValidPosition!.timestamp)
        .inMilliseconds;
    if (dtMs <= GpsConfig.minSampleIntervalMs) {
      print('GPS: Position rejected — duplicate/too soon (${dtMs}ms, ${distance.toStringAsFixed(1)}m)');
      return false;
    }

    final dtSec = dtMs / 1000.0;
    final derivedSpeed = distance / dtSec;

    // Determine max jump speed: if driving profile or reported speed is fast (>8 m/s), allow up to maxSpeedMs (50 m/s)
    final isFastProfile = _currentProfile == _MotionProfile.driving || (position.speed.isFinite && position.speed > 8.0);
    final effectiveMaxJump = isFastProfile ? GpsConfig.maxSpeedMs : GpsConfig.maxJumpSpeedMs;

    if (derivedSpeed > effectiveMaxJump) {
      // Check for legitimate relocation after signal loss/tunnel or fast transit:
      // If fixes have plausible accuracy (<= 25m) and are consistent across consecutive updates, or after a long gap (> 25s):
      final bool goodAccuracy = position.accuracy <= 25.0;
      if (goodAccuracy && _lastJumpCandidate != null) {
        final distBetweenCandidates = Geolocator.distanceBetween(
          _lastJumpCandidate!.latitude,
          _lastJumpCandidate!.longitude,
          position.latitude,
          position.longitude,
        );
        final dtBetweenCandidates = position.timestamp
            .difference(_lastJumpCandidate!.timestamp)
            .inMilliseconds / 1000.0;
        final speedBetweenCandidates = dtBetweenCandidates > 0
            ? distBetweenCandidates / dtBetweenCandidates
            : 0.0;
        if (speedBetweenCandidates <= GpsConfig.maxSpeedMs) {
          _consecutiveJumpRejections++;
        } else {
          _consecutiveJumpRejections = 1;
        }
      } else {
        _consecutiveJumpRejections = 1;
      }
      _lastJumpCandidate = position;

      // If at least 3 consecutive fixes agree on the new location or time gap is large (>25s) with good accuracy:
      // Break out of the jump trap and accept as a new anchor
      if (goodAccuracy && (_consecutiveJumpRejections >= 3 || dtSec > 25.0)) {
        print('GPS: Jump recovery triggered after ${_consecutiveJumpRejections} consistent fixes / gap ${dtSec.toStringAsFixed(1)}s');
        _consecutiveJumpRejections = 0;
        _lastJumpCandidate = null;
        _lastDerivedSpeedMs = null;
        _stationaryLocked = false;
        _stationaryAnchor = null;
      } else {
        print(
          'GPS: Position rejected — GPS jump ${distance.toStringAsFixed(1)}m in ${dtSec.toStringAsFixed(2)}s '
          '(${derivedSpeed.toStringAsFixed(1)} m/s > ${effectiveMaxJump.toStringAsFixed(1)}) [attempt $_consecutiveJumpRejections]',
        );
        return false;
      }
    } else {
      _consecutiveJumpRejections = 0;
      _lastJumpCandidate = null;
    }

    if (_stationaryLocked && _stationaryAnchor != null) {
      final distFromAnchor = Geolocator.distanceBetween(
        _stationaryAnchor!.latitude,
        _stationaryAnchor!.longitude,
        position.latitude,
        position.longitude,
      );
      final bool unlockEligible = distFromAnchor >= GpsConfig.stationaryUnlockDistance ||
          derivedSpeed >= GpsConfig.stationaryUnlockSpeedMs;
      if (unlockEligible) {
        _consecutiveUnlockEligible++;
      } else {
        _consecutiveUnlockEligible = 0;
      }
      if (_consecutiveUnlockEligible < GpsConfig.stationaryUnlockConsecutive) {
        print('GPS: Rejected - stationary lock active (distFromAnchor=${distFromAnchor.toStringAsFixed(2)}m, speed=${derivedSpeed.toStringAsFixed(2)} m/s)');
        return false;
      }
      _stationaryLocked = false;
      _stationaryAnchor = null;
      _consecutiveUnlockEligible = 0;
      print('GPS: Stationary lock released');
    }

    final double avgAcc = ((_lastValidPosition!.accuracy) + (position.accuracy)) / 2.0;
    final double dynMin = max(
      relaxed ? 0.8 : GpsConfig.minMovementMeters,
      min(GpsConfig.dynamicMinMoveCapMeters,
          GpsConfig.dynamicMinMoveAccuracyFactor * avgAcc),
    );
    if (distance < dynMin) {
      print('GPS: Position rejected - too small movement: ${distance}m (< $dynMin m)');
      return false;
    }

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

    if (_lastDerivedSpeedMs != null && !relaxed) {
      final accel = (derivedSpeed - _lastDerivedSpeedMs!) / dtSec;
      // Never reject initial movement from rest / slow pace (< 3.0 m/s / ~11 km/h)
      if (derivedSpeed > 3.0 || _lastDerivedSpeedMs! > 3.0) {
        double accelLimit;
        switch (_currentProfile) {
          case _MotionProfile.stationary:
            accelLimit = GpsConfig.accelStationary;
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
          print('GPS: Rejected - acceleration spike ${accel.toStringAsFixed(1)} m/s^2 > $accelLimit');
          return false;
        }
      }
    }
    _lastDerivedSpeedMs = derivedSpeed;

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
      min(GpsConfig.dynamicMinMoveCapMeters,
          GpsConfig.dynamicMinMoveAccuracyFactor * avgAcc),
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
    // Prefer computed speed when present; otherwise use reported speed
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
    _appendDistancePoint(trackPoint);
    
    // Update notification
    if (!testSuppressSideEffects) {
      unawaited(_updateTrackingNotification());
    }
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

      if (_trackPoints.length >= 2 && distance >= GpsConfig.minMovementMeters) {
        print(
          'GPS: Distance ${_totalDistance.toStringAsFixed(2)}m '
          '(step ${distance.toStringAsFixed(2)}m)',
        );
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
      final elevationChange = position.altitude - _lastValidPosition!.altitude;
      if (elevationChange > 0) {
        _totalElevationGain += elevationChange;
      } else {
        _totalElevationLoss += elevationChange.abs();
      }
      
      // Update min/max altitude
      _minAltitude = _minAltitude == null ? position.altitude : min(_minAltitude!, position.altitude);
      _maxAltitude = _maxAltitude == null ? position.altitude : max(_maxAltitude!, position.altitude);
    }
  }

  void _resetDistanceAnchor() {
    _distanceAnchor = null;
  }

  /// Stejná pravidla jako [_sumFilteredDistance], ale jen pro nový bod.
  void _appendDistancePoint(TrackPoint current) {
    final anchor = _distanceAnchor;
    if (anchor == null) {
      _distanceAnchor = current;
      return;
    }
    final distance = Geolocator.distanceBetween(
      anchor.latitude,
      anchor.longitude,
      current.latitude,
      current.longitude,
    );
    if (distance < GpsConfig.minMovementMeters) return;

    final dtMs = current.timestamp.difference(anchor.timestamp).inMilliseconds;
    final speed = dtMs > 0 ? distance / (dtMs / 1000.0) : double.infinity;
    if (speed > GpsConfig.maxSpeedMs) {
      _distanceAnchor = current;
      return;
    }
    _totalDistance += distance;
    _distanceAnchor = current;
  }

  void _rebuildDistanceFromTrack() {
    _distanceAnchor = null;
    _totalDistance = 0;
    for (final point in _trackPoints) {
      _appendDistancePoint(point);
    }
  }

  double _sumFilteredDistance(List<TrackPoint> points) {
    if (points.length < 2) return 0;
    double total = 0;
    TrackPoint anchor = points.first;
    for (int i = 1; i < points.length; i++) {
      final current = points[i];
      final distance = Geolocator.distanceBetween(
        anchor.latitude,
        anchor.longitude,
        current.latitude,
        current.longitude,
      );
      if (distance < GpsConfig.minMovementMeters) continue;

      final dtMs = current.timestamp.difference(anchor.timestamp).inMilliseconds;
      final speed = dtMs > 0 ? distance / (dtMs / 1000.0) : double.infinity;
      // Skip teleport jumps without polluting cumulative distance
      if (speed > GpsConfig.maxSpeedMs) {
        anchor = current;
        continue;
      }
      total += distance;
      anchor = current;
    }
    return total;
  }

  @visibleForTesting
  double testSumFilteredDistance(List<TrackPoint> points) => _sumFilteredDistance(points);

  @visibleForTesting
  bool testIsValidPosition(Position position) => _isValidPosition(position);

  @visibleForTesting
  void testResetState() {
    _isTracking = false;
    _startTime = null;
    _lastValidPosition = null;
    _lastDerivedSpeedMs = null;
    _hasFirstFix = false;
    _stationaryLocked = false;
    _stationaryAnchor = null;
    _consecutiveJumpRejections = 0;
    _lastJumpCandidate = null;
    _trackPoints.clear();
    _resetDistanceAnchor();
    _totalDistance = 0.0;
    _resetRecordingPauseState();
  }

  @visibleForTesting
  void testSetStationaryLocked(bool locked, Position? anchor) {
    _stationaryLocked = locked;
    _stationaryAnchor = anchor;
  }

  /// Starts an in-memory tracking session without platform GPS / permissions.
  @visibleForTesting
  void testBeginTrackingSession({DateTime? startTime}) {
    _isTracking = true;
    _startTime = startTime ?? DateTime.now();
    _trackPoints.clear();
    _resetDistanceAnchor();
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
    _consecutiveJumpRejections = 0;
    _lastJumpCandidate = null;
    _hasFirstFix = false;
    _resetRecordingPauseState();
    _currentProfile = _MotionProfile.walking;
  }

  @visibleForTesting
  bool get testRecordingPaused => _recordingPaused;

  @visibleForTesting
  List<TrackPoint> get testTrackPoints => List.unmodifiable(_trackPoints);

  /// Skip notifications / backups / adaptive platform calls during unit tests.
  @visibleForTesting
  bool testSuppressSideEffects = false;

  // Calculate final statistics with improved accuracy
  void _calculateFinalStatistics() {
    if (_trackPoints.length < 2) return;

    _totalDistance = _sumFilteredDistance(_trackPoints);

    final totalTime = trackingDuration.inSeconds;
    if (totalTime > 0) {
      _averageSpeed = _totalDistance / totalTime;
    }

    print('GPS: Final statistics - Total distance: ${_totalDistance.toStringAsFixed(2)}m, Average speed: ${_averageSpeed.toStringAsFixed(2)} m/s');
  }

  Future<void> _ingestNativeBacklog() async {
    if (!Platform.isAndroid || !_isTracking) return;
    try {
      final raw = await _methodChannel.invokeMethod<List<dynamic>>('readPersistedTrack');
      if (raw == null || raw.isEmpty) return;
      final lastTs = _trackPoints.isEmpty ? null : _trackPoints.last.timestamp;
      var ingested = 0;
      for (final e in raw) {
        if (e is! Map) continue;
        final map = Map<dynamic, dynamic>.from(e);
        final tsMs = (map['timestamp'] as num?)?.toInt() ?? 0;
        if (tsMs <= 0) continue;
        final ts = DateTime.fromMillisecondsSinceEpoch(tsMs);
        if (lastTs != null && !ts.isAfter(lastTs)) continue;
        final lat = (map['latitude'] as num?)?.toDouble();
        final lng = (map['longitude'] as num?)?.toDouble();
        if (!_isPlausibleCoordinate(lat, lng)) continue;
        onPositionUpdate(
          Position(
            latitude: lat!,
            longitude: lng!,
            timestamp: ts,
            accuracy: (map['accuracy'] as num?)?.toDouble() ?? 25.0,
            altitude: (map['altitude'] as num?)?.toDouble() ?? 0.0,
            altitudeAccuracy: 0.0,
            heading: 0.0,
            headingAccuracy: 0.0,
            speed: (map['speed'] as num?)?.toDouble() ?? 0.0,
            speedAccuracy: 0.0,
          ),
        );
        ingested++;
      }
      if (ingested > 0) {
        print('GPS: Ingested $ingested native backlog points after resume');
        _totalDistance = _sumFilteredDistance(_trackPoints);
      }
    } catch (e) {
      print('GPS: Native backlog ingest failed: $e');
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
    final now = DateTime.now();
    if (_lastNotificationAt != null &&
        now.difference(_lastNotificationAt!) < const Duration(seconds: 15)) {
      return;
    }
    _lastNotificationAt = now;

    final duration = trackingDuration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    final distanceKm = _totalDistance / 1000;
    final body =
        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} • ${distanceKm.toStringAsFixed(2)} km';

    if (Platform.isAndroid && _backgroundServiceRunning) {
      try {
        await _methodChannel.invokeMethod('updateTrackingStats', {
          'title': 'Sledování trasy',
          'text': body,
        });
      } catch (e) {
        print('GPS: Failed to update native notification: $e');
      }
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

    try {
      await _notifications.show(
        _trackingNotificationId,
        'Strakatá turistika',
        body,
        notificationDetails,
        payload: 'gps_tracking_page',
      );
    } catch (e) {
      print('GPS: Failed to update local notification: $e');
    }
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
    _resetDistanceAnchor();
    _totalDistance = 0.0;
    _averageSpeed = 0.0;
    _maxSpeed = 0.0;
    _totalElevationGain = 0.0;
    _totalElevationLoss = 0.0;
    _minAltitude = null;
    _maxAltitude = null;
    _lastValidPosition = null;
    _consecutiveJumpRejections = 0;
    _lastJumpCandidate = null;
  }
  
  // Dispose resources
  void dispose() {
    if (_lifecycleObserverAttached) {
      WidgetsBinding.instance.removeObserver(this);
      _lifecycleObserverAttached = false;
    }
    _locationEventSubscription?.cancel();
    _periodicLocationTimer?.cancel();
    _backgroundCheckTimer?.cancel();
    _stopMotionSensor();
  }
} 