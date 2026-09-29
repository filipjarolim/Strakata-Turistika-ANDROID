import 'package:flutter_test/flutter_test.dart';
import 'package:strakataturistikaandroidapp/models/tracking_summary.dart';
import 'package:strakataturistikaandroidapp/models/visit_data.dart';
import 'package:strakataturistikaandroidapp/utils/type_converter.dart';
import 'package:strakataturistikaandroidapp/utils/visit_scoring.dart';

TrackingSummary summaryWithMeters(double meters) {
  final t0 = DateTime.utc(2026, 5, 1, 10);
  return TrackingSummary(
    isTracking: false,
    startTime: t0,
    duration: const Duration(hours: 1),
    totalDistance: meters,
    averageSpeed: 1.0,
    maxSpeed: 2.0,
    totalElevationGain: 0,
    totalElevationLoss: 0,
    minAltitude: null,
    maxAltitude: null,
    trackPoints: [
      TrackPoint(
        latitude: 50.0,
        longitude: 14.0,
        timestamp: t0,
        speed: 1,
        accuracy: 5,
      ),
      TrackPoint(
        latitude: 50.01,
        longitude: 14.01,
        timestamp: t0.add(const Duration(hours: 1)),
        speed: 1,
        accuracy: 5,
      ),
    ],
  );
}

VisitData visit({
  double? distanceKm,
  Map<String, dynamic>? extraData,
  Map<String, dynamic>? extraPoints,
  Map<String, dynamic>? route,
  double points = 0,
}) {
  return VisitData(
    id: 'test-1',
    year: 2026,
    visitDate: DateTime.utc(2026, 5, 15),
    createdAt: DateTime.utc(2026, 5, 15),
    state: VisitState.DRAFT,
    points: points,
    visitedPlaces: '',
    photos: const [],
    places: const [],
    distanceKm: distanceKm,
    extraData: extraData,
    extraPoints: extraPoints ?? const {'source': 'screenshot'},
    route: route,
  );
}

void main() {
  group('TypeConverter.toDouble — edge cases', () {
    test('česká čárka a mezery', () {
      expect(TypeConverter.toDouble('12,5'), 12.5);
      expect(TypeConverter.toDouble('  8  '), 8.0);
      expect(TypeConverter.toDouble('8,0'), 8.0);
    });

    test('odmítne neplatné', () {
      expect(TypeConverter.toDouble(''), isNull);
      expect(TypeConverter.toDouble('   '), isNull);
      expect(TypeConverter.toDouble('abc'), isNull);
      expect(TypeConverter.toDouble(null), isNull);
    });
  });

  group('resolveScoringDistanceKm — Marek / screenshot', () {
    test('ruční km jen v extraData jako string', () {
      expect(
        resolveScoringDistanceKm(
          summary: null,
          extraData: {'distance': '11,3', 'source': 'screenshot'},
        ),
        closeTo(11.3, 1e-9),
      );
    });

    test('GPS summary má přednost před extraData', () {
      expect(
        resolveScoringDistanceKm(
          summary: summaryWithMeters(8500),
          extraData: {'distance': '99'},
        ),
        closeTo(8.5, 1e-9),
      );
    });

    test('fallback na extraPoints když extraData prázdné', () {
      expect(
        resolveScoringDistanceKm(
          summary: null,
          extraData: {},
          extraPoints: {'distanceKm': '6,2'},
        ),
        closeTo(6.2, 1e-9),
      );
    });

    test('nula / záporné se přeskočí', () {
      expect(
        resolveScoringDistanceKm(
          summary: null,
          extraData: {'distance': 0, 'distanceKm': -1},
        ),
        isNull,
      );
      expect(
        resolveScoringDistanceKm(
          summary: null,
          extraData: {'distance': '0', 'distanceKm': '7.1'},
        ),
        7.1,
      );
    });

    test('prázdný summary (0 m) neblokuje ruční km', () {
      expect(
        resolveScoringDistanceKm(
          summary: summaryWithMeters(0),
          extraData: {'distance': '4.5'},
        ),
        4.5,
      );
    });
  });

  group('distancePointsForKm + min distance', () {
    test('1 bod / km', () {
      expect(distancePointsForKm(12.4, 1.0), closeTo(12.4, 1e-9));
    });

    test('hranice minima 3.0', () {
      expect(meetsMinDistanceKm(3.0, 3.0), isTrue);
      expect(meetsMinDistanceKm(2.999, 3.0), isFalse);
      expect(meetsMinDistanceKm(null, 3.0), isFalse);
    });

    test('body za km i pod minimem (UI preview); gate je samostatně', () {
      expect(distancePointsForKm(2.5, 1.0), 2.5);
      expect(meetsMinDistanceKm(2.5, 3.0), isFalse);
    });
  });

  group('VisitData — fromMap / resolvedDistanceKm / toMap roundtrip', () {
    test('fromMap čte km jen z extraData (legacy Android upload)', () {
      final v = VisitData.fromMap({
        '_id': 'abc',
        'visitDate': '2026-05-15T10:00:00.000Z',
        'points': '8,5',
        'seasonYear': 2026,
        'state': 'PENDING_REVIEW',
        'extraPoints': {'source': 'screenshot', 'totalPoints': 1},
        'extraData': {'distance': '14,2'},
      });
      expect(v.distanceKm, closeTo(14.2, 1e-9));
      expect(v.points, 8.5);
      expect(v.resolvedDistanceKm, closeTo(14.2, 1e-9));
    });

    test('toMap zapíše distanceKm i když je hodnota jen v extraData', () {
      final v = visit(
        distanceKm: null,
        extraData: {'distance': '9,7'},
        extraPoints: const {'source': 'screenshot'},
      );
      // Simulace starého objektu bez top-level distanceKm.
      expect(v.distanceKm, isNull);
      expect(v.resolvedDistanceKm, closeTo(9.7, 1e-9));

      final map = v.toMap();
      expect(map['distanceKm'], closeTo(9.7, 1e-9));

      final again = VisitData.fromMap(Map<String, dynamic>.from(map));
      expect(again.distanceKm, closeTo(9.7, 1e-9));
    });

    test('top-level distanceKm má prioritu před extraData', () {
      final v = visit(
        distanceKm: 5.5,
        extraData: {'distance': 99},
      );
      expect(v.resolvedDistanceKm, 5.5);
      expect(v.toMap()['distanceKm'], 5.5);
    });

    test('fallback na route.totalDistance v metrech', () {
      final v = visit(
        distanceKm: null,
        extraData: {},
        route: {'totalDistance': 12345, 'source': 'gps_tracking'},
      );
      expect(v.resolvedDistanceKm, closeTo(12.345, 1e-6));
    });

    test('duration z extraData string minut', () {
      final v = VisitData.fromMap({
        '_id': 'd1',
        'visitDate': '2026-05-15T10:00:00.000Z',
        'points': 0,
        'seasonYear': 2026,
        'extraPoints': {'source': 'screenshot'},
        'extraData': {'distance': '5', 'duration': '90'},
      });
      expect(v.resolvedDurationMinutes, 90);
      expect(v.toMap()['durationMinutes'], 90);
    });
  });

  group('end-to-end screenshot scoring scénář', () {
    test('ruční 12,4 km + 1 bod/km', () {
      final km = resolveScoringDistanceKm(
        summary: null,
        extraData: {'distance': '12,4'},
      );
      expect(km, closeTo(12.4, 1e-9));
      expect(meetsMinDistanceKm(km, 3.0), isTrue);
      expect(distancePointsForKm(km, 1.0), closeTo(12.4, 1e-9));

      final saved = visit(
        distanceKm: double.parse(km!.toStringAsFixed(4)),
        extraData: {'distance': km, 'distanceKm': km},
        extraPoints: {'source': 'screenshot', 'distance': km, 'distanceKm': km},
        points: distancePointsForKm(km, 1.0),
      );
      final payload = saved.toMap();
      expect(payload['distanceKm'], closeTo(12.4, 1e-3));
      expect(payload['extraData']['distance'], closeTo(12.4, 1e-3));
      expect(payload['extraPoints']['distance'], closeTo(12.4, 1e-3));
    });
  });

  group('TrackPoint.fromJson — lat/lng aliasy', () {
    test('přijme lat/lng i longitude', () {
      final a = TrackPoint.fromJson({
        'lat': 50.1,
        'lng': 14.2,
        'timestamp': '2026-05-01T10:00:00.000Z',
      });
      expect(a.latitude, 50.1);
      expect(a.longitude, 14.2);

      final b = TrackPoint.fromJson({
        'latitude': 50.2,
        'lon': 14.3,
        'timestamp': 1714557600000,
      });
      expect(b.latitude, 50.2);
      expect(b.longitude, 14.3);
    });
  });

  group('TrackingSummary.fromPersistedRoute', () {
    test('obnoví summary z uložené GPS trasy', () {
      final summary = TrackingSummary.fromPersistedRoute({
        'totalDistance': 5000.0,
        'duration': 3600,
        'averageSpeed': 1.2,
        'trackPoints': [
          {
            'latitude': 50.0,
            'longitude': 14.0,
            'timestamp': '2026-05-01T10:00:00.000Z',
            'speed': 1.0,
            'accuracy': 5.0,
          },
          {
            'latitude': 50.01,
            'longitude': 14.01,
            'timestamp': '2026-05-01T11:00:00.000Z',
            'speed': 1.0,
            'accuracy': 5.0,
          },
        ],
      });
      expect(summary, isNotNull);
      expect(summary!.totalDistance, 5000);
      expect(summary.trackPoints, hasLength(2));
      expect(
        resolveScoringDistanceKm(summary: summary, extraData: {'distance': '1'}),
        5.0,
      );
    });

    test('vrátí null při méně než 2 bodech', () {
      expect(
        TrackingSummary.fromPersistedRoute({
          'totalDistance': 1000,
          'trackPoints': [
            {'latitude': 50.0, 'longitude': 14.0, 'timestamp': '2026-05-01T10:00:00.000Z'},
          ],
        }),
        isNull,
      );
    });
  });
}
