import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/place_label.dart';

/// Vyhledání místa přes Mapy.com. Klepnutí do mapy dál bere název z Nominatim.
class NominatimService {
  static const _ua = 'StrakataTuristikaAndroid/1.0 (school project; contact via app)';

  static Future<List<NominatimSearchHit>> search(String query, {http.Client? client}) async {
    final q = query.trim();
    if (q.length < 2) return [];
    final c = client ?? http.Client();
    try {
      final uri = Uri.parse(
        'https://mapy.com/api/suggest?phrase=${Uri.encodeQueryComponent(q)}&lang=cs&count=6',
      );
      final res = await c.get(uri, headers: {'Accept': 'application/json', 'User-Agent': _ua});
      if (res.statusCode != 200) return [];
      final decoded = jsonDecode(res.body);
      final list = decoded is Map ? decoded['result'] : null;
      if (list is! List) return [];
      final out = <NominatimSearchHit>[];
      for (final row in list) {
        if (row is! Map) continue;
        final userData = row['userData'];
        if (userData is! Map) continue;
        final data = Map<String, dynamic>.from(userData);
        final label = (data['suggestFirstRow'] as String?)?.trim() ?? '';
        final detail = (data['suggestSecondRow'] as String?)?.trim() ?? '';
        final lat = data['latitude'] is num ? (data['latitude'] as num).toDouble() : double.tryParse('${data['latitude']}');
        final lon = data['longitude'] is num ? (data['longitude'] as num).toDouble() : double.tryParse('${data['longitude']}');
        if (label.isEmpty || lat == null || lon == null) continue;
        if (!lat.isFinite || !lon.isFinite) continue;
        out.add(
          NominatimSearchHit(
            displayName: detail.isEmpty ? label : '$label, $detail',
            label: label,
            detail: detail,
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
