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
import '../utils/visit_submit.dart';

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
      final summary = formContext.trackingSummary;
      ensureVisitCanBeSaved(
        slug: widget.slug,
        user: currentUser,
        summary: summary,
        newPhotoCount: formContext.photoAttachments.length,
        existingPhotoCount: 0,
      );

      final scoringConfig = await ScoringConfigService().getConfig();
      final placeTypeConfigs =
          await PlaceTypeConfigService().getPlaceTypeConfigs();

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

      final visitToSave = buildPendingVisit(
        slug: widget.slug,
        user: currentUser!,
        visitDate: formContext.visitDate,
        routeTitle: formContext.routeTitle,
        routeDescription: formContext.routeDescription,
        dogNotAllowed: formContext.dogNotAllowed,
        extraData: formContext.extraData,
        places: placesToSave,
        summary: summary,
        scoring: scoringConfig,
        placeTypes: placeTypeConfigs,
        photos: photos,
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
