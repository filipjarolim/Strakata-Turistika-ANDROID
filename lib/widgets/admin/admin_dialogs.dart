import 'package:flutter/material.dart';
import '../../models/visit_data.dart';
import '../../services/scoring_config_service.dart';
import '../../services/form_field_service.dart' as form_service;
import '../../models/place_type_config.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../repositories/visit_repository.dart';
import '../../services/error_recovery_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_toast.dart';
import '../../widgets/ui/strakata_primitives.dart';
import '../../utils/type_converter.dart';

class AdminDialogs {
  // Visit Details Dialog
  static Future<void> showVisitDetailsDialog(BuildContext context, VisitData visitData) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 860, maxHeight: 880),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.visibility_rounded, color: Color(0xFF2E7D32), size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              visitData.routeTitle ?? 'Bez názvu',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                                letterSpacing: -0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'DETAIL NÁVŠTĚVY'.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10, 
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF111827), size: 24),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFF3F4F6),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status and points
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: _getStatusColor(visitData.state.name).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _getStatusColor(visitData.state.name).withOpacity(0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_getStatusIcon(visitData.state.name), size: 16, color: _getStatusColor(visitData.state.name)),
                                  const SizedBox(width: 6),
                                  Text(
                                    _getStatusText(visitData.state.name),
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _getStatusColor(visitData.state.name)),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFB7E1C1)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.stars, size: 16, color: Color(0xFF2E7D32)),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${visitData.points.toStringAsFixed(1)} bodů',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Interactive Map + stats
                        _buildMapAndStats(visitData),
                        const SizedBox(height: 16),
                        
                        // User & Route info
                        _buildInfoSection(
                          'Uživatel',
                          Icons.person,
                          [
                            _buildInfoRow('Jméno', visitData.extraPoints['fullName']?.toString() ?? '—'),
                            _buildInfoRow('ID uživatele', visitData.userId ?? '—'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInfoSection(
                          'Trasa',
                          Icons.route,
                          [
                            _buildInfoRow('Název', visitData.routeTitle ?? 'Bez názvu'),
                            _buildInfoRow('Datum', _formatDate(visitData.visitDate)),
                            _buildInfoRow('Vzdálenost', _prettyKm(visitData.route?['totalDistance'])),
                            _buildInfoRow('Doba trvání', _prettyDuration(visitData.route?['duration'])),
                          ],
                        ),
                        
                        if (visitData.extraPoints.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildInfoSection(
                            'Bodové rozdělení',
                            Icons.stacked_bar_chart,
                            [
                              _buildInfoRow('Vzdálenost (km)', (visitData.extraPoints['distanceKm'] ?? '—').toString()),
                              _buildInfoRow('Body za vzdálenost', (visitData.extraPoints['distancePoints'] ?? '—').toString()),
                              _buildInfoRow('Body za místa', (visitData.extraPoints['placePoints'] ?? '—').toString()),
                              _buildInfoRow('Celkem body', visitData.points.toStringAsFixed(1)),
                            ],
                          ),
                        ],
                        
                        if (visitData.places.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildPlacesSection(visitData),
                        ],
                        
                        if ((visitData.photos ?? []).isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildPhotosGrid(visitData),
                        ],
                        
                        if (visitData.routeDescription != null && visitData.routeDescription!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildInfoSection(
                            'Poznámky',
                            Icons.note,
                            [_buildInfoRow('Text', visitData.routeDescription!)],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                // Footer actions
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: LayoutBuilder(builder: (context, c) {
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.end,
                      children: [
                         AppButton(
                          onPressed: () async {
                            final reason = await _askRejectReason(context);
                            if (reason == null) return;
                            final ok = await VisitRepository().updateVisitState(visitData.id, VisitState.REJECTED, rejectionReason: reason);
                            if (ok && context.mounted) Navigator.of(context).pop();
                          },
                          text: 'ZAMÍTNOUT',
                          icon: Icons.close_rounded,
                          type: AppButtonType.destructiveOutline,
                          size: AppButtonSize.medium,
                        ),
                        AppButton(
                          onPressed: () async {
                            await showEditPointsDialog(context, visitData);
                          },
                          text: 'UPRAVIT BODY',
                          icon: Icons.edit_rounded,
                          type: AppButtonType.secondary,
                          size: AppButtonSize.medium,
                        ),
                        AppButton(
                          onPressed: () async {
                            final ok = await VisitRepository().updateVisitState(visitData.id, VisitState.APPROVED);
                            if (ok && context.mounted) Navigator.of(context).pop();
                          },
                          text: 'SCHVÁLIT',
                          icon: Icons.check_rounded,
                          type: AppButtonType.primary,
                          size: AppButtonSize.medium,
                        ),
                      ],
                    );
                  }),
                ),
                          ],
                        ),
          ),
        );
      },
    );
  }

  static Future<String?> _askRejectReason(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Důvod zamítnutí'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Zadejte důvod (nepovinné)'),
        ),
        actions: [
          AppButton(
            onPressed: () => Navigator.pop(context),
            text: 'Zrušit',
            type: AppButtonType.ghost,
            size: AppButtonSize.small,
          ),
          AppButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            text: 'Potvrdit',
            type: AppButtonType.primary,
            size: AppButtonSize.small,
          ),
        ],
      ),
    );
  }

  static Future<void> showEditPointsDialog(BuildContext context, VisitData visit) async {
    final pointsC = TextEditingController(text: visit.points.toStringAsFixed(1));
    final peaksC = TextEditingController(text: (visit.extraPoints['peaks'] ?? 0).toString());
    final towersC = TextEditingController(text: (visit.extraPoints['towers'] ?? 0).toString());
    final treesC = TextEditingController(text: (visit.extraPoints['trees'] ?? 0).toString());
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Upravit body a místa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: pointsC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Body')),
            const SizedBox(height: 8),
            TextField(controller: peaksC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Vrcholů')),
            const SizedBox(height: 8),
            TextField(controller: towersC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rozhleden')),
            const SizedBox(height: 8),
            TextField(controller: treesC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stromů')),
          ],
        ),
        actions: [
          AppButton(
            onPressed: () => Navigator.pop(context),
            text: 'Zrušit',
            type: AppButtonType.ghost,
            size: AppButtonSize.small,
          ),
          AppButton(
            onPressed: () async {
              final p = double.tryParse(pointsC.text.replaceAll(',', '.')) ?? visit.points;
              final pk = int.tryParse(peaksC.text) ?? 0;
              final tw = int.tryParse(towersC.text) ?? 0;
              final tr = int.tryParse(treesC.text) ?? 0;
              final ok = await VisitRepository().updateVisitPoints(visit.id, p, pk, tw, tr);
              if (ok && context.mounted) Navigator.pop(context);
            },
            text: 'Uložit',
            type: AppButtonType.primary,
            size: AppButtonSize.small,
          )
        ],
      ),
    );
  }

  static Widget _buildMapAndStats(VisitData visit) {
    final track = (visit.route?['trackPoints'] as List?) ?? (visit.route?['points'] as List?) ?? (visit.route?['path'] as List?) ?? [];
    final List<LatLng> pts = [];
    if (track is List) {
      for (final item in track) {
        if (item is Map) {
          final lat = TypeConverter.toDouble(item['latitude'] ?? item['lat'] ?? item['y']);
          final lon = TypeConverter.toDouble(item['longitude'] ?? item['lng'] ?? item['lon'] ?? item['x']);
          if (lat != null && lon != null) {
            pts.add(LatLng(lat.toDouble(), lon.toDouble()));
          }
        } else if (item is List && item.length >= 2) {
          final a = item[0];
          final b = item[1];
          if (a is num && b is num) {
            pts.add(LatLng(a.toDouble(), b.toDouble()));
          }
        }
      }
    }

    // Compute bounds and adaptive zoom
    LatLng center = const LatLng(49.8175, 15.4730);
    double zoom = 13.0;
    if (pts.isNotEmpty) {
      double minLat = pts.first.latitude, maxLat = pts.first.latitude;
      double minLng = pts.first.longitude, maxLng = pts.first.longitude;
      for (final p in pts) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
      final spanLat = (maxLat - minLat).abs();
      final spanLng = (maxLng - minLng).abs();
      final span = spanLat > spanLng ? spanLat : spanLng;
      if (span > 0.1) {
        zoom = 10.0;
      } else if (span > 0.05) {
        zoom = 11.0;
      } else if (span > 0.01) {
        zoom = 12.0;
      } else if (span > 0.005) {
        zoom = 13.0;
      } else {
        zoom = 14.0;
      }
    }

    final totalMeters = TypeConverter.toDoubleWithDefault(visit.route?['totalDistance'], 0.0);
    final durationSec = TypeConverter.toIntWithDefault(visit.route?['duration'], 0);
    final km = totalMeters / 1000.0;
    final h = durationSec > 0 ? (durationSec / 3600.0) : 0.0;
    final avg = (h > 0 && km > 0) ? (km / h) : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          // Open in Mapy.cz / Export
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: AppButton(
                onPressed: pts.isEmpty ? null : () {
                  final geojson = _toGeoJsonFeature(pts);
                  _openInMapyCz(geojson);
                },
                text: 'Otevřít v Mapy.cz',
                icon: Icons.open_in_new,
                type: AppButtonType.outline,
                size: AppButtonSize.small,
              ),
            ),
          ),
          SizedBox(
            height: 260,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              child: FlutterMap(
                mapController: MapController(),
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: zoom,
                ),
                children: [
                  FutureBuilder<bool>(
                    future: ErrorRecoveryService().isNetworkAvailable(),
                    builder: (context, snapshot) {
                      if (snapshot.data == true) {
                        return TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'cz.strakata.turistika.strakataturistikaandroidapp',
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  if (pts.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(points: pts, strokeWidth: 6, color: const Color(0xFF4CAF50)),
                      ],
                    ),
                  if (pts.isNotEmpty)
                    MarkerLayer(markers: [
                      Marker(
                        point: pts.first,
                        width: 20,
                        height: 20,
                        child: Container(
                          decoration: BoxDecoration(color: const Color(0xFF4CAF50), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                        ),
                      ),
                      if (pts.length > 1)
                        Marker(
                          point: pts.last,
                          width: 20,
                          height: 20,
                          child: Container(
                            decoration: BoxDecoration(color: const Color(0xFF2E7D32), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                          ),
                        ),
                    ]),
                  if (pts.isEmpty)
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(8)),
                        child: const Text('Trasa neobsahuje souřadnice', style: TextStyle(color: Colors.black87)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statChip(Icons.straighten, '${km.toStringAsFixed(2)} km'),
                _statChip(Icons.timer, _prettyDuration(durationSec)),
                _statChip(Icons.speed, '${avg.toStringAsFixed(1)} km/h'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _statChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF2E7D32)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
        ],
      ),
    );
  }

  static Widget _buildPlacesSection(VisitData visit) {
    return _buildInfoSection(
      'Navštívená místa',
      Icons.place,
      visit.places.map((place) {
        return _buildInfoRow(place.name, '${place.type.name} • ${place.photos.length} fotek');
      }).toList(),
    );
  }

  static Widget _buildPhotosGrid(VisitData visit) {
    final legacy = visit.photos ?? [];
    final placePhotos = visit.places
        .expand((p) => p.photos)
        .map((ph) => ph.url)
        .toList();
    
    // Combine photos with metadata
    final allPhotoData = <Map<String, dynamic>>[];
    
    // Legacy photos (may include screenshots from web)
    for (final photo in legacy) {
      final url = (photo['url'] ?? '').toString();
      if (url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('/') || url.startsWith('file://'))) {
        allPhotoData.add({
          'url': url,
          'isScreenshot': (photo['title']?.toString().toLowerCase().contains('screenshot') ?? false) ||
                         (photo['title']?.toString().toLowerCase().contains('watch') ?? false) ||
                         (photo['description']?.toString().toLowerCase().contains('screenshot') ?? false),
        });
      }
    }
    
    // Place photos
    for (final url in placePhotos) {
      if (url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('/') || url.startsWith('file://'))) {
        allPhotoData.add({
          'url': url,
          'isScreenshot': false,
        });
      }
    }
    
    final all = allPhotoData.map((p) => p['url'] as String).toList();

    if (all.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Fotografie', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${all.length} ${all.length == 1 ? 'fotka' : all.length < 5 ? 'fotky' : 'fotek'}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: all.length,
          itemBuilder: (context, index) {
            final photoData = allPhotoData[index];
            return _buildPhotoThumbnail(
              context, 
              all[index], 
              all, 
              index,
              isScreenshot: photoData['isScreenshot'] as bool? ?? false,
            );
          },
        ),
      ],
    );
  }

  static Widget _buildPhotoThumbnail(
    BuildContext context, 
    String photoUrl, 
    List<String> allPhotos, 
    int index, {
    bool isScreenshot = false,
  }) {
    final cleanPath = photoUrl.startsWith('file://') ? photoUrl.substring(7) : photoUrl;
    final isLocalFile = cleanPath.startsWith('/');
    
    return GestureDetector(
      onTap: () => _showPhotoViewer(context, allPhotos, index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            isLocalFile
                ? Image.file(
                    File(cleanPath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFFFFEBEE),
                      child: const Icon(Icons.broken_image, color: Color(0xFFE53935)),
                    ),
                  )
                : Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: const Color(0xFFF5F6F7),
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                            color: const Color(0xFF4CAF50),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFFFFF3E0),
                      child: const Icon(Icons.broken_image, color: Color(0xFFFF9800)),
                    ),
                  ),
            // Screenshot badge (top left)
            if (isScreenshot)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.watch, size: 10, color: Colors.white),
                      const SizedBox(width: 2),
                      Text(
                        'GPS',
                        style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            // Index badge (top right)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showPhotoViewer(BuildContext context, List<String> photos, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (context) => _PhotoViewerDialog(photos: photos, initialIndex: initialIndex),
    );
  }

  static Widget _buildInfoSection(String title, IconData icon, List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: const Color(0xFF111827)),
              ),
              const SizedBox(width: 12),
              Text(
                title.toUpperCase(), 
                style: TextStyle(
                  fontSize: 11, 
                  fontWeight: FontWeight.w900, 
                  color: const Color(0xFF111827),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...rows,
        ],
      ),
    );
  }

  static Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120, 
            child: Text(
              label, 
              style: TextStyle(
                fontSize: 12, 
                color: Colors.grey[500], 
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value, 
              style: const TextStyle(
                fontSize: 13, 
                color: Color(0xFF111827), 
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day}.${d.month}.${d.year}';
  }

  static String _prettyKm(dynamic metersVal) {
    final m = TypeConverter.toDoubleWithDefault(metersVal, 0.0);
    return '${(m / 1000.0).toStringAsFixed(2)} km';
  }

  static String _prettyDuration(dynamic secondsVal) {
    final s = (secondsVal as num?)?.toInt() ?? 0;
    final h = (s ~/ 3600).toString().padLeft(2, '0');
    final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$h:$m:$sec';
  }

  static String _formatDateTime(dynamic value) {
    DateTime? dt;
    if (value is DateTime) {
      dt = value;
    } else if (value is String) {
      dt = DateTime.tryParse(value);
    }
    dt ??= DateTime.now();
    final d = dt;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd.$mm.$yyyy $hh:$min';
  }

  static Color _getStatusColor(String state) {
    switch (state) {
      case 'PENDING_REVIEW':
        return Colors.orange;
      case 'APPROVED':
        return const Color(0xFF4CAF50);
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static IconData _getStatusIcon(String state) {
    switch (state) {
      case 'PENDING_REVIEW':
        return Icons.schedule;
      case 'APPROVED':
        return Icons.check_circle;
      case 'REJECTED':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  static String _getStatusText(String state) {
    switch (state) {
      case 'PENDING_REVIEW':
        return 'Čeká na revizi';
      case 'APPROVED':
        return 'Schváleno';
      case 'REJECTED':
        return 'Odmítnuto';
      default:
        return 'Neznámý stav';
    }
  }

  // Form Preview Dialog
  static Future<void> showFormPreviewDialog(
    BuildContext context,
    List<form_service.FormField> formFields,
    ScoringConfig? scoringConfig,
  ) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700, maxHeight: 800),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green[600],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.visibility, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Náhled formuláře',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Zobrazuje aktuální konfiguraci',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: const Icon(Icons.close, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Scoring config
                        if (scoringConfig != null) ...[
                          _buildPreviewSection(
                            'Pravidla bodování',
                            Icons.score,
                            [
                              _buildPreviewRow('Body za km', '${scoringConfig.pointsPerKm}'),
                              _buildPreviewRow('Min. vzdálenost', '${scoringConfig.minDistanceKm} km'),
                              ...scoringConfig.placeTypePoints.entries.map((entry) => 
                                _buildPreviewRow('Body za ${entry.key}', '${entry.value}')
                              ),
                              _buildPreviewRow('Vyžadovat místo', scoringConfig.requireAtLeastOnePlace ? 'Ano' : 'Ne'),
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                        ],
                        
                        // Form fields
                        _buildPreviewSection(
                          'Pole formuláře (${formFields.length})',
                          Icons.list_alt,
                          formFields.map((field) {
                            return _buildPreviewRow(
                              field.label,
                              '${field.type}${field.required ? ' (Povinné)' : ''}',
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Form Preview Bottom Sheet (improved design)
  static Future<void> showFormPreviewSheet(
    BuildContext context,
    List<form_service.FormField> formFields,
    ScoringConfig? scoringConfig,
  ) async {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const StrakataSheetHandle(margin: EdgeInsets.only(top: 12)),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.visibility, color: Colors.green[700], size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Náhled formuláře',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Aktuální konfigurace pro kontrolu',
                            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (scoringConfig != null) ...[
                        _buildPreviewSection(
                          'Pravidla bodování',
                          Icons.score,
                          [
                            _buildPreviewRow('Body za km', '${scoringConfig.pointsPerKm}'),
                            _buildPreviewRow('Min. vzdálenost', '${scoringConfig.minDistanceKm} km'),
                            ...scoringConfig.placeTypePoints.entries.map((entry) =>
                              _buildPreviewRow('Body za ${entry.key}', '${entry.value}')
                            ),
                            _buildPreviewRow('Vyžadovat místo', scoringConfig.requireAtLeastOnePlace ? 'Ano' : 'Ne'),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                      _buildPreviewSection(
                        'Pole formuláře (${formFields.length})',
                        Icons.list_alt,
                        [
                          ...formFields.map((field) => _buildPreviewRow(
                            field.label,
                            '${field.type}${field.required ? ' (Povinné)' : ''}',
                          )),
                          // Locked visited places card indicator
                          _buildPreviewRow('Navštívená místa', 'Uzamčené systémové pole (na konci)'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Add Form Field Dialog
  static Future<void> showAddFormFieldDialog(
    BuildContext context,
    {required Function(form_service.FormField) onFieldAdded}
  ) async {
    final formKey = GlobalKey<FormState>();
    final labelController = TextEditingController();
    String selectedType = 'text';
    bool isRequired = false;
    
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.add, color: Colors.blue[700], size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Přidat pole', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: labelController,
                      decoration: const InputDecoration(
                        labelText: 'Název pole',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        filled: true,
                        fillColor: Color(0xFFF8FAFC),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Název je povinný';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Typ pole',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        filled: true,
                        fillColor: Color(0xFFF8FAFC),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'text', child: Text('Text')),
                        DropdownMenuItem(value: 'textarea', child: Text('Dlouhý text')),
                        DropdownMenuItem(value: 'number', child: Text('Číslo')),
                        DropdownMenuItem(value: 'select', child: Text('Výběr')),
                        DropdownMenuItem(value: 'checkbox', child: Text('Zaškrtávací pole')),
                        DropdownMenuItem(value: 'date', child: Text('Datum')),
                        DropdownMenuItem(value: 'time', child: Text('Čas')),
                        DropdownMenuItem(value: 'email', child: Text('Email')),
                        DropdownMenuItem(value: 'phone', child: Text('Telefon')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedType = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: isRequired,
                          onChanged: (value) {
                            setState(() {
                              isRequired = value ?? false;
                            });
                          },
                          activeColor: Colors.blue[600],
                        ),
                        const Text('Povinné pole'),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Zrušit'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      // Generovat unikátní name z labelu
                      final fieldName = labelController.text
                          .toLowerCase()
                          .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
                          .replaceAll(RegExp(r'_+'), '_')
                          .replaceAll(RegExp(r'^_|_$'), '');
                      
                      final field = form_service.FormField(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: fieldName,
                        label: labelController.text,
                        type: selectedType,
                        required: isRequired,
                        order: 0,
                        options: [],
                        active: true,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );
                      onFieldAdded(field);
                      Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Přidat'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Edit Form Field Dialog
  static Future<void> showEditFormFieldDialog(
    BuildContext context,
    form_service.FormField field,
    {required Function(form_service.FormField) onFieldUpdated}
  ) async {
    final formKey = GlobalKey<FormState>();
    final labelController = TextEditingController(text: field.label);
    String selectedType = field.type;
    bool isRequired = field.required;
    
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.edit, color: Colors.orange[700], size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Upravit pole', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: labelController,
                      decoration: const InputDecoration(
                        labelText: 'Název pole',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        filled: true,
                        fillColor: Color(0xFFF8FAFC),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Název je povinný';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Typ pole',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        filled: true,
                        fillColor: Color(0xFFF8FAFC),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'text', child: Text('Text')),
                        DropdownMenuItem(value: 'textarea', child: Text('Dlouhý text')),
                        DropdownMenuItem(value: 'number', child: Text('Číslo')),
                        DropdownMenuItem(value: 'select', child: Text('Výběr')),
                        DropdownMenuItem(value: 'checkbox', child: Text('Zaškrtávací pole')),
                        DropdownMenuItem(value: 'date', child: Text('Datum')),
                        DropdownMenuItem(value: 'time', child: Text('Čas')),
                        DropdownMenuItem(value: 'email', child: Text('Email')),
                        DropdownMenuItem(value: 'phone', child: Text('Telefon')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedType = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: isRequired,
                          onChanged: (value) {
                            setState(() {
                              isRequired = value ?? false;
                            });
                          },
                          activeColor: Colors.blue[600],
                        ),
                        const Text('Povinné pole'),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Zrušit'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final updatedField = field.copyWith(
                        label: labelController.text,
                        type: selectedType,
                        required: isRequired,
                        updatedAt: DateTime.now(),
                      );
                      onFieldUpdated(updatedField);
                      Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Uložit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Delete Form Field Dialog
  static Future<void> showDeleteFormFieldDialog(
    BuildContext context,
    {required VoidCallback onConfirm}
  ) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.delete, color: Colors.red[700], size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Smazat pole', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          content: const Text(
            'Opravdu chcete smazat toto pole? Tato akce je nevratná.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Zrušit'),
            ),
            ElevatedButton(
              onPressed: () {
                onConfirm();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Smazat'),
            ),
          ],
        );
      },
    );
  }

  // Admin Activity Logs Dialog
  static Future<void> showAdminActivityLogsDialog(
    BuildContext context,
    List<Map<String, dynamic>> actions,
  ) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.indigo[600]!, Colors.indigo[400]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.history, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Historie akcí',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Přehled admin aktivit',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white, size: 24),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Expanded(
                  child: actions.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history, size: 60, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'Žádné akce',
                                style: TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(24),
                          itemCount: actions.length,
                          itemBuilder: (context, index) {
                            final action = actions[actions.length - 1 - index]; // Reverse order
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.info, color: Colors.blue[700], size: 16),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          action['action'] ?? 'Neznámá akce',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatDateTime(action['timestamp']),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper methods
  static Widget _buildPreviewSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.grey[700], size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  static Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Nové metody pro ScoringConfig place type points
  static Future<Map<String, dynamic>?> showAddPlaceTypePointsDialog(
    BuildContext context,
    ScoringConfig scoringConfig,
  ) async {
    final TextEditingController placeTypeController = TextEditingController();
    final TextEditingController pointsController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.add, color: Colors.green[700], size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Přidat typ místa', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: placeTypeController,
                  decoration: InputDecoration(
                    labelText: 'Název typu místa',
                    hintText: 'např. jezero, hrad, kostel',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.green[600]!, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Název je povinný';
                    }
                    if (scoringConfig.hasPlaceType(value.trim().toLowerCase())) {
                      return 'Tento typ místa již existuje';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: pointsController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Body',
                    hintText: 'např. 5.0',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.green[600]!, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Body jsou povinné';
                    }
                    final points = double.tryParse(value);
                    if (points == null || points < 0) {
                      return 'Zadejte platné číslo';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Zrušit'),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.green[600],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.of(context).pop({
                        'placeType': placeTypeController.text.trim().toLowerCase(),
                        'points': double.parse(pointsController.text),
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Přidat',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static Future<bool> showRemovePlaceTypePointsDialog(
    BuildContext context,
    String placeType,
    double currentPoints,
  ) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.remove, color: Colors.red[700], size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Odebrat typ místa', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          content: Text(
            'Opravdu chcete odebrat typ místa "$placeType" (aktuálně ${currentPoints} bodů)?\n\nTato akce je nevratná.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Zrušit'),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.red[600],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(true),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Odebrat',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ) ?? false;
  }

  // Place Type Management Dialogs (green/white theme)
  static void showAddPlaceTypeDialog(
    BuildContext context,
    {required Function(PlaceTypeConfig) onPlaceTypeAdded}
  ) {
    final nameController = TextEditingController();
    final labelController = TextEditingController();
    final pointsController = TextEditingController();
    final orderController = TextEditingController();
    bool isActive = true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.place, color: Color(0xFF2E7D32), size: 18),
            ),
            const SizedBox(width: 8),
            const Text('Přidat typ místa', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Název (ID)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: labelController,
              decoration: InputDecoration(labelText: 'Zobrazovaný název', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pointsController,
              decoration: InputDecoration(labelText: 'Body', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: orderController,
              decoration: InputDecoration(labelText: 'Pořadí', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              keyboardType: TextInputType.number,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aktivní'),
              value: isActive,
              onChanged: (v) => isActive = v ?? true,
              activeColor: const Color(0xFF2E7D32),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zrušit')),
          ElevatedButton.icon(
            onPressed: () {
              final pt = PlaceTypeConfig(
                id: nameController.text.trim(),
                name: nameController.text.trim(),
                label: labelController.text.trim(),
                icon: Icons.place,
                points: int.tryParse(pointsController.text) ?? 0,
                color: Colors.green,
                order: int.tryParse(orderController.text) ?? 0,
                isActive: isActive,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              onPlaceTypeAdded(pt);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Přidat'),
          ),
        ],
      ),
    );
  }

  static void showEditPlaceTypeDialog(
    BuildContext context,
    PlaceTypeConfig placeType,
    {required Function(PlaceTypeConfig) onPlaceTypeUpdated}
  ) {
    final nameController = TextEditingController(text: placeType.name);
    final labelController = TextEditingController(text: placeType.label);
    final pointsController = TextEditingController(text: placeType.points.toString());
    final orderController = TextEditingController(text: placeType.order.toString());
    bool isActive = placeType.isActive;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.edit, color: Color(0xFF2E7D32), size: 18),
            ),
            const SizedBox(width: 8),
            const Text('Upravit typ místa', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Název (ID)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: labelController,
              decoration: InputDecoration(labelText: 'Zobrazovaný název', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pointsController,
              decoration: InputDecoration(labelText: 'Body', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: orderController,
              decoration: InputDecoration(labelText: 'Pořadí', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              keyboardType: TextInputType.number,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aktivní'),
              value: isActive,
              onChanged: (v) => isActive = v ?? true,
              activeColor: const Color(0xFF2E7D32),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zrušit')),
          ElevatedButton.icon(
            onPressed: () {
              final updated = placeType.copyWith(
                name: nameController.text.trim(),
                label: labelController.text.trim(),
                points: int.tryParse(pointsController.text) ?? placeType.points,
                order: int.tryParse(orderController.text) ?? placeType.order,
                isActive: isActive,
                updatedAt: DateTime.now(),
              );
              onPlaceTypeUpdated(updated);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Uložit'),
          ),
        ],
      ),
    );
  }

  static void showDeletePlaceTypeDialog(
    BuildContext context,
    PlaceTypeConfig placeType,
    {required VoidCallback onConfirm}
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.delete_outline, color: Color(0xFFC62828), size: 18),
            ),
            const SizedBox(width: 8),
            const Text('Smazat typ místa', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text('Opravdu chcete smazat typ místa "${placeType.label}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zrušit')),
          ElevatedButton(
            onPressed: () { onConfirm(); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC62828), foregroundColor: Colors.white),
            child: const Text('Smazat'),
          ),
        ],
      ),
    );
  }

  static String _toGeoJsonFeature(List<LatLng> pts) {
    final coords = pts.map((p) => [p.longitude, p.latitude]).toList();
    return '{"type":"Feature","geometry":{"type":"LineString","coordinates":${coords.toString()}},"properties":{}}';
  }

  static void _openInMapyCz(String geojson) {
    // Mapy.cz supports data parameter with GeoJSON; we open via URL launcher intent
    // For admin desktop/mobile preview we can rely on web URL
    final encoded = Uri.encodeComponent(geojson);
    final url = Uri.parse('https://mapy.cz/?q=&rm=9&source=coor&id=0&ds=1&dm=1&x=15.4730&y=49.8175&z=10&st=track&dw=2&rl=$encoded');
    // ignore: avoid_print
    print('🌐 Open in Mapy.cz: $url');
  }
}

// Fullscreen Photo Viewer Dialog with zoom and download
class _PhotoViewerDialog extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;

  const _PhotoViewerDialog({
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<_PhotoViewerDialog> createState() => _PhotoViewerDialogState();
}

class _PhotoViewerDialogState extends State<_PhotoViewerDialog> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _downloadPhoto() async {
    setState(() => _isDownloading = true);
    try {
      final photoUrl = widget.photos[_currentIndex];
      final cleanPath = photoUrl.startsWith('file://') ? photoUrl.substring(7) : photoUrl;
      final isLocal = cleanPath.startsWith('/');

      if (isLocal) {
        // Local file - copy to Downloads
        final sourceFile = File(cleanPath);
        if (await sourceFile.exists()) {
          final downloadsDir = await getExternalStorageDirectory();
          final fileName = 'strakata_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final targetPath = '${downloadsDir!.path}/$fileName';
          await sourceFile.copy(targetPath);
          if (mounted) {
            AppToast.showSuccess(context, 'Fotka uložena: $targetPath');
          }
        }
      } else {
        // Network file - download
        final response = await http.get(Uri.parse(photoUrl));
        if (response.statusCode == 200) {
          final downloadsDir = await getExternalStorageDirectory();
          final fileName = 'strakata_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final filePath = '${downloadsDir!.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          if (mounted) {
            AppToast.showSuccess(context, 'Fotka stažena: $filePath');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Chyba při stahování: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Photo viewer with zoom and swipe
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photos.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final photoUrl = widget.photos[index];
              final cleanPath = photoUrl.startsWith('file://') ? photoUrl.substring(7) : photoUrl;
              final isLocal = cleanPath.startsWith('/');

              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: isLocal
                      ? Image.file(
                          File(cleanPath),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFF1F2937),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, size: 64, color: Colors.white70),
                                  SizedBox(height: 16),
                                  Text('Soubor nenalezen', style: TextStyle(color: Colors.white70)),
                                ],
                              ),
                            ),
                          ),
                        )
                      : Image.network(
                          photoUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                                color: Colors.white,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFF1F2937),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, size: 64, color: Colors.white70),
                                  SizedBox(height: 16),
                                  Text('Chyba načítání', style: TextStyle(color: Colors.white70)),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              );
            },
          ),

          // Top bar with close button and counter
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.5),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${widget.photos.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // Balance for close button
                  ],
                ),
              ),
            ),
          ),

          // Bottom bar with download button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: _isDownloading ? null : _downloadPhoto,
                    icon: _isDownloading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.download, size: 20),
                    label: Text(_isDownloading ? 'Stahování...' : 'Stáhnout fotku'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: 8,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

