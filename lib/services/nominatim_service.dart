import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/place_label.dart';

/// OpenStreetMap Nominatim (stejné API jako na webu v `PlacesManager.tsx`).
class NominatimService {
  static const _ua = 'StrakataTuristikaAndroid/1.0 (school project; contact via app)';

  static Future<List<NominatimSearchHit>> search(String query, {http.Client? client}) async {
    final q = query.trim();
    if (q.length < 2) return [];
    final c = client ?? http.Client();
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=jsonv2&addressdetails=1&accept-language=cs&limit=6&q=${Uri.encodeQueryComponent(q)}',
      );
      final res = await c.get(uri, headers: {'Accept': 'application/json', 'User-Agent': _ua});
      if (res.statusCode != 200) return [];
      final list = jsonDecode(res.body) as List<dynamic>;
      final out = <NominatimSearchHit>[];
      for (final row in list) {
        if (row is! Map) continue;
        final m = Map<String, dynamic>.from(row);
        final displayName = (m['display_name'] as String?)?.trim() ?? '';
        final address = NominatimAddress.fromMap(
          m['address'] is Map ? Map<String, dynamic>.from(m['address'] as Map) : null,
        );
        final label = humanPlaceName(
          name: m['name'] as String?,
          displayName: displayName,
          address: address,
        );
        final lat = double.tryParse('${m['lat']}');
        final lon = double.tryParse('${m['lon']}');
        if (label.isEmpty || lat == null || lon == null) continue;
        if (!lat.isFinite || !lon.isFinite) continue;
        out.add(
          NominatimSearchHit(
            displayName: displayName,
            label: label,
            detail: humanPlaceDetail(
              name: m['name'] as String?,
              displayName: displayName,
              address: address,
            ),
            lat: lat,
            lng: lon,
          ),
        );
      }
      return out;
    } finally {
      if (client == null) {
        c.close();
      }
    }
  }

  static Future<String> reverseGeocode(double lat, double lng, {http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&addressdetails=1&accept-language=cs&lat=${Uri.encodeComponent('$lat')}&lon=${Uri.encodeComponent('$lng')}',
      );
      final res = await c.get(uri, headers: {'Accept': 'application/json', 'User-Agent': _ua});
      if (res.statusCode != 200) {
        return 'Místo na mapě (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
      }
      final m = jsonDecode(res.body);
      if (m is Map) {
        final address = NominatimAddress.fromMap(
          m['address'] is Map ? Map<String, dynamic>.from(m['address'] as Map) : null,
        );
        final label = humanPlaceName(
          name: m['name'] as String?,
          displayName: m['display_name'] as String?,
          address: address,
        );
        if (label.isNotEmpty && label != 'Místo na mapě') return label;
      }
      return 'Místo na mapě (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
    } catch (_) {
      return 'Místo na mapě (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
    } finally {
      if (client == null) {
        c.close();
      }
    }
  }
}

class NominatimSearchHit {
  final String displayName;
  final String label;
  final String detail;
  final double lat;
  final double lng;

  const NominatimSearchHit({
    required this.displayName,
    required this.label,
    this.detail = '',
    required this.lat,
    required this.lng,
  });
}
