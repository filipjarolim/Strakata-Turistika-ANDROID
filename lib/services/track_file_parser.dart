import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

import '../models/tracking_summary.dart';

const int _maxPoints = 1000;

/// Stejné fixture jako `lib/visits/parse-track-file.ts` (ADMIN_TEST_TRACK_FILES).
class AdminTestTrackFixture {
  final String id;
  final String label;
  final String filename;
  final String mime;
  final String content;

  const AdminTestTrackFixture({
    required this.id,
    required this.label,
    required this.filename,
    required this.mime,
    required this.content,
  });
}

const List<AdminTestTrackFixture> kAdminTestTrackFixtures = [
  AdminTestTrackFixture(
    id: 'gpx',
    label: 'GPX',
    filename: 'test-admin-trasa.gpx',
    mime: 'application/gpx+xml',
    content: '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Admin Test">
  <trk><trkseg>
    <trkpt lat="50.0000000" lon="14.4650000"></trkpt>
    <trkpt lat="50.0450000" lon="14.4650000"></trkpt>
    <trkpt lat="50.0900000" lon="14.4650000"></trkpt>
  </trkseg></trk>
</gpx>''',
  ),
  AdminTestTrackFixture(
    id: 'kml',
    label: 'KML',
    filename: 'test-admin-trasa.kml',
    mime: 'application/vnd.google-earth.kml+xml',
    content: '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"><Document><Placemark><LineString><coordinates>
14.465,50.0 14.465,50.045 14.465,50.09
</coordinates></LineString></Placemark></Document></kml>''',
  ),
  AdminTestTrackFixture(
    id: 'tcx',
    label: 'TCX',
    filename: 'test-admin-trasa.tcx',
    mime: 'application/vnd.garmin.tcx+xml',
    content: '''<?xml version="1.0" encoding="UTF-8"?>
<TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">
  <Activities><Activity Sport="Walking"><Lap><Track>
    <Trackpoint><Position><LatitudeDegrees>50.0</LatitudeDegrees><LongitudeDegrees>14.465</LongitudeDegrees></Position></Trackpoint>
    <Trackpoint><Position><LatitudeDegrees>50.045</LatitudeDegrees><LongitudeDegrees>14.465</LongitudeDegrees></Position></Trackpoint>
    <Trackpoint><Position><LatitudeDegrees>50.09</LatitudeDegrees><LongitudeDegrees>14.465</LongitudeDegrees></Position></Trackpoint>
  </Track></Lap></Activity></Activities>
</TrainingCenterDatabase>''',
  ),
  AdminTestTrackFixture(
    id: 'geojson',
    label: 'GeoJSON',
    filename: 'test-admin-trasa.geojson',
    mime: 'application/geo+json',
    content: '{"type":"LineString","coordinates":[[14.465,50.0],[14.465,50.045],[14.465,50.09]]}',
  ),
  AdminTestTrackFixture(
    id: 'csv',
    label: 'CSV',
    filename: 'test-admin-trasa.csv',
    mime: 'text/csv',
    content: '''lat,lng
50.0,14.465
50.045,14.465
50.09,14.465''',
  ),
];

class TrackParseResult {
  final bool ok;
  final String? message;
  final List<TrackPoint>? points;

  const TrackParseResult._({required this.ok, this.message, this.points});

  factory TrackParseResult.success(List<TrackPoint> points) =>
      TrackParseResult._(ok: true, points: points);

  factory TrackParseResult.error(String message) =>
      TrackParseResult._(ok: false, message: message);
}

Iterable<XmlElement> _byLocalName(XmlNode doc, String local) =>
    doc.findAllElements('*').where((e) => e.name.local == local);

TrackParseResult _parseGpxXml(XmlDocument doc) {
  var nodes = _byLocalName(doc, 'trkpt').toList();
  if (nodes.isEmpty) {
    nodes = _byLocalName(doc, 'rtept').toList();
  }
  if (nodes.isEmpty) {
    return TrackParseResult.error('Soubor neobsahuje žádné body trasy.');
  }
  final pts = <TrackPoint>[];
  final base = DateTime.now().toUtc();
  for (var i = 0; i < nodes.length && i < _maxPoints; i++) {
    final node = nodes[i];
    final lat = double.tryParse(node.getAttribute('lat') ?? '');
    final lon = double.tryParse(node.getAttribute('lon') ?? '');
    if (lat == null || lon == null) continue;
    final timeText = node.getElement('time')?.innerText;
    final ts = DateTime.tryParse(timeText ?? '') ?? base.add(Duration(seconds: i));
    pts.add(
      TrackPoint(
        latitude: lat,
        longitude: lon,
        timestamp: ts.toLocal(),
        speed: 0,
        accuracy: 5,
        altitude: double.tryParse(node.getElement('ele')?.innerText ?? ''),
        heading: null,
        verticalAccuracy: null,
      ),
    );
  }
  if (pts.length < 2) {
    return TrackParseResult.error('Soubor neobsahuje dost platných bodů trasy.');
  }
  return TrackParseResult.success(pts);
}

TrackParseResult _parseKml(String text) {
  final doc = XmlDocument.parse(text);
  final points = <TrackPoint>[];
  for (final el in _byLocalName(doc, 'coordinates')) {
    final raw = el.innerText.trim();
    for (final chunk in raw.split(RegExp(r'[\s\n]+')).where((s) => s.isNotEmpty)) {
      final parts = chunk.split(',').map((x) => double.tryParse(x.trim())).toList();
      if (parts.length >= 2 && parts[0] != null && parts[1] != null) {
        final lng = parts[0]!;
        final lat = parts[1]!;
        if (lat.isFinite && lng.isFinite) {
          points.add(
            TrackPoint(
              latitude: lat,
              longitude: lng,
              timestamp: DateTime.now().toLocal(),
              speed: 0,
              accuracy: 5,
              altitude: null,
              heading: null,
              verticalAccuracy: null,
            ),
          );
        }
      }
      if (points.length >= _maxPoints) break;
    }
  }
  if (points.length < 2) {
    return TrackParseResult.error('V KML nebyla nalezena žádná LineString / souřadnice.');
  }
  return TrackParseResult.success(points);
}

TrackParseResult _parseTcx(String text) {
  final doc = XmlDocument.parse(text);
  final points = <TrackPoint>[];
  for (final tp in _byLocalName(doc, 'Trackpoint')) {
    final latEl = _byLocalName(tp, 'LatitudeDegrees').firstOrNull;
    final lonEl = _byLocalName(tp, 'LongitudeDegrees').firstOrNull;
    final lat = double.tryParse(latEl?.innerText ?? '');
    final lng = double.tryParse(lonEl?.innerText ?? '');
    if (lat != null && lng != null && lat.isFinite && lng.isFinite) {
      points.add(
        TrackPoint(
          latitude: lat,
          longitude: lng,
          timestamp: DateTime.now().toLocal(),
          speed: 0,
          accuracy: 5,
          altitude: null,
          heading: null,
          verticalAccuracy: null,
        ),
      );
    }
    if (points.length >= _maxPoints) break;
  }
  if (points.length < 2) {
    return TrackParseResult.error('V TCX nebyly nalezeny žádné body Trackpoint.');
  }
  return TrackParseResult.success(points);
}

TrackParseResult _parseGeoJson(String text) {
  dynamic data;
  try {
    data = jsonDecode(text);
  } catch (_) {
    return TrackParseResult.error('Neplatný JSON (GeoJSON).');
  }

  List<TrackPoint> extractLine(List<dynamic> coords) {
    final out = <TrackPoint>[];
    for (final c in coords) {
      if (c is List && c.length >= 2) {
        final lng = (c[0] as num).toDouble();
        final lat = (c[1] as num).toDouble();
        if (lat.isFinite && lng.isFinite) {
          out.add(
            TrackPoint(
              latitude: lat,
              longitude: lng,
              timestamp: DateTime.now().toLocal(),
              speed: 0,
              accuracy: 5,
              altitude: null,
              heading: null,
              verticalAccuracy: null,
            ),
          );
        }
      }
      if (out.length >= _maxPoints) break;
    }
    return out;
  }

  List<TrackPoint> walk(dynamic obj) {
    if (obj is! Map) return [];
    final o = Map<String, dynamic>.from(obj);
    final t = o['type'];
    if (t == 'LineString' && o['coordinates'] is List) {
      return extractLine(o['coordinates'] as List);
    }
    if (t == 'MultiLineString' && o['coordinates'] is List) {
      final first = (o['coordinates'] as List).cast<dynamic>();
      if (first.isNotEmpty && first.first is List) {
        return extractLine(first.first as List);
      }
    }
    if (t == 'Feature' && o['geometry'] is Map) {
      return walk(o['geometry']);
    }
    if (t == 'FeatureCollection' && o['features'] is List) {
      for (final f in (o['features'] as List)) {
        final p = walk(f);
        if (p.length >= 2) return p;
      }
    }
    return [];
  }

  final pts = walk(data);
  if (pts.length < 2) {
    return TrackParseResult.error('GeoJSON neobsahuje LineString s body.');
  }
  return TrackParseResult.success(pts);
}

TrackParseResult _parseCsv(String text) {
  final lines = text.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
  if (lines.length < 2) {
    return TrackParseResult.error('CSV musí mít hlavičku a alespoň jeden řádek.');
  }
  final header = lines.first.split(',').map((h) => h.trim().toLowerCase()).toList();
  var latIdx = header.indexWhere((h) => h == 'lat' || h == 'latitude' || h == 'y');
  var lngIdx = header.indexWhere(
    (h) => h == 'lng' || h == 'lon' || h == 'longitude' || h == 'x',
  );
  if (latIdx < 0 || lngIdx < 0) {
    latIdx = 0;
    lngIdx = 1;
  }
  final pts = <TrackPoint>[];
  for (var i = 1; i < lines.length && pts.length < _maxPoints; i++) {
    final cells = lines[i].split(',').map((c) => c.trim()).toList();
    if (cells.length <= latIdx || cells.length <= lngIdx) continue;
    final lat = double.tryParse(cells[latIdx]);
    final lng = double.tryParse(cells[lngIdx]);
    if (lat != null && lng != null && lat.isFinite && lng.isFinite) {
      pts.add(
        TrackPoint(
          latitude: lat,
          longitude: lng,
          timestamp: DateTime.now().toLocal(),
          speed: 0,
          accuracy: 5,
          altitude: null,
          heading: null,
          verticalAccuracy: null,
        ),
      );
    }
  }
  if (pts.length < 2) {
    return TrackParseResult.error('V CSV nebyly nalezeny platné souřadnice.');
  }
  return TrackParseResult.success(pts);
}

/// Parsování GPX / KML / TCX / GeoJSON / CSV — stejné rozšíření jako na webu (`parseTrackFile`).
TrackParseResult parseTrackFile(String text, String filename) {
  final parts = filename.split('.');
  final ext = parts.length > 1 ? parts.last.toLowerCase() : '';
  const supported = {'gpx', 'kml', 'tcx', 'csv', 'json', 'geojson'};
  if (!supported.contains(ext)) {
    return TrackParseResult.error(
      'Nepodporovaný formát. Použijte GPX, KML, TCX, CSV nebo GeoJSON.',
    );
  }
  final t = text.trim();
  if (t.isEmpty) {
    return TrackParseResult.error('Prázdný soubor.');
  }
  try {
    if (ext == 'gpx') {
      return _parseGpxXml(XmlDocument.parse(t));
    }
    if (ext == 'kml') return _parseKml(t);
    if (ext == 'tcx') return _parseTcx(t);
    if (ext == 'json' || ext == 'geojson') return _parseGeoJson(t);
    if (ext == 'csv') return _parseCsv(t);
  } catch (_) {
    return TrackParseResult.error('Nepodařilo se zpracovat soubor.');
  }
  return TrackParseResult.error('Nepodporovaný formát souboru.');
}

List<TrackPoint> _ensureDistinctTimestamps(List<TrackPoint> points) {
  final t0 = points.first.timestamp;
  if (!points.every((p) => p.timestamp == t0)) return points;
  return [
    for (var i = 0; i < points.length; i++)
      TrackPoint(
        latitude: points[i].latitude,
        longitude: points[i].longitude,
        timestamp: t0.add(Duration(seconds: i)),
        speed: points[i].speed,
        accuracy: points[i].accuracy,
        altitude: points[i].altitude,
        heading: points[i].heading,
        verticalAccuracy: points[i].verticalAccuracy,
      ),
  ];
}

TrackingSummary trackPointsToSummary(List<TrackPoint> points) {
  if (points.length < 2) {
    throw ArgumentError('Need at least 2 points');
  }
  points = _ensureDistinctTimestamps(points);
  final distance = const Distance();
  double totalDistance = 0;
  double maxSpeed = 0;
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1];
    final b = points[i];
    final seg = distance.as(
      LengthUnit.Meter,
      LatLng(a.latitude, a.longitude),
      LatLng(b.latitude, b.longitude),
    );
    totalDistance += seg;
    final dt = b.timestamp.difference(a.timestamp).inMilliseconds / 1000.0;
    if (dt > 0 && seg > 0) {
      final sp = seg / dt;
      if (sp > maxSpeed) maxSpeed = sp;
    }
  }
  final start = points.first.timestamp;
  final end = points.last.timestamp;
  final duration = end.isAfter(start) ? end.difference(start) : const Duration(seconds: 1);
  final averageSpeed =
      duration.inSeconds > 0 ? totalDistance / duration.inSeconds : 0.0;

  return TrackingSummary(
    isTracking: false,
    startTime: start,
    duration: duration,
    totalDistance: totalDistance,
    averageSpeed: averageSpeed,
    maxSpeed: maxSpeed,
    totalElevationGain: 0,
    totalElevationLoss: 0,
    minAltitude: null,
    maxAltitude: null,
    trackPoints: points,
  );
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
