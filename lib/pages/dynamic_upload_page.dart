import 'dart:convert';

import 'package:flutter/material.dart';
import '../widgets/forms/form_renderer.dart';
import '../widgets/forms/form_design.dart';
import '../models/forms/form_context.dart';
import '../repositories/visit_repository.dart';
import '../models/visit_data.dart';
import '../models/place_type_config.dart';
import '../services/auth_service.dart';
import '../services/scoring_config_service.dart';
import '../services/cloudinary_service.dart';
import '../models/forms/extra_data_merge.dart';
import '../services/track_file_parser.dart';

class DynamicUploadPage extends StatefulWidget {
  final String slug;

  const DynamicUploadPage({Key? key, required this.slug}) : super(key: key);

  @override
  State<DynamicUploadPage> createState() => _DynamicUploadPageState();
}

class _DynamicUploadPageState extends State<DynamicUploadPage> {
  @override
  Widget build(BuildContext context) {
    return FormRenderer(
      slug: widget.slug,
      onSave: (formContext) => _handleSave(context, formContext),
    );
  }

  Future<void> _handleSave(
    BuildContext context,
    FormContext formContext,
  ) async {
    showFormLoadingDialog(context);

    try {
      final summary = formContext.trackingSummary;
      final needsPolyline =
          widget.slug == 'gps-tracking' || widget.slug == 'gpx-upload';
      if (needsPolyline &&
          (summary == null || summary.trackPoints.length < 2)) {
        throw Exception(
          'Chybí platná GPS/GPX data. Dokončete krok nahrání souboru nebo záznamu.',
        );
      }

      double points = 0.0;
      final scoringConfig = await ScoringConfigService().getConfig();
      final placeTypeConfigs =
          await PlaceTypeConfigService().getPlaceTypeConfigs();
      if (summary != null) {
        final distanceKm = summary.totalDistance / 1000;
        points += distanceKm * scoringConfig.pointsPerKm;
      }
      for (final place in formContext.places) {
        final matches = placeTypeConfigs.where((c) => c.name == place.type);
        if (matches.isNotEmpty) {
          points += matches.first.points;
        } else {
          points += scoringConfig.getPointsForPlaceType(place.type);
        }
      }

      List<Map<String, dynamic>>? photos;
      if (formContext.photoAttachments.isNotEmpty) {
        photos = await CloudinaryService.uploadVisitPhotoPayloads(formContext.photoAttachments);
      }

      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('Pro uložení návštěvy se musíte přihlásit.');
      }
      final double? distanceKmTop = summary != null
          ? double.parse((summary.totalDistance / 1000).toStringAsFixed(4))
          : null;
      final int? durationMinTop =
          summary != null ? (summary.duration.inSeconds / 60).ceil() : null;

      final extraForVisit = Map<String, dynamic>.from(formContext.extraData);
      mergeComputedRouteMetricsIntoExtraData(extraForVisit, summary);

      String? routeLinkStr;
      if (summary != null && summary.trackPoints.length >= 2) {
        final forLink = downsampleTrackPoints(summary.trackPoints);
        routeLinkStr = jsonEncode(
          forLink.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
        );
      }

      final mergedExtra = <String, dynamic>{
        'source': widget.slug == 'gpx-upload'
            ? 'gpx_upload'
            : (widget.slug == 'screenshot-upload' ? 'screenshot' : 'gps_tracking'),
      };
      if (distanceKmTop != null) {
        mergedExtra['distanceKm'] = distanceKmTop;
        mergedExtra['distance'] = distanceKmTop;
      }
      if (durationMinTop != null) {
        mergedExtra['elapsedTime'] = durationMinTop;
      }

      final visitToSave = VisitData(
        id: '',
        userId: currentUser.id,
        user: {
          'name': currentUser.name,
          'email': currentUser.email,
          'image': currentUser.image,
        },
        year: formContext.visitDate.year,
        visitDate: formContext.visitDate,
        createdAt: DateTime.now(),
        state: VisitState.PENDING_REVIEW,
        points: points,
        routeTitle: formContext.routeTitle ??
            'Trasa ${DateTime.now().day}.${DateTime.now().month}.',
        routeDescription: formContext.routeDescription ?? '',
        visitedPlaces: formContext.places.map((p) => p.name).join(', '),
        dogName: extraForVisit['dog_name']?.toString() ??
            currentUser.dogName,
        dogNotAllowed: formContext.dogNotAllowed ? 'true' : null,
        routeLink: routeLinkStr,
        extraData: extraForVisit,
        photos: photos,
        route: summary != null ? routePayloadForStorage(summary) : null,
        places: formContext.places,
        extraPoints: mergedExtra,
        distanceKm: distanceKmTop,
        durationMinutes: durationMinTop,
      );

      final savedId = await VisitRepository().saveVisit(visitToSave);

      if (!context.mounted) return;
      Navigator.pop(context);

      if (savedId != null) {
        await showFormStatusDialog(
          context,
          title: 'Úspěch!',
          message: 'Vaše návštěva byla úspěšně uložena k revizi.',
          onConfirm: () {
            Navigator.popUntil(context, (route) => route.isFirst);
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chyba při ukládání návštěvy.')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chyba: ${e.toString()}')),
      );
    }
  }
}
