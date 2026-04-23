import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/vector_tile_provider.dart';

class SharedMapWidget extends StatelessWidget {
  final MapController? mapController;
  final LatLng center;
  final double zoom;
  final List<Marker> markers;
  final List<Polyline> polylines;
  final bool isInteractive;
  final Function(MapPosition, bool)? onPositionChanged;
  final VoidCallback? onMapReady;
  final double? minZoom;
  final double? maxZoom;

  const SharedMapWidget({
    Key? key,
    this.mapController,
    this.center = const LatLng(49.8175, 15.4730), // CZ Center
    this.zoom = 13.0,
    this.markers = const [],
    this.polylines = const [],
    this.isInteractive = true,
    this.onPositionChanged,
    this.onMapReady,
    this.minZoom,
    this.maxZoom,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        minZoom: minZoom ?? 6.0,
        maxZoom: maxZoom ?? 18.0,
        interactionOptions: InteractionOptions(
          flags: isInteractive 
              ? InteractiveFlag.all & ~InteractiveFlag.rotate 
              : InteractiveFlag.none,
        ),
        onPositionChanged: onPositionChanged,
        onMapReady: onMapReady,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'cz.strakata.turistika.strakataturistikaandroidapp',
          tileProvider: VectorTileProvider(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          ),
        ),
        
        if (polylines.isNotEmpty)
          PolylineLayer(polylines: polylines),
          
        if (markers.isNotEmpty)
          MarkerLayer(markers: markers),
      ],
    );
  }
}
