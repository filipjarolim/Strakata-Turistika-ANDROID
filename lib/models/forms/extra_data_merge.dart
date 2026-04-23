import '../tracking_summary.dart';

bool _extraValueEmpty(dynamic v) {
  if (v == null) return true;
  if (v is String && v.trim().isEmpty) return true;
  return false;
}

/// Doplní do `extra` vzdálenost a čas z GPS/GPX, pokud je ve formuláři prázdné
/// (stejná idea jako sloučení u webu před validací `createVisitData`).
void mergeComputedRouteMetricsIntoExtraData(
  Map<String, dynamic> extra,
  TrackingSummary? summary,
) {
  if (summary == null) return;
  final km = summary.totalDistance / 1000;
  if (_extraValueEmpty(extra['distance']) && _extraValueEmpty(extra['distanceKm'])) {
    extra['distance'] = km.toStringAsFixed(2);
    extra['distanceKm'] = km;
  }
  final min = (summary.duration.inSeconds / 60).ceil();
  if (_extraValueEmpty(extra['duration'])) {
    extra['duration'] = min.toString();
  }
}
