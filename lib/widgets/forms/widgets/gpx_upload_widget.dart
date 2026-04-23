import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:xml/xml.dart';

import '../../../config/app_colors.dart';
import '../../../models/forms/form_config.dart';
import '../../../models/forms/form_context.dart';
import '../../../models/tracking_summary.dart';
import '../../../widgets/ui/app_button.dart';
import '../form_design.dart';

class GpxUploadWidget extends StatefulWidget {
  final FormFieldWidget field;

  const GpxUploadWidget({Key? key, required this.field}) : super(key: key);

  @override
  State<GpxUploadWidget> createState() => _GpxUploadWidgetState();
}

class _GpxUploadWidgetState extends State<GpxUploadWidget> {
  bool _isLoading = false;
  String? _selectedFileName;

  @override
  Widget build(BuildContext context) {
    final formContext = context.watch<FormContext>();
    final summary = formContext.trackingSummary;
    return FormSectionCard(
      title: widget.field.label,
      subtitle: 'Importujte reálný GPX soubor a doplňte trasu bez GPS záznamu.',
      icon: Icons.upload_file_rounded,
      child: Column(
        children: [
          Icon(Icons.upload_file_rounded, size: 42, color: AppColors.brand),
          const SizedBox(height: 8),
          Text(
            'Vyberte GPX soubor s vaší trasou',
            textAlign: TextAlign.center,
            style: GoogleFonts.libreFranklin(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_selectedFileName != null) ...[
            const SizedBox(height: 10),
            Text(
              _selectedFileName!,
              textAlign: TextAlign.center,
              style: GoogleFonts.libreFranklin(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (summary != null && summary.trackPoints.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Načteno ${summary.trackPoints.length} bodů · ${(summary.totalDistance / 1000).toStringAsFixed(2)} km',
              textAlign: TextAlign.center,
              style: GoogleFonts.libreFranklin(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 24),
          AppButton(
            onPressed: _isLoading ? null : () => _pickGpxFile(context),
            text: _isLoading ? 'Načítám…' : 'Vybrat soubor',
            type: AppButtonType.primary,
            size: AppButtonSize.medium,
          ),
        ],
      ),
    );
  }

  Future<void> _pickGpxFile(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final formContext = context.read<FormContext>();
    setState(() => _isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final selected = result.files.first;
      final selectedName = selected.name;
      if (!selected.name.toLowerCase().endsWith('.gpx')) {
        throw Exception('Vyberte prosím soubor ve formátu .gpx');
      }
      final path = selected.path;

      if (path == null || path.isEmpty) {
        throw Exception('Soubor GPX nemá platnou cestu.');
      }

      final summary = await _parseGpxToSummary(File(path));
      if (!mounted) return;
      formContext.setTrackingSummary(summary);
      formContext.updateField('visitDate', summary.startTime ?? DateTime.now());
      setState(() => _selectedFileName = selectedName);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('GPX se nepodařilo načíst: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<TrackingSummary> _parseGpxToSummary(File file) async {
    final raw = await file.readAsString();
    final doc = XmlDocument.parse(raw);
    final trkptNodes = doc.findAllElements('trkpt').toList();
    if (trkptNodes.length < 2) {
      throw Exception('Soubor GPX neobsahuje dost bodů trasy.');
    }

    final points = <TrackPoint>[];
    DateTime? startTime;
    double minAltitude = double.infinity;
    double maxAltitude = -double.infinity;
    double elevationGain = 0.0;
    double elevationLoss = 0.0;
    final distance = const Distance();
    double totalDistance = 0.0;
    double maxSpeed = 0.0;

    double? prevLat;
    double? prevLon;
    double? prevEle;
    DateTime? prevTime;

    for (int i = 0; i < trkptNodes.length; i++) {
      final node = trkptNodes[i];
      final lat = double.tryParse(node.getAttribute('lat') ?? '');
      final lon = double.tryParse(node.getAttribute('lon') ?? '');
      if (lat == null || lon == null) continue;

      final eleText = node.getElement('ele')?.innerText;
      final timeText = node.getElement('time')?.innerText;
      final altitude = double.tryParse(eleText ?? '');
      final timestamp = DateTime.tryParse(timeText ?? '') ?? DateTime.now().toUtc().add(Duration(seconds: i));
      startTime ??= timestamp;

      if (altitude != null) {
        if (altitude < minAltitude) minAltitude = altitude;
        if (altitude > maxAltitude) maxAltitude = altitude;
      }

      double segmentDistance = 0.0;
      double speed = 0.0;

      if (prevLat != null && prevLon != null) {
        segmentDistance = distance.as(
          LengthUnit.Meter,
          LatLng(prevLat, prevLon),
          LatLng(lat, lon),
        );
        totalDistance += segmentDistance;
      }

      if (prevTime != null) {
        final dt = timestamp.difference(prevTime).inMilliseconds / 1000.0;
        if (dt > 0 && segmentDistance > 0) {
          speed = segmentDistance / dt;
          if (speed > maxSpeed) maxSpeed = speed;
        }
      }

      if (prevEle != null && altitude != null) {
        final delta = altitude - prevEle;
        if (delta > 0) {
          elevationGain += delta;
        } else if (delta < 0) {
          elevationLoss += -delta;
        }
      }

      points.add(
        TrackPoint(
          latitude: lat,
          longitude: lon,
          timestamp: timestamp.toLocal(),
          speed: speed,
          accuracy: 5.0,
          altitude: altitude,
          heading: null,
          verticalAccuracy: null,
        ),
      );

      prevLat = lat;
      prevLon = lon;
      prevEle = altitude;
      prevTime = timestamp;
    }

    if (points.length < 2) {
      throw Exception('GPX neobsahuje validní body trasy.');
    }

    final endTime = points.last.timestamp;
    final start = points.first.timestamp;
    final duration = endTime.isAfter(start) ? endTime.difference(start) : const Duration(seconds: 1);
    final averageSpeed = duration.inSeconds > 0 ? totalDistance / duration.inSeconds : 0.0;

    return TrackingSummary(
      isTracking: false,
      startTime: start,
      duration: duration,
      totalDistance: totalDistance,
      averageSpeed: averageSpeed,
      maxSpeed: maxSpeed,
      totalElevationGain: elevationGain,
      totalElevationLoss: elevationLoss,
      minAltitude: minAltitude.isFinite ? minAltitude : null,
      maxAltitude: maxAltitude.isFinite ? maxAltitude : null,
      trackPoints: points,
    );
  }
}
