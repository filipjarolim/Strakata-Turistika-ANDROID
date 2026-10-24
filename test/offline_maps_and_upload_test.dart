import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:strakataturistikaandroidapp/models/place_type_config.dart';
import 'package:strakataturistikaandroidapp/models/tracking_summary.dart';
import 'package:strakataturistikaandroidapp/models/visit_data.dart';
import 'package:strakataturistikaandroidapp/services/auth_service.dart';
import 'package:strakataturistikaandroidapp/services/mapy_cz_download_service.dart';
import 'package:strakataturistikaandroidapp/services/scoring_config_service.dart';
import 'package:strakataturistikaandroidapp/services/vector_tile_provider.dart';
import 'package:strakataturistikaandroidapp/utils/visit_submit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('nahrání záznamu', () {
    final user = User(
      id: 'user-1',
      email: 'walker@example.com',
      name: 'Walker',
      isOAuth: true,
      provider: 'google',
      providerAccountId: 'sub',
    );
    final scoring = ScoringConfig(
      id: 's',
      pointsPerKm: 1,
      minDistanceKm: 3,
      requireAtLeastOnePlace: false,
      placeTypePoints: const {},
      active: true,
      updatedAt: DateTime(2026, 1, 1),
    );
    final start = DateTime(2026, 8, 8, 9);
    final track = TrackingSummary(
      isTracking: false,
      startTime: start,
      duration: const Duration(minutes: 50),
      totalDistance: 5200,
      averageSpeed: 1.2,
      maxSpeed: 1.8,
      totalElevationGain: 40,
      totalElevationLoss: 10,
      minAltitude: 300,
      maxAltitude: 420,
      trackPoints: [
        TrackPoint(
          latitude: 50.0,
          longitude: 14.4,
          timestamp: start,
          speed: 1.2,
          accuracy: 5,
        ),
        TrackPoint(
          latitude: 50.04,
          longitude: 14.45,
          timestamp: start.add(const Duration(minutes: 50)),
          speed: 1.2,
          accuracy: 5,
        ),
      ],
    );

    VisitData save(String slug, {TrackingSummary? summary, List<Map<String, dynamic>>? photos, Map<String, dynamic> extra = const {}}) {
      return buildPendingVisit(
        slug: slug,
        user: user,
        visitDate: start,
        routeTitle: 'Výlet',
        routeDescription: '',
        dogNotAllowed: false,
        extraData: extra,
        places: const [],
        summary: summary,
        scoring: scoring,
        placeTypes: const <PlaceTypeConfig>[],
        photos: photos,
      );
    }

    test('GPS, GPX i screenshot jdou k revizi pod přihlášeným uživatelem', () {
      final gps = save('gps-tracking', summary: track);
      final gpx = save('gpx-upload', summary: track);
      final shot = save(
        'screenshot-upload',
        extra: {'distanceKm': '6,2'},
        photos: [
          {'url': 'https://cdn.example/map.jpg'},
        ],
      );

      expect(gps.userId, 'user-1');
      expect(gps.state, VisitState.PENDING_REVIEW);
      expect(gps.formSlug, 'gps-tracking');
      expect(gps.route?['totalDistance'], 5200);
      expect(gps.points, closeTo(5.2, 0.01));

      expect(gpx.extraPoints['source'], 'gpx_upload');
      expect(gpx.formSlug, 'gpx-upload');
      expect(gpx.routeLink, contains('50.0'));

      expect(shot.extraPoints['source'], 'screenshot');
      expect(shot.distanceKm, closeTo(6.2, 0.01));
      expect(shot.photos, hasLength(1));
      expect(shot.route, isNull);
    });

    test('bez trasy nebo bez fotky se záznam neodešle', () {
      expect(
        () => save('gps-tracking'),
        throwsA(predicate((e) => e.toString().contains('GPS/GPX'))),
      );
      expect(
        () => save('gpx-upload', summary: null),
        throwsA(predicate((e) => e.toString().contains('GPS/GPX'))),
      );
      expect(
        () => save('screenshot-upload', extra: {'distanceKm': 4}),
        throwsA(predicate((e) => e.toString().contains('screenshot'))),
      );
    });
  });

  group('offline mapy', () {
    test('dlaždice se uloží, načte a po měsíci pořád jde vykreslit', () {
      final raw = Uint8List.fromList(List<int>.generate(64, (i) => i + 1));
      final stored = VectorTileData.compress(raw, 'base');
      expect(stored.decompress(), raw);
      expect(stored.isValid, isTrue);
      expect(bytesFromCachedTile(stored), raw);

      final stale = VectorTileData(
        compressedData: stored.compressedData,
        layer: 'base',
        timestamp: DateTime.now().subtract(const Duration(days: 45)),
        originalSize: stored.originalSize,
        compressedSize: stored.compressedSize,
        hash: stored.hash,
      );
      expect(stale.isValid, isFalse);
      expect(bytesFromCachedTile(stale), raw);
      expect(bytesFromCachedTile(null), isNull);
    });

    test('podrobné stažení bere každou dlaždici, ne jen každou n-tou', () {
      expect(MapyCzDownloadService.tileStepForZoom(12), 1);
      expect(MapyCzDownloadService.tileStepForZoom(15), 1);
      expect(MapyCzDownloadService.tileStepForZoom(18), 1);
    });
  });
}
