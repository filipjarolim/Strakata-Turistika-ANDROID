import 'package:flutter_test/flutter_test.dart';
import 'package:strakataturistikaandroidapp/utils/visit_scoring.dart';

void main() {
  group('resolveScoringDistanceKm', () {
    test('uses manual extraData distance when summary is null (screenshot path)', () {
      final km = resolveScoringDistanceKm(
        summary: null,
        extraData: {'distance': '3.00'},
      );
      expect(km, 3.0);
    });

    test('uses distanceKm key and Czech decimal comma', () {
      final km = resolveScoringDistanceKm(
        summary: null,
        extraData: {'distanceKm': '3,5'},
      );
      expect(km, 3.5);
    });

    test('returns null when no distance provided', () {
      expect(resolveScoringDistanceKm(summary: null, extraData: {}), isNull);
      expect(resolveScoringDistanceKm(summary: null, extraData: null), isNull);
    });
  });

  group('distancePointsForKm', () {
    test('multiplies km by pointsPerKm', () {
      expect(distancePointsForKm(3.0, 2.0), 6.0);
    });

    test('returns 0 for missing distance', () {
      expect(distancePointsForKm(null, 2.0), 0.0);
    });
  });

  group('meetsMinDistanceKm', () {
    test('exact boundary passes', () {
      expect(meetsMinDistanceKm(3.0, 3.0), isTrue);
      expect(meetsMinDistanceKm(2.99, 3.0), isFalse);
    });
  });
}
