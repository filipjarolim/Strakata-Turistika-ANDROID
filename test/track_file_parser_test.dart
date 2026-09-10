import 'package:flutter_test/flutter_test.dart';
import 'package:strakataturistikaandroidapp/services/track_file_parser.dart';

void main() {
  group('TrackFileParser - Fixtures', () {
    for (final fixture in kAdminTestTrackFixtures) {
      test('Successfully parses valid fixture ${fixture.label} (${fixture.filename})', () {
        final result = parseTrackFile(fixture.content, fixture.filename);
        expect(result.ok, isTrue, reason: result.message);
        expect(result.points, isNotNull);
        expect(result.points!.length, greaterThanOrEqualTo(2));

        final summary = trackPointsToSummary(result.points!);
        expect(summary.totalDistance, greaterThan(0));
        expect(summary.trackPoints.length, greaterThanOrEqualTo(2));
      });
    }
  });

  group('TrackFileParser - Edge Cases & Error Handling', () {
    test('Rejects empty or whitespace-only content', () {
      final res1 = parseTrackFile('', 'trasa.gpx');
      expect(res1.ok, isFalse);
      expect(res1.message, contains('prázdný'));

      final res2 = parseTrackFile('   \n\t  ', 'trasa.kml');
      expect(res2.ok, isFalse);
      expect(res2.message, contains('prázdný'));
    });

    test('Rejects unsupported file extension', () {
      final res = parseTrackFile('some content', 'trasa.pdf');
      expect(res.ok, isFalse);
      expect(res.message, contains('Nepodporovaný formát'));
    });

    test('Handles corrupted XML in GPX with informative message', () {
      const brokenXml = '<gpx><trk><trkseg><trkpt lat="50.0"';
      final res = parseTrackFile(brokenXml, 'corrupted.gpx');
      expect(res.ok, isFalse);
      expect(res.message, contains('XML chyba'));
    });

    test('Rejects GPX with no trackpoints', () {
      const emptyGpx = '<?xml version="1.0"?><gpx version="1.1"><metadata><name>Test</name></metadata></gpx>';
      final res = parseTrackFile(emptyGpx, 'empty.gpx');
      expect(res.ok, isFalse);
      expect(res.message, contains('GPX soubor neobsahuje žádné trasové body'));
    });

    test('Rejects GPX with only 1 point (at least 2 required)', () {
      const singlePointGpx = '''<?xml version="1.0"?>
<gpx version="1.1">
  <trk><trkseg>
    <trkpt lat="50.0" lon="14.4"></trkpt>
  </trkseg></trk>
</gpx>''';
      final res = parseTrackFile(singlePointGpx, 'single.gpx');
      expect(res.ok, isFalse);
      expect(res.message, contains('alespoň 2 body'));
    });

    test('Filters out invalid lat/lon coordinates in GPX', () {
      const invalidCoordsGpx = '''<?xml version="1.0"?>
<gpx version="1.1">
  <trk><trkseg>
    <trkpt lat="95.0" lon="14.4"></trkpt>
    <trkpt lat="50.0" lon="195.0"></trkpt>
    <trkpt lat="50.0" lon="14.4"></trkpt>
  </trkseg></trk>
</gpx>''';
      final res = parseTrackFile(invalidCoordsGpx, 'invalid.gpx');
      expect(res.ok, isFalse);
      expect(res.message, contains('alespoň 2 body'));
    });

    test('Handles corrupted KML with informative error', () {
      const brokenKml = '<kml><Document><coordinates>14.4,50.0';
      final res = parseTrackFile(brokenKml, 'broken.kml');
      expect(res.ok, isFalse);
      expect(res.message, contains('XML chyba'));
    });

    test('Rejects KML with missing coordinates', () {
      const emptyKml = '<?xml version="1.0"?><kml xmlns="http://www.opengis.net/kml/2.2"><Document></Document></kml>';
      final res = parseTrackFile(emptyKml, 'empty.kml');
      expect(res.ok, isFalse);
      expect(res.message, contains('nebyla nalezena platná trasa'));
    });

    test('Handles corrupted TCX with informative error', () {
      const brokenTcx = '<TrainingCenterDatabase><Activities>';
      final res = parseTrackFile(brokenTcx, 'broken.tcx');
      expect(res.ok, isFalse);
      expect(res.message, contains('XML chyba'));
    });

    test('Handles corrupted GeoJSON', () {
      const brokenJson = '{"type": "LineString", "coordinates": [';
      final res = parseTrackFile(brokenJson, 'broken.geojson');
      expect(res.ok, isFalse);
      expect(res.message, contains('Neplatný JSON formát'));
    });

    test('Handles GeoJSON with no coordinates', () {
      const emptyJson = '{"type": "FeatureCollection", "features": []}';
      final res = parseTrackFile(emptyJson, 'empty.json');
      expect(res.ok, isFalse);
      expect(res.message, contains('neobsahuje platnou geometrii'));
    });

    test('Parses CSV with semicolon delimiters and comma decimals', () {
      const csvCzech = '''lat;lng
50,0500;14,4500
50,0600;14,4600
50,0700;14,4700''';
      final res = parseTrackFile(csvCzech, 'trasa.csv');
      expect(res.ok, isTrue, reason: res.message);
      expect(res.points!.length, 3);
      expect(res.points![0].latitude, closeTo(50.05, 0.001));
      expect(res.points![0].longitude, closeTo(14.45, 0.001));
    });

    test('Rejects CSV with missing lat/lng data', () {
      const badCsv = '''name,age
Petr,25
Jana,30''';
      final res = parseTrackFile(badCsv, 'bad.csv');
      expect(res.ok, isFalse);
      expect(res.message, contains('nebyly nalezeny alespoň 2 platné souřadnice'));
    });
  });
}
