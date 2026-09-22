import 'dart:convert';
import 'dart:io';

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
import '../utils/visit_scoring.dart';

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

  Future<List<Place>> _uploadLocalPlacePhotos(List<Place> places) async {
    final out = <Place>[];
    for (final place in places) {
      if (place.photos.every((p) => !p.isLocal)) {
        out.add(place);
        continue;
      }
      final uploaded = <PlacePhoto>[];
      for (final photo in place.photos) {
        if (!photo.isLocal) {
          uploaded.add(photo);
          continue;
        }
        final file = File(photo.url);
        if (!await file.exists()) {
          throw Exception('Lokální fotka místa "${place.name}" už v telefonu není.');
        }
        final response = await CloudinaryService.uploadImageResponse(file);
        if (response == null) {
          throw Exception('Nepodařilo se nahrát fotku místa "${place.name}".');
        }
        uploaded.add(
          photo.copyWith(
            url: response.secureUrl,
            publicId: response.publicId,
            isLocal: false,
          ),
        );
      }
      out.add(place.copyWith(photos: uploaded));
    }
    return out;
  }

  Future<void> _handleSave(
    BuildContext context,
    FormContext formContext,
  ) async {
    showFormLoadingDialog(context);

    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null || currentUser.id.isEmpty) {
        throw Exception('Pro uložení návštěvy se musíte nejdříve přihlásit.');
      }

      final summary = formContext.trackingSummary;
      final needsPolyline =
          widget.slug == 'gps-tracking' || widget.slug == 'gpx-upload';
      if (needsPolyline &&
          (summary == null || summary.trackPoints.length < 2)) {
        throw Exception(
          'Chybí platná GPS/GPX data. Dokončete krok nahrání souboru nebo záznamu.',
        );
      }

      if (widget.slug == 'screenshot-upload' &&
          formContext.photoAttachments.isEmpty) {
        throw Exception(
          'Nahrajte prosím alespoň jeden screenshot mapy nebo záznamu jako doklad o absolvované trase.',
        );
      }

      double points = 0.0;
      final scoringConfig = await ScoringConfigService().getConfig();
      final placeTypeConfigs =
          await PlaceTypeConfigService().getPlaceTypeConfigs();
      // GPS/GPX summary, jinak ručně zadané km (screenshot) — musí se započítat stejně.
      final scoredDistanceKm = resolveScoringDistanceKm(
        summary: summary,
        extraData: formContext.extraData,
      );
      points += distancePointsForKm(
        scoredDistanceKm,
        scoringConfig.pointsPerKm,
      );
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
        try {
          photos = await CloudinaryService.uploadVisitPhotoPayloads(
            formContext.photoAttachments,
          );
          if (photos.isEmpty && formContext.photoAttachments.isNotEmpty) {
            throw Exception(
              'Nepodařilo se nahrát fotografie. Zkontrolujte připojení k internetu a zkuste to znovu.',
            );
          }
        } catch (e) {
          throw Exception(
            'Nahrání fotografií selhalo: ${e.toString().replaceFirst(RegExp(r"^Exception:\s*"), "")}',
          );
        }
      }

      List<Place> placesToSave = formContext.places;
      try {
        placesToSave = await _uploadLocalPlacePhotos(placesToSave);
      } catch (e) {
        throw Exception(
          'Nahrání fotek bodovaných míst selhalo: ${e.toString().replaceFirst(RegExp(r"^Exception:\s*"), "")}',
        );
      }

      final extraForVisit = Map<String, dynamic>.from(formContext.extraData);
      mergeComputedRouteMetricsIntoExtraData(extraForVisit, summary);

      final double? distanceKmTop = scoredDistanceKm != null
          ? double.parse(scoredDistanceKm.toStringAsFixed(4))
          : resolveScoringDistanceKm(extraData: extraForVisit);
      final int? durationMinTop =
          summary != null ? (summary.duration.inSeconds / 60).ceil() : null;

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
        visitedPlaces: placesToSave.map((p) => p.name).join(', '),
        dogName: extraForVisit['dog_name']?.toString() ??
            currentUser.dogName,
        dogNotAllowed: formContext.dogNotAllowed ? 'true' : null,
        routeLink: routeLinkStr,
        extraData: extraForVisit,
        photos: photos,
        route: summary != null ? routePayloadForStorage(summary) : null,
        places: placesToSave,
        extraPoints: mergedExtra,
        distanceKm: distanceKmTop,
        durationMinutes: durationMinTop,
      );

      final savedId = await VisitRepository().saveVisit(visitToSave);

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (savedId != null) {
        await showFormStatusDialog(
          context,
          title: 'Úspěch!',
          message: 'Vaše návštěva byla úspěšně uložena k revizi.',
          onConfirm: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        );
      } else {
        await showFormStatusDialog(
          context,
          title: 'Uložení selhalo',
          message:
              'Server nepotvrdil uložení návštěvy. Zkontrolujte připojení k internetu a zkuste to znovu — vyplněné údaje zůstávají zachovány.',
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog
      final cleanMsg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      await showFormStatusDialog(
        context,
        title: 'Chyba při odeslání',
        message: cleanMsg,
      );
    }
  }
}
