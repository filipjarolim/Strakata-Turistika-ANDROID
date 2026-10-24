import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:strakataturistikaandroidapp/services/enhanced_gps_tracking_service.dart';
import 'package:strakataturistikaandroidapp/services/gps_battery_profile.dart';
import 'package:strakataturistikaandroidapp/services/track_file_parser.dart';

Position _fix({
  required double lat,
  required DateTime time,
  double speed = 1.3,
  double accuracy = 6,
}) {
  return Position(
    latitude: lat,
    longitude: 14.4,
    timestamp: time,
    accuracy: accuracy,
    altitude: 400,
    altitudeAccuracy: 4,
    heading: 0,
    headingAccuracy: 0,
    speed: speed,
    speedAccuracy: 0.4,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GPS baterie na dlouhém výletě', () {
    test('úsporný režim při stání pustí GNSS a prodlouží interval', () {
      final saverStill = androidGpsSettings(
        profile: GpsMotionProfile.stationary,
        saver: true,
      );
      final preciseStill = androidGpsSettings(
        profile: GpsMotionProfile.stationary,
        saver: false,
      );
      expect(saverStill['priority'], 102);
      expect(saverStill['intervalMs'], greaterThanOrEqualTo(20000));
      expect(saverStill['smallestDisplacementM'], greaterThanOrEqualTo(20));
      expect(saverStill['intervalMs'], greaterThan(preciseStill['intervalMs']));
    });

    test('úsporná chůze bere vzorky řidčeji než přesný režim', () {
      final saver = androidGpsSettings(
        profile: GpsMotionProfile.walking,
        saver: true,
      );
      final precise = androidGpsSettings(
        profile: GpsMotionProfile.walking,
        saver: false,
      );
      expect(saver['intervalMs'], greaterThanOrEqualTo(10000));
      expect(saver['smallestDisplacementM'], greaterThanOrEqualTo(8));
      expect(precise['intervalMs'], lessThan(saver['intervalMs']));
      expect(precise['priority'], 100);
    });

    test('běh a auto nenechávají vteřinový interval v úspoře', () {
      final run = androidGpsSettings(
        profile: GpsMotionProfile.running,
        saver: true,
      );
      final drive = androidGpsSettings(
        profile: GpsMotionProfile.driving,
        saver: true,
      );
      expect(run['intervalMs'], greaterThanOrEqualTo(4000));
      expect(drive['intervalMs'], greaterThanOrEqualTo(2000));
      expect(drive['priority'], 100);
    });
  });

  group('GPS záznam přes 4 hodiny', () {
    late EnhancedGPSTrackingService service;
    late DateTime now;

    setUp(() {
      now = DateTime(2026, 10, 24, 8);
      service = EnhancedGPSTrackingService();
      service.testResetState();
      service.testSuppressSideEffects = true;
      service.testClock = () => now;
      service.testBeginTrackingSession(startTime: now);
    });

    test('4 h chůze, 25 min pauza, vzdálenost sedí a čas pauzu nepočítá', () {
      const step = Duration(seconds: 12);
      const latStep = 0.0001348; // ~15 m
      var lat = 50.0;
      var t = now;

      void walk(int steps) {
        for (var i = 0; i < steps; i++) {
          now = t;
          service.onPositionUpdate(_fix(lat: lat, time: t));
          lat += latStep;
          t = t.add(step);
        }
      }

      walk(600); // 2 h
      final pointsAtLunch = service.testTrackPoints.length;
      final distanceAtLunch = service.totalDistance;

      service.setRecordingPaused(true);
      now = t.add(const Duration(minutes: 25));
      service.onPositionUpdate(_fix(lat: lat + 0.01, time: now, speed: 1.4));
      expect(service.testTrackPoints.length, pointsAtLunch);
      expect(service.totalDistance, distanceAtLunch);

      service.setRecordingPaused(false);
      t = now;
      walk(600); // další 2 h

      expect(service.trackingDuration.inMinutes, inInclusiveRange(239, 241));
      expect(service.totalDistance, inInclusiveRange(16000, 20000));
      expect(
        service.totalDistance,
        closeTo(service.testSumFilteredDistance(service.testTrackPoints), 0.05),
      );
      expect(service.testTrackPoints.length, lessThan(2000));
      expect(service.testTrackPoints.length, greaterThan(800));

      final pace = service.totalDistance / service.trackingDuration.inSeconds;
      expect(pace, inInclusiveRange(1.0, 1.6));

      final summary = service.getSummary();
      final stored = routePayloadForStorage(summary);
      expect(stored['totalDistance'], closeTo(service.totalDistance, 0.05));
      expect((stored['trackPoints'] as List).length, lessThanOrEqualTo(1000));
      expect(summary.duration.inMinutes, inInclusiveRange(239, 241));
    });

    test('skok uprostřed čtyřhodinové trasy nepřidá kilometry', () {
      const step = Duration(seconds: 12);
      var lat = 49.5;
      var t = now;
      for (var i = 0; i < 300; i++) {
        now = t;
        service.onPositionUpdate(_fix(lat: lat, time: t));
        lat += 0.0001348;
        t = t.add(step);
      }
      final before = service.totalDistance;

      now = t;
      service.onPositionUpdate(_fix(lat: lat + 0.05, time: t, speed: 1.2));

      for (var i = 0; i < 20; i++) {
        t = t.add(step);
        now = t;
        lat += 0.0001348;
        service.onPositionUpdate(_fix(lat: lat, time: t));
      }

      expect(service.totalDistance, lessThan(before + 800));
      expect(service.trackingDuration.inMinutes, greaterThan(50));
    });
  });
}
