import 'package:flutter/material.dart';
import '../widgets/forms/form_renderer.dart';
import '../widgets/forms/form_design.dart';
import '../models/forms/form_context.dart';
import '../repositories/visit_repository.dart';
import '../models/visit_data.dart';
import '../services/auth_service.dart';
import '../config/app_colors.dart';
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
      if (summary == null) {
        throw Exception('Chybí data o trase. Nahrajte prosím GPX soubor.');
      }

      final currentUser = AuthService.currentUser;
      final visitToSave = VisitData(
        id: '',
        userId: currentUser?.id,
        user: currentUser != null ? {'name': currentUser.name, 'email': currentUser.email, 'image': currentUser.image} : null,
        year: DateTime.now().year,
        visitDate: formContext.visitDate,
        createdAt: DateTime.now(),
        state: VisitState.PENDING_REVIEW,
        points: 0, // In a real app, calculate points based on summary and places
        routeTitle: formContext.routeTitle ?? 'Nová trasa',
        routeDescription: formContext.routeDescription,
        visitedPlaces: formContext.places.map((p) => p.name).join(', '),
        dogName: null, // This would normally come from extraData if mapped
        dogNotAllowed: formContext.dogNotAllowed ? 'true' : null,
        extraData: formContext.extraData,
        photos: formContext.selectedImages.map((f) => {'url': f.path, 'local': true}).toList(),
        route: {
          'duration': summary.duration.inSeconds,
          'totalDistance': summary.totalDistance,
          'trackPoints': summary.trackPoints.map((p) => p.toJson()).toList(),
        },
        places: formContext.places,
        extraPoints: {
          'source': effectiveSlug == 'strakata-upload'
              ? 'strakata_route'
              : (effectiveSlug == 'gpx-upload'
                  ? 'gpx_upload'
                  : (effectiveSlug == 'screenshot-upload'
                      ? 'screenshot'
                      : 'gps_tracking')),
          if (effectiveSlug == 'strakata-upload')
            'strakataRouteId': formContext.extraData['strakataRouteId'],
          if (effectiveSlug == 'strakata-upload')
            'strakataRouteLabel': formContext.extraData['strakataRouteLabel'],
        },
      );

      final success = await VisitRepository().saveVisit(visitToSave);

      // Close loading dialog
      if (!context.mounted) return;
      Navigator.pop(context);

      if (success) {
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
