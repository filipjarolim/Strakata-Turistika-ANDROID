import 'dart:convert';

import '../models/forms/extra_data_merge.dart';
import '../models/place_type_config.dart';
import '../models/tracking_summary.dart';
import '../models/visit_data.dart';
import '../services/auth_service.dart';
import '../services/scoring_config_service.dart';
import '../services/track_file_parser.dart';
import 'season_year.dart';
import 'visit_scoring.dart';

/// Zdroj záznamu uložený v `extraPoints.source` a čtený zpět přes [VisitData.formSlug].
String visitSourceForSlug(String slug) {
  switch (slug) {
    case 'gpx-upload':
      return 'gpx_upload';
    case 'screenshot-upload':
      return 'screenshot';
    default:
      return 'gps_tracking';
  }
}

/// Stejné podmínky pro GPS záznam, GPX i screenshot, ať se odesílá z formuláře nebo z uploadu.
void ensureVisitCanBeSaved({
  required String slug,
  required User? user,
  required TrackingSummary? summary,
  required int newPhotoCount,
  required int existingPhotoCount,
}) {
  if (user == null || user.id.isEmpty) {
    throw Exception('Pro uložení návštěvy se musíte přihlásit.');
  }

  final needsPolyline = slug == 'gps-tracking' || slug == 'gpx-upload';
  if (needsPolyline && (summary == null || summary.trackPoints.length < 2)) {
    throw Exception(
      'Chybí platná GPS/GPX data. Dokončete krok nahrání souboru nebo záznamu.',
    );
  }

  if (slug == 'screenshot-upload' &&
      newPhotoCount == 0 &&
      existingPhotoCount == 0) {
    throw Exception(
      'Nahrajte prosím alespoň jeden screenshot mapy nebo záznamu jako doklad o absolvované trase.',
    );
  }
}

/// Sestaví návštěvu ve stavu čeká na schválení. Body za km jen od minimální délky.
VisitData buildPendingVisit({
  required String slug,
  required User user,
  required DateTime visitDate,
  required String? routeTitle,
  required String? routeDescription,
  required bool dogNotAllowed,
  required Map<String, dynamic> extraData,
  required List<Place> places,
  required TrackingSummary? summary,
  required ScoringConfig scoring,
  required List<PlaceTypeConfig> placeTypes,
  required List<Map<String, dynamic>>? photos,
  VisitData? existingVisit,
}) {
  final storedPhotos = (photos != null && photos.isNotEmpty)
      ? photos
      : existingVisit?.photos
          ?.map((e) => Map<String, dynamic>.from(e))
          .toList();

  ensureVisitCanBeSaved(
    slug: slug,
    user: user,
    summary: summary,
    newPhotoCount: storedPhotos?.length ?? 0,
    existingPhotoCount: 0,
  );

  final scoredDistanceKm = resolveScoringDistanceKm(
    summary: summary,
    extraData: extraData,
  );
  var points = 0.0;
  if (meetsMinDistanceKm(scoredDistanceKm, scoring.minDistanceKm)) {
    points += distancePointsForKm(scoredDistanceKm, scoring.pointsPerKm);
  }
  for (final place in places) {
    final matches = placeTypes.where((c) => c.name == place.type);
    if (matches.isNotEmpty) {
      points += matches.first.points;
    } else {
      points += scoring.getPointsForPlaceType(place.type);
    }
  }

  final extraForVisit = Map<String, dynamic>.from(extraData);
  mergeComputedRouteMetricsIntoExtraData(extraForVisit, summary);

  final double? distanceKmTop = scoredDistanceKm != null
      ? double.parse(scoredDistanceKm.toStringAsFixed(4))
      : (resolveScoringDistanceKm(extraData: extraForVisit) ??
          existingVisit?.distanceKm);
  final int? durationMinTop = summary != null
      ? (summary.duration.inSeconds / 60).ceil()
      : existingVisit?.durationMinutes;

  String? routeLinkStr;
  if (summary != null && summary.trackPoints.length >= 2) {
    final forLink = downsampleTrackPoints(summary.trackPoints);
    routeLinkStr = jsonEncode(
      forLink.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
    );
  }

  final mergedExtra = Map<String, dynamic>.from(existingVisit?.extraPoints ?? {});
  mergedExtra['source'] = visitSourceForSlug(slug);
  if (distanceKmTop != null) {
    mergedExtra['distanceKm'] = distanceKmTop;
    mergedExtra['distance'] = distanceKmTop;
  }
  if (durationMinTop != null) {
    mergedExtra['elapsedTime'] = durationMinTop;
  }

  final now = DateTime.now();
  return VisitData(
    id: existingVisit?.id ?? '',
    userId: user.id,
    user: {
      'name': user.name,
      'email': user.email,
      'image': user.image,
    },
    year: seasonEndingYear(visitDate),
    visitDate: visitDate,
    createdAt: existingVisit?.createdAt ?? now,
    state: VisitState.PENDING_REVIEW,
    points: points,
    routeTitle: routeTitle ?? 'Trasa ${now.day}.${now.month}.',
    routeDescription: routeDescription ?? '',
    visitedPlaces: places.map((p) => p.name).join(', '),
    dogName: extraForVisit['dog_name']?.toString() ?? user.dogName,
    dogNotAllowed: dogNotAllowed ? 'true' : null,
    routeLink: routeLinkStr,
    extraData: extraForVisit,
    photos: storedPhotos,
    route: summary != null ? routePayloadForStorage(summary) : null,
    places: places,
    extraPoints: mergedExtra,
    distanceKm: distanceKmTop,
    durationMinutes: durationMinTop,
  );
}
