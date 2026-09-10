import '../models/tracking_summary.dart';
import '../models/visit_data.dart';
import '../repositories/visit_repository.dart';
import 'auth_service.dart';
import 'route_backup_service.dart';
import 'track_file_parser.dart';

/// Průběžný upsert konceptu výletu do Mongo během GPS měření.
///
/// Když telefon dojde baterie nebo appka spadne, poslední checkpoint
/// (typicky ≤ 2 min) už je v databázi — trasa se neztratí.
class LiveTrackCheckpointService {
  static final LiveTrackCheckpointService _instance =
      LiveTrackCheckpointService._internal();
  factory LiveTrackCheckpointService() => _instance;
  LiveTrackCheckpointService._internal();

  final VisitRepository _repo = VisitRepository();
  bool _inFlight = false;

  /// Uloží / aktualizuje DRAFT. Vrací uloženou návštěvu, nebo null při chybě / offline.
  Future<VisitData?> saveDraft(
    TrackingSummary summary, {
    bool clearLocalOnSuccess = false,
  }) async {
    if (summary.trackPoints.length < 2) return null;
    while (_inFlight) {
      await Future.delayed(const Duration(milliseconds: 120));
    }
    _inFlight = true;
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null || currentUser.id.isEmpty) {
        print(
          '⚠️ [LiveCheckpoint] Uživatel není přihlášen — zůstává jen lokální záloha.',
        );
        return null;
      }

      final backup = RouteBackupService();
      final now = DateTime.now();
      final existingId = backup.draftVisitId ?? '';
      final start = summary.startTime ??
          backup.sessionStartTime ??
          (summary.trackPoints.isNotEmpty
              ? summary.trackPoints.first.timestamp
              : now);

      final extra = <String, dynamic>{
        'source': 'gps_tracking',
        if (backup.sessionId != null) 'trackingSessionId': backup.sessionId,
      };

      final visit = VisitData(
        id: existingId,
        userId: currentUser.id,
        user: {
          'name': currentUser.name,
          'email': currentUser.email,
          'image': currentUser.image,
        },
        seasonId: null,
        year: start.year,
        visitDate: start,
        createdAt: now,
        state: VisitState.DRAFT,
        points: 0,
        routeTitle:
            'Trasa ${start.day}.${start.month}.${start.year}',
        routeDescription: 'GPS trasa',
        visitedPlaces: backup.capturedPlaces.map((p) => p.name).join(', '),
        dogName: currentUser.dogName,
        dogNotAllowed: null,
        photos: [],
        places: List<Place>.from(backup.capturedPlaces),
        route: routePayloadForStorage(summary),
        extraData: {},
        extraPoints: extra,
        distanceKm: summary.totalDistance > 0
            ? (summary.totalDistance / 1000 * 1000).round() / 1000
            : null,
        durationMinutes: summary.duration.inSeconds > 0
            ? (summary.duration.inSeconds / 60).ceil()
            : null,
      );

      final savedId = await _repo.saveVisit(visit);
      if (savedId == null) return null;

      await backup.setDraftVisitId(savedId);
      if (clearLocalOnSuccess) {
        await backup.clearBackup();
      }
      print(
        '✅ [LiveCheckpoint] DRAFT uložen ($savedId, '
        '${summary.trackPoints.length} bodů, ${(summary.totalDistance / 1000).toStringAsFixed(2)} km)',
      );
      return visit.copyWith(id: savedId);
    } catch (e) {
      print('❌ [LiveCheckpoint] Uložení konceptu selhalo: $e');
      return null;
    } finally {
      _inFlight = false;
    }
  }
}
