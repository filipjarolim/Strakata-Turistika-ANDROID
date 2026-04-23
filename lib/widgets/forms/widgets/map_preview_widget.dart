import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../models/forms/form_config.dart';
import '../../../models/forms/form_context.dart';
import '../form_design.dart';

class MapPreviewWidget extends StatelessWidget {
  final FormFieldWidget field;

  const MapPreviewWidget({Key? key, required this.field}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formContext = Provider.of<FormContext>(context);
    final summary = formContext.trackingSummary;
    
    if (summary == null || summary.trackPoints.isEmpty) {
      final files = formContext.selectedImages;
      if (files.isNotEmpty) {
        return FormSectionCard(
          title: 'Náhled trasy',
          subtitle: 'Polyline není k dispozici — první nahraný obrázek (např. screenshot mapy).',
          icon: Icons.map_outlined,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Image.file(
                File(files.first.path),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text('Obrázek se nepodařilo načíst'),
                ),
              ),
            ),
          ),
        );
      }
      return const FormSectionCard(
        title: 'Náhled trasy',
        icon: Icons.map_outlined,
        child: SizedBox(
          height: 120,
          child: Center(child: Text('Žádná trasa ani obrázek k zobrazení')),
        ),
      );
    }

    final points = summary.trackPoints.map((p) => LatLng(p.latitude, p.longitude)).toList();
    
    return FormSectionCard(
      title: 'Náhled trasy',
      subtitle: 'Kontrola, že je stopa kompletní a vede správně.',
      icon: Icons.map_outlined,
      child: Container(
        height: 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E4DC)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: FlutterMap(
            options: MapOptions(
              initialCenter: _calculateCenter(points),
              initialZoom: _calculateZoom(points),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.strakataturistika.app',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    strokeWidth: 4,
                    color: const Color(0xFF2563EB),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  LatLng _calculateCenter(List<LatLng> points) {
    double lat = 0;
    double lng = 0;
    for (var p in points) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }

  double _calculateZoom(List<LatLng> points) {
    // Simple zoom logic
    return 13.0;
  }
}
