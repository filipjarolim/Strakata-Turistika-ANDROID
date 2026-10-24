import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../config/app_theme.dart';
import '../models/forms/form_config.dart';
import '../models/forms/form_context.dart';
import '../models/visit_data.dart';
import '../models/tracking_summary.dart';
import '../services/form_service.dart';
import '../widgets/forms/form_widget_factory.dart';
import '../widgets/forms/form_design.dart';
import '../repositories/visit_repository.dart';
import '../services/auth_service.dart';
import '../services/scoring_config_service.dart';
import '../services/cloudinary_service.dart'; // Ensure this exists or use appropriate service
import '../models/place_type_config.dart';
import '../widgets/forms/form_field_validator.dart';
import '../services/route_backup_service.dart';
import '../utils/visit_submit.dart';

class DynamicFormPage extends StatefulWidget {
  final String slug;
  final TrackingSummary? trackingSummary;
  final VisitData? existingVisit;

  const DynamicFormPage({
    Key? key,
    required this.slug,
    this.trackingSummary,
    this.existingVisit,
  }) : super(key: key);

  @override
  State<DynamicFormPage> createState() => _DynamicFormPageState();
}

class _DynamicFormPageState extends State<DynamicFormPage> {
  late Future<FormConfig?> _formConfigFuture;
  final FormContext _formContext = FormContext();
  int _currentStep = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _formConfigFuture = FormService().getFormBySlug(widget.slug);
    // Ihned — addPostFrameCallback nechával trackingSummary prázdný při rychlém „Dokončit“.
    _formContext.initializeWith(
      summary: widget.trackingSummary,
      existingVisit: widget.existingVisit,
      capturedPlaces: RouteBackupService().capturedPlaces,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<FormContext>.value(
      value: _formContext,
      child: FutureBuilder<FormConfig?>(
        future: _formConfigFuture,
        builder: (context, snapshot) {
          final title = snapshot.data?.name ?? 'Načítání...';
          return FormPageShell(
            title: title,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            body: Builder(
              builder: (context) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: AppColors.brand));
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Chyba při načítání formuláře: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.libreFranklin(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }

                final config = snapshot.data!;
                return _buildForm(context, config);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, FormConfig config) {
    if (config.steps.isEmpty) return const Center(child: Text('Prázdný formulář'));

    final step = config.steps[_currentStep];
    final isLastStep = _currentStep == config.steps.length - 1;
    final isUploadStep = step.id == 'upload';

    return Column(
      children: [
        // Progress Indicator
        if (config.steps.length > 1)
          LinearProgressIndicator(
            value: (_currentStep + 1) / config.steps.length,
            backgroundColor: const Color(0xFFE8E4DC).withValues(alpha: 0.5),
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
          ),
        
        Expanded(
          child: SingleChildScrollView(
            padding: FormDesign.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FormStepHeaderCard(
                  title: step.label,
                  subtitle: 'Vyplňte údaje pečlivě, ovlivní body i vyhodnocení trasy.',
                  stepIndex: _currentStep + 1,
                  totalSteps: config.steps.length,
                ),
                if (isUploadStep) ...[
                  const SizedBox(height: 12),
                  _buildUploadStepHero(config.slug),
                  const SizedBox(height: 12),
                  _buildUploadRulesOverview(),
                ],
                const SizedBox(height: 16),
                ...step.fields.map((field) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: FormWidgetFactory.build(field),
                )),
              ],
            ),
          ),
        ),
        
        FormBottomActionBar(
          primaryLabel: isLastStep ? 'Dokončit' : 'Další',
          onPrimaryPressed: _isSubmitting
              ? null
              : () {
                  final validationError = validateFormStep(_formContext, step);
                  if (validationError != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(validationError)),
                    );
                    return;
                  }
                  if (isLastStep) {
                    _handleSubmit();
                  } else {
                    setState(() => _currentStep++);
                  }
                },
          secondaryLabel: _currentStep > 0 ? 'Zpět' : null,
          onSecondaryPressed: _currentStep > 0
              ? () => setState(() => _currentStep--)
              : null,
          isLoading: _isSubmitting,
        ),
      ],
    );
  }

  Future<void> _handleSubmit() async {
    setState(() => _isSubmitting = true);
    
    try {
      final summary =
          _formContext.trackingSummary ?? widget.trackingSummary;
      final currentUser = AuthService.currentUser;
      final priorPhotos = widget.existingVisit?.photos;

      ensureVisitCanBeSaved(
        slug: widget.slug,
        user: currentUser,
        summary: summary,
        newPhotoCount: _formContext.photoAttachments.length,
        existingPhotoCount: priorPhotos?.length ?? 0,
      );

      final scoringConfig = await ScoringConfigService().getConfig();
      final placeTypeConfigs = await PlaceTypeConfigService().getPlaceTypeConfigs();

      List<Map<String, dynamic>>? photos;
      if (_formContext.photoAttachments.isNotEmpty) {
        try {
          photos = await CloudinaryService.uploadVisitPhotoPayloads(_formContext.photoAttachments);
          if (photos.isEmpty && _formContext.photoAttachments.isNotEmpty) {
            throw Exception('Nepodařilo se nahrát fotografie. Zkontrolujte připojení k internetu a zkuste to znovu.');
          }
        } catch (e) {
          throw Exception('Nahrání fotografií selhalo: ${e.toString().replaceFirst(RegExp(r"^Exception:\s*"), "")}');
        }
      }
      if ((photos == null || photos.isEmpty) && priorPhotos != null && priorPhotos.isNotEmpty) {
        photos = priorPhotos.map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (photos != null && priorPhotos != null && priorPhotos.isNotEmpty) {
        photos = [
          ...priorPhotos.map((e) => Map<String, dynamic>.from(e)),
          ...photos,
        ];
      }

      List<Place> placesToSave = _formContext.places;
      try {
        placesToSave = await _uploadLocalPlacePhotos(placesToSave);
      } catch (e) {
        throw Exception('Nahrání fotek bodovaných míst selhalo: $e');
      }

      final visit = buildPendingVisit(
        slug: widget.slug,
        user: currentUser!,
        visitDate: _formContext.visitDate,
        routeTitle: _formContext.routeTitle,
        routeDescription: _formContext.routeDescription,
        dogNotAllowed: _formContext.dogNotAllowed,
        extraData: _formContext.extraData,
        places: placesToSave,
        summary: summary,
        scoring: scoringConfig,
        placeTypes: placeTypeConfigs,
        photos: photos,
        existingVisit: widget.existingVisit,
      );

      final savedId = await VisitRepository().saveVisit(visit);

      if (savedId != null) {
        // Záznam je bezpečně v databázi — lokální záloha trasy už není potřeba.
        await RouteBackupService().clearBackup();
        if (mounted) {
          await showFormStatusDialog(
            context,
            title: 'Návštěva uložena',
            message:
                'Záznam je v databázi ve stavu „čeká na schválení“. V administraci na webu ho uvidíte v přehledu návštěv s filtrem Čeká na schválení (výchozí). Koncepty (DRAFT) se v adminu nezobrazují.',
            onConfirm: () => Navigator.of(context).popUntil((route) => route.isFirst),
          );
        }
      } else {
        if (mounted) {
          await showFormStatusDialog(
            context,
            title: 'Uložení selhalo',
            message:
                'Při ukládání došlo k chybě. Zkontrolujte připojení k internetu '
                'a zkuste to znovu — vyplněná data i trasa zůstávají zachována.',
          );
        }
      }

    } catch (e) {
      print('Submission error: $e');
      if (mounted) {
        final cleanMsg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        await showFormStatusDialog(
          context,
          title: 'Chyba při odeslání',
          message: cleanMsg,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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

  Widget _buildUploadStepHero(String slug) {
    final isGpx = slug == 'gpx-upload';
    final isGps = slug == 'gps-tracking';
    final isScreenshot = slug == 'screenshot-upload';

    late final List<Color> gradientColors;
    late final String pill;
    late final String headline;
    late final String sub;

    if (isGpx) {
      gradientColors = const [Color(0xFFD5F8E4), Color(0xFF59DF87)];
      pill = 'GPX soubor';
      headline = 'Nahrát z appky';
      sub = 'Export trasy z hodinek nebo aplikace (Mapy.cz, Strava a další).';
    } else if (isGps) {
      gradientColors = const [Color(0xFFE0E7FF), Color(0xFF6366F1)];
      pill = 'GPS v telefonu';
      headline = 'Záznam z aplikace';
      sub =
          'Trasa je už načtená z měření — v dalších krocích doplníte název, datum, témata a místa jako na webu.';
    } else if (isScreenshot) {
      gradientColors = const [Color(0xFFF2F9C4), Color(0xFFB6DB2E)];
      pill = 'Screenshot';
      headline = 'Nahrát screenshot';
      sub = 'Nahrajte screenshot mapy a důkazní fotky z výletu.';
    } else {
      gradientColors = const [Color(0xFFF2F9C4), Color(0xFFB6DB2E)];
      pill = 'Nahrání trasy';
      headline = 'Nahrát trasu';
      sub = 'Postupujte podle polí níže.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradientColors,
        ),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              pill,
              style: GoogleFonts.libreFranklin(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            headline,
            style: AppTheme.editorialHeadline(
              color: AppColors.textPrimary,
              fontSize: 30,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            style: GoogleFonts.libreFranklin(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadRulesOverview() {
    return FormSectionCard(
      title: 'Rychlý přehled',
      subtitle: 'Stejné kontrolní body jako na webu před pokračováním.',
      icon: Icons.info_outline_rounded,
      child: Column(
        children: const [
          _RuleRow(
            icon: Icons.photo_camera_back_outlined,
            text: 'Důkazní fotky mají být v časové návaznosti k datu návštěvy.',
          ),
          SizedBox(height: 8),
          _RuleRow(
            icon: Icons.directions_walk_rounded,
            text: 'Body se počítají jen pro chůzi a korektně vyplněná bodovaná místa.',
          ),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.libreFranklin(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
