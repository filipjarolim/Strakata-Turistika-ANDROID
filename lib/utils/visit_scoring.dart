import '../models/tracking_summary.dart';
import 'type_converter.dart';

/// Vzdálenost pro bodování: GPS/GPX summary má přednost, jinak ruční
/// hodnota z `extraData` (screenshot / ruční zápis km).
double? resolveScoringDistanceKm({
  TrackingSummary? summary,
  Map<String, dynamic>? extraData,
}) {
  if (summary != null && summary.totalDistance > 0) {
    return summary.totalDistance / 1000.0;
  }
  if (extraData == null || extraData.isEmpty) return null;
  for (final key in ['distanceKm', 'distance']) {
    final value = TypeConverter.toDouble(extraData[key]);
    if (value != null && value.isFinite && value > 0) return value;
  }
  return null;
}

/// Body za vzdálenost: `km * pointsPerKm`.
double distancePointsForKm(double? distanceKm, double pointsPerKm) {
  if (distanceKm == null || distanceKm <= 0 || pointsPerKm <= 0) return 0.0;
  return distanceKm * pointsPerKm;
}
