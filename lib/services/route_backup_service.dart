import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tracking_summary.dart';
import '../models/visit_data.dart';
import 'track_file_parser.dart';

/// Lokální záloha naměřené trasy a míst pořízených během záznamu.
///
/// Ukládá se průběžně (ne až po ukončení), takže ani pád aplikace,
/// vybití telefonu ani výpadek sítě data nesmaže. Maže se až po
/// úspěšném uložení konceptu / odeslání.
class RouteBackupService {
  static final RouteBackupService _instance = RouteBackupService._internal();
  factory RouteBackupService() => _instance;
  RouteBackupService._internal();

  static const String _fileName = 'unsaved_route_backup.json';
  static const String _tmpFileName = 'unsaved_route_backup.json.tmp';
  static const MethodChannel _nativeChannel = MethodChannel('gps_tracking_channel');

  static const String _prefActive = 'gps_session_active';
  static const String _prefSessionId = 'gps_session_id';
  static const String _prefDraftId = 'gps_draft_visit_id';
  static const String _prefStart = 'gps_session_start';
  static const String _prefSavedAt = 'gps_session_saved_at';

  List<Place> capturedPlaces = [];
  String? sessionId;
  String? draftVisitId;
  bool isActive = false;
  DateTime? sessionStartTime;
  DateTime? lastSavedAt;

  Future<void>? _saveChain;

  Future<File> _backupFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<File> _tmpFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_tmpFileName');
  }

  /// Serialize writes so concurrent saveBackup cannot race on the tmp rename.
  Future<void> saveBackup(TrackingSummary summary, {bool active = true}) {
    final previous = _saveChain;
    final done = Completer<void>();
    _saveChain = done.future;
    () async {
      try {
        if (previous != null) await previous;
        await _saveBackupUnlocked(summary, active: active);
      } finally {
        if (!done.isCompleted) done.complete();
      }
    }();
    return done.future;
  }

  Future<void> _saveBackupUnlocked(TrackingSummary summary, {bool active = true}) async {
    try {
      if (summary.trackPoints.length < 2 && capturedPlaces.isEmpty) return;
      isActive = active;
      lastSavedAt = DateTime.now();
      sessionStartTime ??= summary.startTime ??
          (summary.trackPoints.isNotEmpty ? summary.trackPoints.first.timestamp : null);
      sessionId ??= 'tr_${DateTime.now().millisecondsSinceEpoch}';

      final map = {
        'savedAt': lastSavedAt!.toIso8601String(),
        'sessionId': sessionId,
        'draftVisitId': draftVisitId,
        'isActive': isActive,
        'startTime': sessionStartTime?.toIso8601String(),
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

      final tmp = await _tmpFile();
      final file = await _backupFile();
      final payload = jsonEncode(map);
      await tmp.writeAsString(payload, flush: true);
      try {
        if (await file.exists()) {
          await file.delete();
        }
        await tmp.rename(file.path);
      } on PathNotFoundException {
        // Rename can fail on some Android FS races — fall back to copy.
        await file.writeAsString(payload, flush: true);
        if (await tmp.exists()) {
          await tmp.delete();
        }
      } catch (_) {
        await file.writeAsString(payload, flush: true);
        try {
          if (await tmp.exists()) await tmp.delete();
        } catch (_) {}
      }
      await _persistPrefs();
      print(
        '✅ [RouteBackup] Záloha (${summary.trackPoints.length} bodů, '
        '${capturedPlaces.length} míst, active=$isActive)',
      );
    } catch (e) {
      print('❌ [RouteBackup] Záloha selhala: $e');
    }
  }

  /// Nová měřicí relace — smaže předchozí identitu, ne soubor (ten přepíše až první záloha).
  Future<void> beginNewSession() async {
    sessionId = 'tr_${DateTime.now().millisecondsSinceEpoch}';
    draftVisitId = null;
    isActive = true;
    sessionStartTime = DateTime.now();
    lastSavedAt = null;
    capturedPlaces = [];
    await _persistPrefs();
  }

  /// Obnovení relace ze zálohy (po pádu / vybití).
  void adoptSession({
    String? id,
    String? draftId,
    DateTime? startTime,
  }) {
    sessionId = id ?? sessionId ?? 'tr_${DateTime.now().millisecondsSinceEpoch}';
    draftVisitId = draftId ?? draftVisitId;
    sessionStartTime = startTime ?? sessionStartTime;
    isActive = true;
  }

  Future<void> setDraftVisitId(String id) async {
    draftVisitId = id;
    await _persistPrefs();
  }

  Future<void> markInactive() async {
    isActive = false;
    await _persistPrefs();
  }

  Future<void> _persistPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefActive, isActive);
      if (sessionId != null) {
        await prefs.setString(_prefSessionId, sessionId!);
      } else {
        await prefs.remove(_prefSessionId);
      }
      if (draftVisitId != null) {
        await prefs.setString(_prefDraftId, draftVisitId!);
      } else {
        await prefs.remove(_prefDraftId);
      }
      if (sessionStartTime != null) {
        await prefs.setString(_prefStart, sessionStartTime!.toIso8601String());
      }
      if (lastSavedAt != null) {
        await prefs.setString(_prefSavedAt, lastSavedAt!.toIso8601String());
      }
    } catch (e) {
      print('❌ [RouteBackup] SharedPreferences selhaly: $e');
    }
  }

  /// Vrátí zálohovanou trasu, nebo null pokud žádná neexistuje / je nečitelná.
  Future<TrackingSummary?> loadBackup() async {
    try {
      await _hydrateFromPrefs();
      final file = await _backupFile();
      if (!await file.exists()) return null;
      final data = jsonDecode(await file.readAsString());
      if (data is! Map) return null;
      final map = Map<String, dynamic>.from(data);
      _applyMeta(map);
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

  void _applyMeta(Map<String, dynamic> map) {
    sessionId = map['sessionId']?.toString() ?? sessionId;
    draftVisitId = map['draftVisitId']?.toString() ?? draftVisitId;
    isActive = map['isActive'] == true;
    final startRaw = map['startTime']?.toString();
    if (startRaw != null) {
      sessionStartTime = DateTime.tryParse(startRaw) ?? sessionStartTime;
    }
    final savedRaw = map['savedAt']?.toString();
    if (savedRaw != null) {
      lastSavedAt = DateTime.tryParse(savedRaw) ?? lastSavedAt;
    }
  }

  Future<void> _hydrateFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isActive = prefs.getBool(_prefActive) ?? isActive;
      sessionId = prefs.getString(_prefSessionId) ?? sessionId;
      draftVisitId = prefs.getString(_prefDraftId) ?? draftVisitId;
      final start = prefs.getString(_prefStart);
      if (start != null) {
        sessionStartTime = DateTime.tryParse(start) ?? sessionStartTime;
      }
      final saved = prefs.getString(_prefSavedAt);
      if (saved != null) {
        lastSavedAt = DateTime.tryParse(saved) ?? lastSavedAt;
      }
    } catch (_) {}
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

  Future<bool> hasUnsavedBackup() async {
    final backup = await loadBackup();
    if (backup != null && backup.trackPoints.length >= 2) return true;
    final native = await loadNativeFallback();
    return native != null && native.trackPoints.length >= 2;
  }

  /// Aktivní relace, která neskončila Stopem (pád, kill, vybití).
  Future<bool> wasSessionActive() async {
    await _hydrateFromPrefs();
    if (isActive) return true;
    try {
      final file = await _backupFile();
      if (!await file.exists()) return false;
      final data = jsonDecode(await file.readAsString());
      if (data is Map && data['isActive'] == true) return true;
    } catch (_) {}
    return false;
  }

  Future<void> addCapturedPlace(Place place) async {
    capturedPlaces = [...capturedPlaces, place];
  }

  Future<void> clearBackup() async {
    capturedPlaces = [];
    sessionId = null;
    draftVisitId = null;
    isActive = false;
    sessionStartTime = null;
    lastSavedAt = null;
    try {
      final file = await _backupFile();
      if (await file.exists()) {
        await file.delete();
      }
      final tmp = await _tmpFile();
      if (await tmp.exists()) {
        await tmp.delete();
      }
    } catch (e) {
      print('❌ [RouteBackup] Smazání zálohy selhalo: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefActive);
      await prefs.remove(_prefSessionId);
      await prefs.remove(_prefDraftId);
      await prefs.remove(_prefStart);
      await prefs.remove(_prefSavedAt);
    } catch (_) {}
    if (Platform.isAndroid) {
      try {
        await _nativeChannel.invokeMethod('clearPersistedTrack');
      } catch (_) {}
    }
  }
}
