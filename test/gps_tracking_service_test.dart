import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:strakataturistikaandroidapp/models/tracking_summary.dart';
import 'package:strakataturistikaandroidapp/services/enhanced_gps_tracking_service.dart';
import 'package:strakataturistikaandroidapp/utils/gps_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EnhancedGPSTrackingService - Distance Calculation & Filtering', () {
    late EnhancedGPSTrackingService service;

    setUp(() {
      service = EnhancedGPSTrackingService();
      service.testResetState();
    });

    test('sumFilteredDistance returns 0 for empty or single point list', () {
      expect(service.testSumFilteredDistance([]), 0.0);
      expect(
        service.testSumFilteredDistance([
          TrackPoint(
            latitude: 50.0,
            longitude: 14.4,
            timestamp: DateTime.now(),
            speed: 1.0,
            accuracy: 5.0,
          ),
        ]),
        0.0,
      );
    });

    test('sumFilteredDistance accumulates small incremental steps via anchor pattern', () {
      // 1 degree latitude ~ 111,111 meters.
      // 0.0000135 degrees ~ 1.5 meters.
      // Previous faulty logic checked points[i-1] vs points[i] (< 2m threshold)
      // and discarded every single step, resulting in 0m total distance!
      // The fixed anchor logic accumulates until >= 2m threshold is crossed.
      final start = DateTime(2026, 9, 7, 10, 0, 0);
      final List<TrackPoint> points = [];

      // 10 steps of ~1.5m each, spaced 2 seconds apart
      for (int i = 0; i <= 10; i++) {
        points.add(TrackPoint(
          latitude: 50.0 + (i * 0.0000135),
          longitude: 14.4,
          timestamp: start.add(Duration(seconds: i * 2)),
          speed: 0.75,
          accuracy: 4.0,
        ));
      }

      final distance = service.testSumFilteredDistance(points);
      // 10 * 1.5m = 15m. Distance should be between 13m and 17m, definitely > 0!
      expect(distance, greaterThan(12.0));
      expect(distance, lessThan(18.0));
    });

    test('sumFilteredDistance skips teleport jumps without polluting cumulative distance', () {
      final start = DateTime(2026, 9, 7, 10, 0, 0);
      final points = [
        TrackPoint(
          latitude: 50.0,
          longitude: 14.4,
          timestamp: start,
          speed: 1.2,
          accuracy: 4.0,
        ),
        // Normal move: 10m north in 5s (~2 m/s)
        TrackPoint(
          latitude: 50.0001,
          longitude: 14.4,
          timestamp: start.add(const Duration(seconds: 5)),
          speed: 2.0,
          accuracy: 4.0,
        ),
        // Teleport jump: 5000m away in 1s (5000 m/s > 50 m/s maxSpeedMs)
        TrackPoint(
          latitude: 50.05,
          longitude: 14.4,
          timestamp: start.add(const Duration(seconds: 6)),
          speed: 50.0,
          accuracy: 4.0,
        ),
        // Move at the new place: 10m further in 5s
        TrackPoint(
          latitude: 50.0501,
          longitude: 14.4,
          timestamp: start.add(const Duration(seconds: 11)),
          speed: 2.0,
          accuracy: 4.0,
        ),
      ];

      final distance = service.testSumFilteredDistance(points);
      // Only the two valid ~11m segments should count, not the 5000m jump
      expect(distance, lessThan(100.0));
      expect(distance, greaterThan(15.0));
    });
  });

  group('EnhancedGPSTrackingService - Position Validation & Jump Recovery', () {
    late EnhancedGPSTrackingService service;

    setUp(() {
      service = EnhancedGPSTrackingService();
      service.testResetState();
    });

    Position createPos({
      required double lat,
      required double lng,
      required DateTime time,
      double accuracy = 5.0,
      double speed = 1.0,
    }) {
      return Position(
        latitude: lat,
        longitude: lng,
        timestamp: time,
        accuracy: accuracy,
        altitude: 200.0,
        altitudeAccuracy: 5.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: speed,
        speedAccuracy: 0.5,
      );
    }

    test('accepts initial position with reasonable accuracy', () {
      final pos = createPos(
        lat: 50.0,
        lng: 14.4,
        time: DateTime.now(),
        accuracy: 10.0,
      );
      expect(service.testIsValidPosition(pos), isTrue);
    });

    test('rejects position with poor accuracy in normal mode', () {
      // First fix
      final first = createPos(lat: 50.0, lng: 14.4, time: DateTime(2026, 9, 7, 10, 0, 0), accuracy: 5.0);
      service.testIsValidPosition(first);
      // Register it as last valid
      service.onPositionUpdate(first);

      // Now incoming position has 50m accuracy (threshold is 25m)
      final poor = createPos(lat: 50.0001, lng: 14.4, time: DateTime(2026, 9, 7, 10, 0, 5), accuracy: 50.0);
      expect(service.testIsValidPosition(poor), isFalse);
    });

    test('allows start of motion from rest without false acceleration rejection', () {
      final t0 = DateTime(2026, 9, 7, 10, 0, 0);
      final p0 = createPos(lat: 50.0, lng: 14.4, time: t0, speed: 0.0);
      service.onPositionUpdate(p0);

      // Accelerating from 0 to 2.5 m/s in 1 second (derivedSpeed = 2.5 m/s, accel = 2.5 m/s²)
      // Previously, default walking accel threshold (1.8 m/s²) rejected this initial step.
      // Fixed logic allows start from rest when derivedSpeed <= 3.0 m/s.
      final t1 = t0.add(const Duration(seconds: 1));
      // 2.5m at lat 50.0 is ~0.0000225 deg
      final p1 = createPos(lat: 50.0000225, lng: 14.4, time: t1, speed: 2.5);
      expect(service.testIsValidPosition(p1), isTrue);
    });

    test('recovers from GPS jump after 3 consecutive consistent fixes', () {
      final t0 = DateTime(2026, 9, 7, 10, 0, 0);
      final p0 = createPos(lat: 50.0, lng: 14.4, time: t0, speed: 1.0);
      service.onPositionUpdate(p0);

      // Tunnel exit / teleport jump: 500m away in 2s
      final t1 = t0.add(const Duration(seconds: 2));
      final jumpPos1 = createPos(lat: 50.0045, lng: 14.4, time: t1, speed: 1.0, accuracy: 6.0);
      // Attempt 1: rejected as jump candidate
      expect(service.testIsValidPosition(jumpPos1), isFalse);

      // Attempt 2: consistent with attempt 1 (only 3m away from jumpPos1 in 2s)
      final t2 = t1.add(const Duration(seconds: 2));
      final jumpPos2 = createPos(lat: 50.00453, lng: 14.4, time: t2, speed: 1.0, accuracy: 6.0);
      expect(service.testIsValidPosition(jumpPos2), isFalse);

      // Attempt 3: consistent with attempt 2 (3rd consistent fix triggers jump recovery!)
      final t3 = t2.add(const Duration(seconds: 2));
      final jumpPos3 = createPos(lat: 50.00456, lng: 14.4, time: t3, speed: 1.0, accuracy: 6.0);
      expect(service.testIsValidPosition(jumpPos3), isTrue);
    });

    test('stationary lock suppresses small jitter but unlocks on genuine movement', () {
      final t0 = DateTime(2026, 9, 7, 10, 0, 0);
      final anchor = createPos(lat: 50.0, lng: 14.4, time: t0);
      service.onPositionUpdate(anchor);
      service.testSetStationaryLocked(true, anchor);

      // Small jitter: 1.5m away (stationaryUnlockDistance is 15m)
      final t1 = t0.add(const Duration(seconds: 3));
      final jitter = createPos(lat: 50.000013, lng: 14.4, time: t1, speed: 0.3);
      expect(service.testIsValidPosition(jitter), isFalse);

      // Significant movement: 25m away (stationaryUnlockDistance exceeded)
      // Needs consecutive fixes to unlock (stationaryUnlockConsecutive = 2)
      final t2 = t1.add(const Duration(seconds: 3));
      final move1 = createPos(lat: 50.000225, lng: 14.4, time: t2, speed: 2.0);
      // First move fix registers eligibility but may be suppressed until consecutive count met
      service.testIsValidPosition(move1);

      final t3 = t2.add(const Duration(seconds: 2));
      final move2 = createPos(lat: 50.00025, lng: 14.4, time: t3, speed: 2.0);
      final accepted = service.testIsValidPosition(move2);
      expect(accepted, isTrue);
    });
  });

  group('TrackPoint & GpsUtils Models and Utilities', () {
    test('TrackPoint JSON serialization and deserialization', () {
      final now = DateTime(2026, 9, 7, 12, 30, 45);
      final original = TrackPoint(
        latitude: 50.0755,
        longitude: 14.4378,
        timestamp: now,
        speed: 1.4,
        accuracy: 4.5,
        altitude: 250.0,
        heading: 90.0,
        verticalAccuracy: 3.0,
      );

      final json = original.toJson();
      final restored = TrackPoint.fromJson(json);

      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
      expect(restored.speed, original.speed);
      expect(restored.accuracy, original.accuracy);
      expect(restored.altitude, original.altitude);
      expect(restored.heading, original.heading);
      expect(restored.timestamp.toIso8601String(), original.timestamp.toIso8601String());
    });

    test('TrackPoint parses native Android epoch milliseconds timestamp', () {
      final json = {
        'latitude': 50.0,
        'longitude': 14.4,
        'timestamp': 1788780000000, // epoch ms
        'speed': 1.5,
        'accuracy': 3.0,
      };

      final point = TrackPoint.fromJson(json);
      expect(point.latitude, 50.0);
      expect(point.timestamp.millisecondsSinceEpoch, 1788780000000);
    });

    test('GpsUtils calculates accurate distance between points', () {
      // Prague Old Town Square to Charles Bridge ~ 700m
      const p1 = LatLng(50.0875, 14.4211);
      const p2 = LatLng(50.0865, 14.4114);

      final dist = GpsUtils.calculateDistance(p1, p2);
      expect(dist, greaterThan(600.0));
      expect(dist, lessThan(800.0));
    });

    test('GpsUtils headings and formatting', () {
      expect(GpsUtils.getHeadingDirection(0), 'N');
      expect(GpsUtils.getHeadingDirection(90), 'E');
      expect(GpsUtils.getHeadingDirection(180), 'S');
      expect(GpsUtils.getHeadingDirection(270), 'W');
      expect(GpsUtils.getHeadingDirection(45), 'NE');

      expect(GpsUtils.formatDuration(const Duration(seconds: 45)), '45s');
      expect(GpsUtils.formatDuration(const Duration(minutes: 5, seconds: 12)), '5m 12s');
      expect(GpsUtils.formatDuration(const Duration(hours: 2, minutes: 15, seconds: 30)), '2h 15m 30s');
    });
  });
}
