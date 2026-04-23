import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../config/app_colors.dart';
import '../../../models/forms/form_config.dart';
import '../../../models/forms/form_context.dart';
import '../../../services/auth_service.dart';
import '../form_design.dart';

class RouteSummaryWidget extends StatelessWidget {
  final FormFieldWidget field;

  const RouteSummaryWidget({super.key, required this.field});

  @override
  Widget build(BuildContext context) {
    final formContext = Provider.of<FormContext>(context);
    final summary = formContext.trackingSummary;
    final title = (formContext.routeTitle ?? '').trim();
    final desc = (formContext.routeDescription ?? '').trim();
    final d = formContext.visitDate;
    final dateStr = '${d.day}. ${d.month}. ${d.year}';
    final themeRaw = formContext.extraData['themeKeywordsSelected'];
    final themeKeywords = themeRaw is List
        ? themeRaw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : const <String>[];
    final placeNames = formContext.places.map((p) => p.name.trim()).where((e) => e.isNotEmpty).toList();
    final photoCount = formContext.photoAttachments.length;
    final dogLine = _dogSummaryLine(formContext);

    return FormSectionCard(
      title: field.label,
      subtitle: 'Zkontrolujte údaje před odesláním — odpovídají poli na webu.',
      icon: Icons.summarize_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            _block('Název', title, Icons.route_rounded)
          else
            _muted('Název zatím nevyplněný'),
          const SizedBox(height: 12),
          _block('Datum návštěvy', dateStr, Icons.event_outlined),
          const SizedBox(height: 12),
          if (desc.isNotEmpty) ...[
            _block('Popis', desc, Icons.notes_rounded),
            const SizedBox(height: 12),
          ],
          _block('Pes', dogLine, Icons.pets_outlined),
          const SizedBox(height: 12),
          if (themeKeywords.isNotEmpty) ...[
            Text(
              'Téma měsíce',
              style: GoogleFonts.libreFranklin(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textTertiary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: themeKeywords
                  .map(
                    (k) => Chip(
                      label: Text(
                        k,
                        style: GoogleFonts.libreFranklin(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: AppColors.brand.withValues(alpha: 0.15),
                      side: BorderSide.none,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
          if (placeNames.isNotEmpty) ...[
            _block('Bodovaná místa (${placeNames.length})', placeNames.join(' · '), Icons.place_outlined),
            const SizedBox(height: 12),
          ] else
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _muted('Žádná bodovaná místa nejsou vyplněna.'),
            ),
          _block('Fotografie k odeslání', '$photoCount souborů', Icons.photo_library_outlined),
          if (summary != null) ...[
            const Divider(height: 28),
            Text(
              'GPS metriky',
              style: GoogleFonts.libreFranklin(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            _stat(Icons.straighten, 'Vzdálenost', '${(summary.totalDistance / 1000).toStringAsFixed(2)} km'),
            _stat(Icons.timer_outlined, 'Doba', _formatDuration(summary.duration)),
            _stat(Icons.speed, 'Průměr / max', '${(summary.averageSpeed * 3.6).toStringAsFixed(1)} / ${(summary.maxSpeed * 3.6).toStringAsFixed(1)} km/h'),
            _stat(Icons.terrain_outlined, 'Převýšení + / −',
                '+${summary.totalElevationGain.toStringAsFixed(0)} m / −${summary.totalElevationLoss.toStringAsFixed(0)} m'),
            if (summary.trackPoints.isNotEmpty)
              _stat(Icons.polyline, 'Bodů stopy', '${summary.trackPoints.length}'),
          ] else ...[
            const Divider(height: 28),
            Text(
              'Bez GPS stopy',
              style: GoogleFonts.libreFranklin(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'U nástěnky ze screenshotu nebo ručního zadání není k dispozici polyline — '
              'souhrn výše shrnuje text, datum, témata a místa stejně jako na webu.',
              style: GoogleFonts.libreFranklin(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Only values from [FormContext] or přihlášený uživatel — žádné vymyšlené jméno.
  String _dogSummaryLine(FormContext formContext) {
    if (formContext.dogNotAllowed) {
      return 'Uvedeno: pes neměl přístup';
    }
    final fromForm = formContext.extraData['dog_name']?.toString().trim();
    if (fromForm != null && fromForm.isNotEmpty) return fromForm;
    final fromProfile = AuthService.currentUser?.dogName?.trim();
    if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
    return 'Jméno psa není ve formuláři ani v profilu vyplněno.';
  }

  Widget _block(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textTertiary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.libreFranklin(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.libreFranklin(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _muted(String text) {
    return Text(
      text,
      style: GoogleFonts.libreFranklin(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textTertiary,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _stat(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.libreFranklin(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.libreFranklin(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    return '${twoDigits(d.inHours)}:$twoDigitMinutes';
  }
}
