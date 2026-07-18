import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/vector_tile_provider.dart';

enum MapStyle {
  standard,
  tourist,
  satellite,
}

class SharedMapWidget extends StatefulWidget {
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
  final Function(LatLng)? onTap;
  final EdgeInsets? controlsPadding;

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
    this.onTap,
    this.controlsPadding,
  }) : super(key: key);

  @override
  State<SharedMapWidget> createState() => _SharedMapWidgetState();
}

class _SharedMapWidgetState extends State<SharedMapWidget> {
  late final MapController _mapController;
  MapStyle _currentStyle = MapStyle.standard;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _mapController = widget.mapController ?? MapController();
  }

  String getTemplateUrl(MapStyle style) {
    switch (style) {
      case MapStyle.standard:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case MapStyle.tourist:
        return 'https://tile.opentopomap.org/{z}/{x}/{y}.png';
      case MapStyle.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
  }

  Widget _getStyleIcon(MapStyle style) {
    switch (style) {
      case MapStyle.standard:
        return const Icon(Icons.map_outlined, size: 20, color: Color(0xFF2E7D32));
      case MapStyle.tourist:
        return const Icon(Icons.terrain_rounded, size: 20, color: Color(0xFF2E7D32));
      case MapStyle.satellite:
        return const Icon(Icons.satellite_alt_rounded, size: 20, color: Color(0xFF2E7D32));
    }
  }

  void _cycleMapStyle() {
    setState(() {
      switch (_currentStyle) {
        case MapStyle.standard:
          _currentStyle = MapStyle.tourist;
          break;
        case MapStyle.tourist:
          _currentStyle = MapStyle.satellite;
          break;
        case MapStyle.satellite:
          _currentStyle = MapStyle.standard;
          break;
      }
    });
  }

  Future<void> _goToCurrentLocation() async {
    setState(() {
      _locating = true;
    });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        _mapController.move(LatLng(position.latitude, position.longitude), 15.0);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Přístup k polohovým službám byl zamítnut.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nepodařilo se zaměřit polohu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _locating = false;
        });
      }
    }
  }

  Widget _buildMapControl({
    required Widget icon,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: ClipOval(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            child: Tooltip(
              message: tooltip,
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.center,
            initialZoom: widget.zoom,
            minZoom: widget.minZoom ?? 5.0,
            maxZoom: widget.maxZoom ?? 18.0,
            interactionOptions: InteractionOptions(
              flags: widget.isInteractive 
                  ? InteractiveFlag.all & ~InteractiveFlag.rotate 
                  : InteractiveFlag.none,
            ),
            onPositionChanged: widget.onPositionChanged,
            onMapReady: widget.onMapReady,
            onTap: widget.onTap != null ? (tapPosition, point) => widget.onTap!(point) : null,
          ),
          children: [
            TileLayer(
              urlTemplate: getTemplateUrl(_currentStyle),
              userAgentPackageName: 'cz.strakata.turistika.strakataturistikaandroidapp',
              tileProvider: VectorTileProvider(
                urlTemplate: getTemplateUrl(_currentStyle),
              ),
            ),
            
            if (widget.polylines.isNotEmpty)
              PolylineLayer(polylines: widget.polylines),
              
            if (widget.markers.isNotEmpty)
              MarkerLayer(markers: widget.markers),
          ],
        ),
        if (widget.isInteractive)
          Positioned(
            right: widget.controlsPadding?.right ?? 12,
            bottom: widget.controlsPadding?.bottom ?? 16,
            left: widget.controlsPadding?.left,
            top: widget.controlsPadding?.top,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMapControl(
                  icon: _getStyleIcon(_currentStyle),
                  onPressed: _cycleMapStyle,
                  tooltip: 'Změnit styl mapy',
                ),
                const SizedBox(height: 8),
                _buildMapControl(
                  icon: _locating 
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E7D32))) 
                      : const Icon(Icons.my_location_rounded, size: 20, color: Color(0xFF2E7D32)),
                  onPressed: _locating ? null : _goToCurrentLocation,
                  tooltip: 'Moje poloha',
                ),
                const SizedBox(height: 8),
                _buildMapControl(
                  icon: const Icon(Icons.add_rounded, size: 22, color: Color(0xFF2E7D32)),
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, currentZoom + 1);
                  },
                  tooltip: 'Přiblížit',
                ),
                const SizedBox(height: 6),
                _buildMapControl(
                  icon: const Icon(Icons.remove_rounded, size: 22, color: Color(0xFF2E7D32)),
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, currentZoom - 1);
                  },
                  tooltip: 'Oddálit',
                ),
              ],
            ),
          ),
      ],
    );
  }
}
