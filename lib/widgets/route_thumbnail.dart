import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/visit_data.dart';
import '../config/app_colors.dart';
import 'maps/shared_map_widget.dart';
import '../utils/type_converter.dart';

class RouteThumbnail extends StatelessWidget {
  final VisitData visit;
  final double height;
  final double borderRadius;
  final bool showGradient;

  const RouteThumbnail({
    Key? key,
    required this.visit,
    this.height = 120,
    this.borderRadius = 0,
    this.showGradient = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 1. Try to show Hero Image (First Photo)
    if (visit.photos != null && visit.photos!.isNotEmpty) {
      final String? url = visit.photos!.first['url'] as String?;
      if (url != null && url.isNotEmpty) {
        return SizedBox(
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: 'visit_photo_${visit.id}',
                  child: Image.network(
                    url,
                    height: height,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildMapPreview(context),
                  ),
                ),
                if (showGradient)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.0),
                          Colors.black.withValues(alpha: 0.4),
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }
    }

    // 2. Show Map Preview (Polyline)
    return _buildMapPreview(context);
  }

  Widget _buildMapPreview(BuildContext context) {
    if (visit.route == null || visit.route!['trackPoints'] == null) {
      return _buildNoMapPlaceholder();
    }
    
    final points = _getTrackPoints();
    if (points.isEmpty) return _buildNoMapPlaceholder();

    // Calculate bounds
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    
    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    
    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    final latSpan = maxLat - minLat;
    final lngSpan = maxLng - minLng;
    final maxSpan = max(latSpan, lngSpan);
    
    // Crude zoom estimation
    double zoom = 13.0;
    if (maxSpan > 1.0) zoom = 6;
    else if (maxSpan > 0.5) zoom = 8;
    else if (maxSpan > 0.2) zoom = 9;
    else if (maxSpan > 0.1) zoom = 10;
    else if (maxSpan > 0.05) zoom = 11;
    else if (maxSpan > 0.02) zoom = 12;
    else if (maxSpan > 0.01) zoom = 13;
    else zoom = 14;

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.only(
             topLeft: Radius.circular(borderRadius),
             topRight: Radius.circular(borderRadius),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
        child: IgnorePointer( // Make it non-interactive
          child: SharedMapWidget(
            center: LatLng(centerLat, centerLng),
            zoom: zoom,
            isInteractive: false,
            polylines: [
              Polyline(
                points: points,
                strokeWidth: 4.0,
                color: AppColors.primary,
                borderColor: Colors.white,
                borderStrokeWidth: 1.0,
              ),
            ],
            markers: [
              Marker(
                point: points.first,
                width: 12,
                height: 12,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)],
                  ),
                ),
              ),
              Marker(
                point: points.last,
                width: 12,
                height: 12,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoMapPlaceholder() {
    return Container(
      height: height,
      width: double.infinity,
      color: const Color(0xFFF5F6F7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Icon(Icons.map_outlined, size: 32, color: Colors.grey[400]),
             const SizedBox(height: 4),
             Text(
               'Bez náhledu trasy',
               style: TextStyle(color: Colors.grey[500], fontSize: 10),
             ),
          ],
        ),
      ),
    );
  }

  List<LatLng> _getTrackPoints() {
    if (visit.route == null || visit.route!['trackPoints'] == null) return [];
    
    final List<dynamic> rawPoints = visit.route!['trackPoints'];
    if (rawPoints.isEmpty) return [];

    return rawPoints.map((p) {
      return LatLng(
        TypeConverter.toDoubleWithDefault(p['latitude'], 0.0),
        TypeConverter.toDoubleWithDefault(p['longitude'], 0.0),
      );
    }).toList();
  }
}

