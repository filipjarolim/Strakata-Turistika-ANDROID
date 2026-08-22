import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/tracking_summary.dart';
import '../models/visit_data.dart';
import 'track_file_parser.dart';

/// Lokální záloha naměřené trasy a míst pořízených během záznamu.
/// Ukládá se průběžně (ne až po ukončení), takže ani pád aplikace
/// nebo výpadek sítě data nesmaže. Maže se až po úspěšném odeslání.
class RouteBackupService {
  static final RouteBackupService _instance = RouteBackupService._internal();
  factory RouteBackupService() => _instance;
  RouteBackupService._internal();

  static const String _fileName = 'unsaved_route_backup.json';
  static const MethodChannel _nativeChannel = MethodChannel('gps_tracking_channel');

  List<Place> capturedPlaces = [];

  Future<File> _backupFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<void> saveBackup(TrackingSummary summary) async {
    try {
      if (summary.trackPoints.length < 2 && capturedPlaces.isEmpty) return;
      final map = {
        'savedAt': DateTime.now().toIso8601String(),
        'duration': summary.duration.inSeconds,
        'totalDistance': summary.totalDistance,
        'averageSpeed': summary.averageSpeed,
        'maxSpeed': summary.maxSpeed,
        'totalElevationGain': summary.totalElevationGain,
        'totalElevationLoss': summary.totalElevationLoss,
        'minAltitude': summary.minAltitude,
        'maxAltitude': summary.maxAltitude,
        'trackPoints': summary.trackPoints.map((p) => p.toJson()).toList(),
        'capturedPlaces': capturedPlaces.map((p) => p.toMap()).toList(),
      };
      final file = await _backupFile();
      await file.writeAsString(jsonEncode(map), flush: true);
      print(
        '✅ [RouteBackup] Záloha (${summary.trackPoints.length} bodů, ${capturedPlaces.length} míst)',
      );
    } catch (e) {
      print('❌ [RouteBackup] Záloha selhala: $e');
    }
  }

  /// Vrátí zálohovanou trasu, nebo null pokud žádná neexistuje / je nečitelná.
  Future<TrackingSummary?> loadBackup() async {
    try {
      final file = await _backupFile();
      if (!await file.exists()) return null;
      final data = jsonDecode(await file.readAsString());
      if (data is! Map) return null;
      final map = Map<String, dynamic>.from(data);
      final rawPlaces = map['capturedPlaces'];
      if (rawPlaces is List) {
        capturedPlaces = rawPlaces
            .whereType<Map>()
            .map((e) => Place.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
      return TrackingSummary.fromPersistedRoute(map);
    } catch (e) {
      print('❌ [RouteBackup] Načtení zálohy selhalo: $e');
      return null;
    }
  }

  /// Když Flutter záloha chybí, zkus body z nativního Android servisu.
  Future<TrackingSummary?> loadNativeFallback() async {
    if (!Platform.isAndroid) return null;
    try {
      final raw = await _nativeChannel.invokeMethod<List<dynamic>>('readPersistedTrack');
      if (raw == null || raw.length < 2) return null;
      final points = <TrackPoint>[];
      for (final e in raw) {
        if (e is Map) {
          points.add(TrackPoint.fromJson(Map<String, dynamic>.from(e)));
        }
      }
      if (points.length < 2) return null;
      return trackPointsToSummary(points);
    } catch (e) {
      print('❌ [RouteBackup] Native fallback selhal: $e');
      return null;
    }
  }

  Future<void> addCapturedPlace(Place place) async {
    capturedPlaces = [...capturedPlaces, place];
  }

  Future<void> clearBackup() async {
    capturedPlaces = [];
    try {
      final file = await _backupFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('❌ [RouteBackup] Smazání zálohy selhalo: $e');
    }
    if (Platform.isAndroid) {
      try {
        await _nativeChannel.invokeMethod('clearPersistedTrack');
      } catch (_) {}
    }
  }
}
