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
import '../config/app_colors.dart';
import '../models/forms/extra_data_merge.dart';
import 'package:google_fonts/google_fonts.dart';

class DynamicUploadPage extends StatefulWidget {
  final String slug;

  const DynamicUploadPage({Key? key, required this.slug}) : super(key: key);

  @override
  State<DynamicUploadPage> createState() => _DynamicUploadPageState();
}

class _DynamicUploadPageState extends State<DynamicUploadPage> {
  bool _strakataMode = false;

  @override
  Widget build(BuildContext context) {
    final canSwitchMode = widget.slug == 'gps-tracking';
    final effectiveSlug = canSwitchMode
        ? (_strakataMode ? 'strakata-upload' : widget.slug)
        : widget.slug;
    return Column(
      children: [
        if (canSwitchMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: FormSectionCard(
              title: 'Režim nahrávání',
              subtitle: 'Přepnutí funguje stejně jako na webu.',
              icon: Icons.compare_arrows_rounded,
              child: Row(
                children: [
                  Expanded(
                    child: _modeButton(
                      selected: !_strakataMode,
                      title: 'Klasická trasa',
                      onTap: () => setState(() => _strakataMode = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _modeButton(
                      selected: _strakataMode,
                      title: 'Strakatá trasa',
                      onTap: () => setState(() => _strakataMode = true),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: FormRenderer(
            slug: effectiveSlug,
            onSave: (formContext) =>
                _handleSave(context, formContext, effectiveSlug),
          ),
        ),
      ],
    );
  }

  Widget _modeButton({
    required bool selected,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? const Color(0xFFD5F8E4) : const Color(0xFFF4F0E8),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Center(
            child: Text(
              title,
              style: GoogleFonts.libreFranklin(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave(
    BuildContext context,
    FormContext formContext,
    String effectiveSlug,
  ) async {
    showFormLoadingDialog(context);

    try {
      final summary = formContext.trackingSummary;
      final needsPolyline = effectiveSlug == 'gps-tracking' ||
          effectiveSlug == 'gpx-upload' ||
          effectiveSlug == 'strakata-upload';
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
        if (matches.isEmpty) {
          throw Exception(
            'Konfigurace typu místa "${place.type}" nebyla nalezena v databázi.',
          );
        }
        points += matches.first.points;
      }

      List<Map<String, dynamic>>? photos;
      if (formContext.photoAttachments.isNotEmpty) {
        photos = await CloudinaryService.uploadVisitPhotoPayloads(formContext.photoAttachments);
      }

      final currentUser = AuthService.currentUser;
      final double? distanceKmTop = summary != null
          ? double.parse((summary.totalDistance / 1000).toStringAsFixed(4))
          : null;
      final int? durationMinTop =
          summary != null ? (summary.duration.inSeconds / 60).ceil() : null;

      final extraForVisit = Map<String, dynamic>.from(formContext.extraData);
      mergeComputedRouteMetricsIntoExtraData(extraForVisit, summary);

      String? routeLinkStr;
      if (summary != null && summary.trackPoints.length >= 2) {
        routeLinkStr = jsonEncode(
          summary.trackPoints
              .map((p) => {'lat': p.latitude, 'lng': p.longitude})
              .toList(),
        );
      }

      final mergedExtra = <String, dynamic>{
        'source': effectiveSlug == 'strakata-upload'
            ? 'strakata_route'
            : (effectiveSlug == 'gpx-upload'
                ? 'gpx_upload'
                : (effectiveSlug == 'screenshot-upload' ? 'screenshot' : 'gps_tracking')),
        if (effectiveSlug == 'strakata-upload')
          'strakataRouteId': formContext.extraData['strakataRouteId'],
        if (effectiveSlug == 'strakata-upload')
          'strakataRouteLabel': formContext.extraData['strakataRouteLabel'],
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
        userId: currentUser?.id,
        user: currentUser != null
            ? {
                'name': currentUser.name,
                'email': currentUser.email,
                'image': currentUser.image,
              }
            : null,
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
            currentUser?.dogName,
        dogNotAllowed: formContext.dogNotAllowed ? 'true' : null,
        routeLink: routeLinkStr,
        extraData: extraForVisit,
        photos: photos,
        route: summary != null
            ? {
                'duration': summary.duration.inSeconds,
                'totalDistance': summary.totalDistance,
                'trackPoints':
                    summary.trackPoints.map((p) => p.toJson()).toList(),
              }
            : null,
        places: formContext.places,
        extraPoints: mergedExtra,
        distanceKm: distanceKmTop,
        durationMinutes: durationMinTop,
      );

      final savedId = await VisitRepository().saveVisit(visitToSave);

      // Close loading dialog
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
