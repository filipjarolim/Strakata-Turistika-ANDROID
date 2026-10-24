/// Jak často a jak přesně má Android žádat GPS. Úsporný režim je výchozí
/// pro výlet na několik hodin: při stání se GNSS nemusí držet naplno.
enum GpsMotionProfile { stationary, walking, running, driving }

/// `priority` 100 = HIGH_ACCURACY, 102 = BALANCED_POWER_ACCURACY.
Map<String, dynamic> androidGpsSettings({
  required GpsMotionProfile profile,
  required bool saver,
}) {
  switch (profile) {
    case GpsMotionProfile.stationary:
      return {
        'intervalMs': saver ? 25000 : 15000,
        'fastestIntervalMs': saver ? 15000 : 8000,
        'maxWaitTimeMs': saver ? 50000 : 25000,
        'smallestDisplacementM': saver ? 25.0 : 12.0,
        'priority': 102,
      };
    case GpsMotionProfile.walking:
      return saver
          ? {
              'intervalMs': 12000,
              'fastestIntervalMs': 8000,
              'maxWaitTimeMs': 24000,
              'smallestDisplacementM': 10.0,
              'priority': 100,
            }
          : {
              'intervalMs': 5000,
              'fastestIntervalMs': 3000,
              'maxWaitTimeMs': 8000,
              'smallestDisplacementM': 4.0,
              'priority': 100,
            };
    case GpsMotionProfile.running:
      return {
        'intervalMs': saver ? 4000 : 2000,
        'fastestIntervalMs': saver ? 2000 : 1000,
        'maxWaitTimeMs': saver ? 8000 : 3000,
        'smallestDisplacementM': 3.0,
        'priority': 100,
      };
    case GpsMotionProfile.driving:
      return {
        'intervalMs': 2000,
        'fastestIntervalMs': 1000,
        'maxWaitTimeMs': 4000,
        'smallestDisplacementM': 8.0,
        'priority': 100,
      };
  }
}
