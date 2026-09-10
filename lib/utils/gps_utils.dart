import 'dart:math';
import 'package:latlong2/latlong.dart';

// Helper class for route segments
class RouteSegment {
  final double direction; // Degrees (0 = North, 90 = East, etc.)
  final double distance; // Distance in degrees
  final double curveRadius; // Curve radius for transitions
  
  RouteSegment({
    required this.direction,
    required this.distance,
    required this.curveRadius,
  });
}

class GpsUtils {
  static String getHeadingDirection(double heading) {
    if (heading >= 337.5 || heading < 22.5) return 'N';
    if (heading >= 22.5 && heading < 67.5) return 'NE';
    if (heading >= 67.5 && heading < 112.5) return 'E';
    if (heading >= 112.5 && heading < 157.5) return 'SE';
    if (heading >= 157.5 && heading < 202.5) return 'S';
    if (heading >= 202.5 && heading < 247.5) return 'SW';
    if (heading >= 247.5 && heading < 292.5) return 'W';
    if (heading >= 292.5 && heading < 337.5) return 'NW';
    return 'N';
  }

  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  static double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    final double lat1Rad = point1.latitude * pi / 180;
    final double lat2Rad = point2.latitude * pi / 180;
    final double deltaLat = (point2.latitude - point1.latitude) * pi / 180;
    final double deltaLng = (point2.longitude - point1.longitude) * pi / 180;
    
    final double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLng / 2) * sin(deltaLng / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  static List<LatLng> generateSmartRoute() {
    final List<LatLng> points = [];
    
    // Starting point (Prague center)
    double lat = 50.0755;
    double lng = 14.4378;
    
    // Define route segments with smooth transitions
    final List<RouteSegment> segments = [
      RouteSegment(direction: 90, distance: 0.02, curveRadius: 0.005), // East
      RouteSegment(direction: 45, distance: 0.015, curveRadius: 0.003), // Northeast
      RouteSegment(direction: 0, distance: 0.02, curveRadius: 0.005), // North
      RouteSegment(direction: -45, distance: 0.015, curveRadius: 0.003), // Northwest
      RouteSegment(direction: -90, distance: 0.02, curveRadius: 0.005), // West
      RouteSegment(direction: -135, distance: 0.015, curveRadius: 0.003), // Southwest
      RouteSegment(direction: 180, distance: 0.02, curveRadius: 0.005), // South
      RouteSegment(direction: 135, distance: 0.015, curveRadius: 0.003), // Southeast
      RouteSegment(direction: 90, distance: 0.025, curveRadius: 0.008), // East (longer)
      RouteSegment(direction: 30, distance: 0.02, curveRadius: 0.005), // Northeast
      RouteSegment(direction: -30, distance: 0.02, curveRadius: 0.005), // Northwest
      RouteSegment(direction: -90, distance: 0.025, curveRadius: 0.008), // West (longer)
    ];
    
    // Generate points for each segment
    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final nextSegment = i < segments.length - 1 ? segments[i + 1] : null;
      
      // Calculate points for this segment
      final segmentPoints = generateSegmentPoints(
        startLat: lat,
        startLng: lng,
        direction: segment.direction,
        distance: segment.distance,
        curveRadius: segment.curveRadius,
        nextDirection: nextSegment?.direction,
      );
      
      points.addAll(segmentPoints);
      
      // Update starting point for next segment
      if (segmentPoints.isNotEmpty) {
        lat = segmentPoints.last.latitude;
        lng = segmentPoints.last.longitude;
      }
    }
    
    return points;
  }

  static List<LatLng> generateSegmentPoints({
    required double startLat,
    required double startLng,
    required double direction,
    required double distance,
    required double curveRadius,
    double? nextDirection,
  }) {
    final List<LatLng> points = [];
    final int numPoints = 20; // Points per segment
    
    // Calculate if we need to curve for the next direction
    final bool needsCurve = nextDirection != null && 
        (nextDirection - direction).abs() > 10;
    
    if (needsCurve) {
      // Generate curved transition
      final double curveStartDistance = distance * 0.7; // Start curve at 70% of segment
      final double curveDistance = distance * 0.3; // Last 30% is curve
      
      // Straight part
      for (int i = 0; i < numPoints * 0.7; i++) {
        final double progress = i / (numPoints * 0.7);
        final double currentDistance = curveStartDistance * progress;
        
        final double newLat = startLat + (currentDistance * cos(direction * pi / 180));
        final double newLng = startLng + (currentDistance * sin(direction * pi / 180));
        
        points.add(LatLng(newLat, newLng));
      }
      
      // Curved part
      final double curveStartLat = startLat + (curveStartDistance * cos(direction * pi / 180));
      final double curveStartLng = startLng + (curveStartDistance * sin(direction * pi / 180));
      
      for (int i = 0; i < numPoints * 0.3; i++) {
        final double progress = i / (numPoints * 0.3);
        final double angleProgress = progress * (nextDirection - direction) / 180 * pi;
        
        // Smooth curve using cubic interpolation
        final double currentAngle = direction + (nextDirection - direction) * progress;
        final double curveOffset = curveRadius * sin(angleProgress);
        
        final double newLat = curveStartLat + (curveDistance * progress * cos(currentAngle * pi / 180)) + curveOffset;
        final double newLng = curveStartLng + (curveDistance * progress * sin(currentAngle * pi / 180)) + curveOffset;
        
        points.add(LatLng(newLat, newLng));
      }
    } else {
      // Straight segment
      for (int i = 0; i < numPoints; i++) {
        final double progress = i / numPoints;
        final double currentDistance = distance * progress;
        
        final double newLat = startLat + (currentDistance * cos(direction * pi / 180));
        final double newLng = startLng + (currentDistance * sin(direction * pi / 180));
        
        points.add(LatLng(newLat, newLng));
      }
    }
    
    return points;
  }
} 