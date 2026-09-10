import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../config/app_colors.dart';
import '../../../models/forms/form_config.dart';
import '../../../models/forms/form_context.dart';
import '../../../services/auth_service.dart';
import '../../../services/track_file_parser.dart';
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

  bool get _isAdmin => (AuthService.currentUser?.role ?? '') == 'ADMIN';

  @override
  Widget build(BuildContext context) {
    final formContext = context.watch<FormContext>();
    final summary = formContext.trackingSummary;
    return FormSectionCard(
      title: widget.field.label,
      subtitle:
          'GPX, KML, TCX, GeoJSON nebo CSV — stejné formáty jako na webu u kroku „Soubor z appky“.',
      icon: Icons.upload_file_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.upload_file_rounded, size: 42, color: AppColors.brand),
          const SizedBox(height: 8),
          Text(
            'Vyberte soubor trasy',
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
          if (_isAdmin) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nástroj pro správce',
                    style: GoogleFonts.libreFranklin(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF312E81),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rychlé nahrání stejné testovací trasy v podporovaných formátech (jako na webu).',
                    style: GoogleFonts.libreFranklin(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4338CA),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kAdminTestTrackFixtures
                        .map(
                          (f) => OutlinedButton(
                            onPressed: _isLoading ? null : () => _loadAdminFixture(context, f),
                            child: Text('Test · ${f.label}'),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          AppButton(
            onPressed: _isLoading ? null : () => _pickTrackFile(context),
            text: _isLoading ? 'Načítám…' : 'Vybrat soubor',
            type: AppButtonType.primary,
            size: AppButtonSize.medium,
          ),
        ],
      ),
    );
  }

  Future<void> _loadAdminFixture(BuildContext context, AdminTestTrackFixture fixture) async {
    final messenger = ScaffoldMessenger.of(context);
    final formContext = context.read<FormContext>();
    setState(() => _isLoading = true);
    try {
      final parsed = parseTrackFile(fixture.content, fixture.filename);
      if (!parsed.ok || parsed.points == null) {
        throw Exception(parsed.message ?? 'Chyba parsování');
      }
      final summary = trackPointsToSummary(parsed.points!);
      if (!mounted) return;
      formContext.setTrackingSummary(summary);
      formContext.updateField('visitDate', summary.startTime ?? DateTime.now());
      setState(() => _selectedFileName = fixture.filename);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Testovací trasa ${fixture.label} úspěšně načtena.'),
          backgroundColor: const Color(0xFF15803D),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final cleanMsg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      messenger.showSnackBar(
        SnackBar(
          content: Text('Testovací soubor: $cleanMsg'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickTrackFile(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final formContext = context.read<FormContext>();
    setState(() => _isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['gpx', 'kml', 'tcx', 'csv', 'json', 'geojson'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final selected = result.files.first;
      final path = selected.path;
      if (path == null || path.isEmpty) {
        throw Exception('Soubor nemá platnou cestu.');
      }
      final file = File(path);
      if (!await file.exists()) {
        throw Exception('Vybraný soubor nebyl nalezen.');
      }
      final size = await file.length();
      if (size > 25 * 1024 * 1024) {
        throw Exception('Soubor je příliš velký (maximální povolená velikost je 25 MB).');
      }
      if (size == 0) {
        throw Exception('Vybraný soubor je prázdný.');
      }

      final bytes = await file.readAsBytes();
      String text;
      try {
        text = utf8.decode(bytes);
      } catch (_) {
        try {
          text = utf8.decode(bytes, allowMalformed: true);
        } catch (_) {
          text = latin1.decode(bytes);
        }
      }

      final parsed = parseTrackFile(text, selected.name);
      if (!parsed.ok || parsed.points == null) {
        throw Exception(parsed.message ?? 'Soubor se nepodařilo zpracovat.');
      }
      final summary = trackPointsToSummary(parsed.points!);
      if (!mounted) return;
      formContext.setTrackingSummary(summary);
      formContext.updateField('visitDate', summary.startTime ?? DateTime.now());
      setState(() => _selectedFileName = selected.name);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Trasa „${selected.name}“ byla úspěšně načtena (${summary.trackPoints.length} bodů, ${(summary.totalDistance / 1000).toStringAsFixed(2)} km).'),
          backgroundColor: const Color(0xFF15803D),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final cleanMsg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      messenger.showSnackBar(
        SnackBar(
          content: Text(cleanMsg),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
