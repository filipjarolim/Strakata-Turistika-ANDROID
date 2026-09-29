import '../models/tracking_summary.dart';
import 'type_converter.dart';

/// Vzdálenost pro bodování: GPS/GPX summary má přednost, jinak ruční
/// hodnota z `extraData` / `extraPoints` (screenshot / ruční zápis km).
double? resolveScoringDistanceKm({
  TrackingSummary? summary,
  Map<String, dynamic>? extraData,
  Map<String, dynamic>? extraPoints,
}) {
  if (summary != null && summary.totalDistance > 0) {
    return summary.totalDistance / 1000.0;
  }
  for (final map in [extraData, extraPoints]) {
    if (map == null || map.isEmpty) continue;
    for (final key in ['distanceKm', 'distance']) {
      final value = TypeConverter.toDouble(map[key]);
      if (value != null && value.isFinite && value > 0) return value;
    }
  }
  return null;
}

/// Body za vzdálenost: `km * pointsPerKm`.
double distancePointsForKm(double? distanceKm, double pointsPerKm) {
  if (distanceKm == null || distanceKm <= 0 || pointsPerKm <= 0) return 0.0;
  return distanceKm * pointsPerKm;
}

/// Splňuje trasa minimální délku (stejná hranice jako web / GPS preview).
bool meetsMinDistanceKm(double? distanceKm, double minDistanceKm) {
  if (distanceKm == null || !distanceKm.isFinite) return false;
  if (minDistanceKm <= 0) return distanceKm > 0;
  return distanceKm >= minDistanceKm;
}
