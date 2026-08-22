import 'package:latlong2/latlong.dart';

import '../utils/type_converter.dart';

class TrackPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double speed;
  final double accuracy;
  final double? heading;
  final double? altitude;
  final double? verticalAccuracy;
  
  TrackPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.speed,
    required this.accuracy,
    this.heading,
    this.altitude,
    this.verticalAccuracy,
  });
  
  LatLng toLatLng() => LatLng(latitude, longitude);
  
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'speed': speed,
      'accuracy': accuracy,
      'heading': heading,
      'altitude': altitude,
      'verticalAccuracy': verticalAccuracy,
    };
  }
  
  factory TrackPoint.fromJson(Map<String, dynamic> json) {
    DateTime parseTimestamp(dynamic raw) {
      if (raw is DateTime) return raw;
      if (raw is num) {
        final n = raw.toInt();
        // nativní Android posílá epoch ms; sekundy by byly ~1e9.
        return DateTime.fromMillisecondsSinceEpoch(n < 100000000000 ? n * 1000 : n);
      }
      return DateTime.tryParse(raw?.toString() ?? '') ?? DateTime.now();
    }

    return TrackPoint(
      latitude: TypeConverter.toDoubleWithDefault(
        json['latitude'] ?? json['lat'],
        0.0,
      ),
      longitude: TypeConverter.toDoubleWithDefault(
        json['longitude'] ?? json['lng'] ?? json['lon'],
        0.0,
      ),
      timestamp: parseTimestamp(json['timestamp']),
      speed: TypeConverter.toDoubleWithDefault(json['speed'], 0.0),
      accuracy: TypeConverter.toDoubleWithDefault(json['accuracy'], 0.0),
      heading: TypeConverter.toDouble(json['heading']),
      altitude: TypeConverter.toDouble(json['altitude']),
      verticalAccuracy: TypeConverter.toDouble(json['verticalAccuracy']),
    );
  }
}

class TrackingSummary {
  final bool isTracking;
  final DateTime? startTime;
  final Duration duration;
  final double totalDistance;
  final double averageSpeed;
  final double maxSpeed;
  final double totalElevationGain;
  final double totalElevationLoss;
  final double? minAltitude;
  final double? maxAltitude;
  final List<TrackPoint> trackPoints;

  TrackingSummary({
    required this.isTracking,
    required this.startTime,
    required this.duration,
    required this.totalDistance,
    required this.averageSpeed,
    required this.maxSpeed,
    required this.totalElevationGain,
    required this.totalElevationLoss,
    required this.minAltitude,
    required this.maxAltitude,
    required this.trackPoints,
  });

  /// Z pole `route` uloženého v Mongo (draft / návštěva) — doplní [FormContext] po návratu do formuláře.
  static TrackingSummary? fromPersistedRoute(Map<String, dynamic> route) {
    final raw = route['trackPoints'];
    if (raw is! List || raw.length < 2) return null;
    final points = <TrackPoint>[];
    for (final e in raw) {
      if (e is Map) {
        try {
          final pt = TrackPoint.fromJson(Map<String, dynamic>.from(e));
          if (pt.latitude != 0 || pt.longitude != 0) {
            points.add(pt);
          }
        } catch (_) {}
      }
    }
    if (points.length < 2) return null;

    final durSec =
        route['duration'] is num ? (route['duration'] as num).toInt() : 0;
    final totalDistance = route['totalDistance'] is num
        ? (route['totalDistance'] as num).toDouble()
        : 0.0;
    final avg = route['averageSpeed'] is num
        ? (route['averageSpeed'] as num).toDouble()
        : 0.0;
    final maxS =
        route['maxSpeed'] is num ? (route['maxSpeed'] as num).toDouble() : 0.0;

    return TrackingSummary(
      isTracking: false,
      startTime: points.first.timestamp,
      duration: Duration(seconds: durSec),
      totalDistance: totalDistance,
      averageSpeed: avg,
      maxSpeed: maxS,
      totalElevationGain: (route['totalElevationGain'] as num?)?.toDouble() ?? 0.0,
      totalElevationLoss: (route['totalElevationLoss'] as num?)?.toDouble() ?? 0.0,
      minAltitude: (route['minAltitude'] as num?)?.toDouble(),
      maxAltitude: (route['maxAltitude'] as num?)?.toDouble(),
      trackPoints: points,
    );
  }
} 