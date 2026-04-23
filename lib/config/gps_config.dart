class GpsConfig {
  // Accuracy thresholds (meters)
  static const double maxAccuracyMeters = 12.0; // strict global cap
  static const double stationaryAccuracyCap = 6.0; // when nearly stationary
  static const double slowAccuracyCap = 8.0; // slow movement

  // Movement thresholds
  static const double minMovementMeters = 2.0; // ignore tiny drift
  static const double maxSpeedMs = 50.0; // unrealistic speed cap
  // Dynamic minimum movement: add fraction of current accuracy to threshold
  static const double dynamicMinMoveAccuracyFactor = 0.5; // e.g., 50% of accuracy

  // Acceleration limits by profile (m/s^2)
  static const double accelStationary = 3.0;
  static const double accelWalking = 4.0;
  static const double accelRunning = 6.0;
  static const double accelDriving = 12.0;

  // Speed smoothing
  static const double stationarySpeedThresholdMs = 0.5; // snap to 0 below this
  static const double emaAlpha = 0.2; // speed EMA

  // Watchdog / recovery
  static const Duration staleUpdateThreshold = Duration(seconds: 12);
  static const Duration periodicUpdateInterval = Duration(seconds: 5);

  // Fast first fix (FFF) bootstrap
  // Allow a looser initial accuracy to show location quickly on weak signal devices
  static const double firstFixRelaxedAccuracyMeters = 120.0;
  // Consider last-known location if not too old
  static const Duration firstFixMaxAge = Duration(minutes: 15);
  // Try a very quick low-accuracy read first, then escalate
  static const Duration firstFixLowAccuracyTimeout = Duration(seconds: 2);
  static const Duration firstFixHighAccuracyTimeout = Duration(seconds: 6);
  // Polling interval before first fix is established
  static const Duration preFirstFixUpdateInterval = Duration(seconds: 2);

  // Stationary lock and hysteresis
  static const Duration stationaryLockWindow = Duration(seconds: 8); // time below speed threshold before lock
  static const double stationaryUnlockDistance = 8.0; // meters away from lock to unlock
  static const double stationaryUnlockSpeedMs = 1.2; // sustained speed to unlock (~4.3 km/h)
  static const int stationaryUnlockConsecutive = 2; // number of consecutive unlock-eligible updates
}


