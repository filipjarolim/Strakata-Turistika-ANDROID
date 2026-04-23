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
    
    // Initialize context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _formContext.initializeWith(
        summary: widget.trackingSummary,
        existingVisit: widget.existingVisit,
      );
    });
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
                  final validationError = _validateStep(step);
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

  String? _validateStep(FormStep step) {
    for (final field in step.fields) {
      if (!field.required) continue;
      final err = _validateField(field);
      if (err != null) return err;
    }
    if (step.id == 'edit') {
      final title = (_formContext.routeTitle ?? '').trim();
      if (title.length < 3) {
        return 'Název trasy musí mít alespoň 3 znaky.';
      }
      if (_formContext.visitDate.isAfter(
        DateTime.now().add(const Duration(days: 1)),
      )) {
        return 'Datum návštěvy nemůže být v budoucnosti.';
      }
      final hasUnnamedPlaces = _formContext.places.any(
        (p) => p.name.trim().isEmpty,
      );
      if (hasUnnamedPlaces) {
        return 'Doplňte název u všech přidaných míst.';
      }
    }
    return null;
  }

  String? _validateField(FormFieldWidget field) {
    switch (field.type) {
      case 'gpx_upload':
        if (_formContext.trackingSummary == null ||
            _formContext.trackingSummary!.trackPoints.length < 2) {
          return 'Nahrajte platný GPX soubor s body trasy.';
        }
        return null;
      case 'image_upload':
        if (_formContext.selectedImages.isEmpty) {
          return 'Nahrajte alespoň jednu fotografii.';
        }
        return null;
      case 'strakata_route_selector':
        final id = _formContext.extraData['strakataRouteId']?.toString() ?? '';
        if (id.trim().isEmpty) {
          return 'Vyberte kategorii Strakaté trasy.';
        }
        return null;
      case 'title_input':
        final title = (_formContext.routeTitle ?? '').trim();
        if (title.isEmpty) {
          return 'Pole "${field.label}" je povinné.';
        }
        return null;
      case 'calendar':
        return null;
      default:
        final name = field.metadata['name']?.toString() ?? field.id;
        final value =
            _formContext.extraData[name] ?? _formContext.extraData[field.id];
        final missing = value == null ||
            (value is String && value.trim().isEmpty) ||
            (value is List && value.isEmpty);
        if (missing) return 'Pole "${field.label}" je povinné.';
        return null;
    }
  }

  Future<void> _handleSubmit() async {
    setState(() => _isSubmitting = true);
    
    try {
      // 1. Calculate points
      double points = 0.0;
      final scoringConfig = await ScoringConfigService().getConfig();
      final placeTypeConfigs = await PlaceTypeConfigService().getPlaceTypeConfigs();
      
      // Distance points
      if (_formContext.trackingSummary != null) {
        double distanceKm = _formContext.trackingSummary!.totalDistance / 1000;
        points += distanceKm * scoringConfig.pointsPerKm;
      }

      // Place points
      for (var place in _formContext.places) {
        final matches = placeTypeConfigs.where((c) => c.name == place.type.name);
        if (matches.isEmpty) {
          throw Exception('Konfigurace typu místa "${place.type.name}" nebyla nalezena v databázi.');
        }
        final typeConfig = matches.first;
        points += typeConfig.points;
      }

      // 2. Prepare VisitData object
      final currentUser = AuthService.currentUser;
      
      // Upload Photos if any (images are in _formContext.selectedImages (File))
      List<Map<String, dynamic>>? photos;
      if (_formContext.selectedImages.isNotEmpty) {
         try {
           final urls = await CloudinaryService.uploadMultipleImages(_formContext.selectedImages);
           photos = urls.map((url) => {
             'url': url,
             'uploadedAt': DateTime.now().toIso8601String(),
           }).toList();
         } catch (e) {
           throw Exception('Nahrání fotografií selhalo: $e');
         }
      }

      final visit = VisitData(
        id: widget.existingVisit?.id ?? '',
        userId: currentUser?.id,
        user: currentUser != null ? {'name': currentUser.name, 'email': currentUser.email, 'image': currentUser.image} : null,
        year: _formContext.visitDate.year,
        visitDate: _formContext.visitDate,
        createdAt: widget.existingVisit?.createdAt ?? DateTime.now(),
        state: VisitState.PENDING_REVIEW,
        points: points,
        routeTitle: _formContext.routeTitle ?? 'Trasa ${DateTime.now().day}.${DateTime.now().month}.',
        routeDescription: _formContext.routeDescription ?? '',
        visitedPlaces: _formContext.places.map((p) => p.name).join(', '),
        dogName: _formContext.extraData['dog_name']?.toString() ?? currentUser?.dogName,
        dogNotAllowed: _formContext.dogNotAllowed ? 'true' : null,
        extraData: _formContext.extraData,
        photos: photos,
        route: _formContext.trackingSummary != null ? {
           'duration': _formContext.trackingSummary!.duration.inSeconds,
           'totalDistance': _formContext.trackingSummary!.totalDistance,
           'trackPoints': _formContext.trackingSummary!.trackPoints.map((p) => p.toJson()).toList(),
        } : null,
        places: _formContext.places,
        extraPoints: {
          'source': widget.slug == 'strakata-upload'
              ? 'strakata_route'
              : (widget.slug == 'gpx-upload'
                  ? 'gpx_upload'
                  : (widget.slug == 'screenshot-upload'
                      ? 'screenshot'
                      : 'gps_tracking')),
          if (widget.slug == 'strakata-upload')
            'strakataRouteId': _formContext.extraData['strakataRouteId'],
          if (widget.slug == 'strakata-upload')
            'strakataRouteLabel': _formContext.extraData['strakataRouteLabel'],
        },
      );

      final success = await VisitRepository().saveVisit(visit);
      
      if (success) {
        if (mounted) {
          await showFormStatusDialog(
            context,
            title: 'Návštěva uložena',
            message: 'Vaše návštěva byla úspěšně odeslána ke kontrole.',
            onConfirm: () => Navigator.of(context).popUntil((route) => route.isFirst),
          );
        }
      } else {
        if (mounted) {
          await showFormStatusDialog(
            context,
            title: 'Uložení selhalo',
            message: 'Při ukládání došlo k chybě. Zkuste to znovu.',
          );
        }
      }

    } catch (e) {
      print('Submission error: $e');
      if (mounted) {
        await showFormStatusDialog(
          context,
          title: 'Chyba',
          message: 'Došlo k neočekávané chybě: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildUploadStepHero(String slug) {
    final isGpx = slug == 'gpx-upload';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isGpx
              ? const [Color(0xFFD5F8E4), Color(0xFF59DF87)]
              : const [Color(0xFFF2F9C4), Color(0xFFB6DB2E)],
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
              'Nahrání trasy',
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
            isGpx ? 'Nahrát z appky' : 'Nahrát screenshot',
            style: AppTheme.editorialHeadline(
              color: AppColors.textPrimary,
              fontSize: 30,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            isGpx
                ? 'Export trasy z hodinek nebo aplikace (Mapy.cz, Strava a další).'
                : 'Nahrajte screenshot mapy a navazující důkazní fotky z výletu.',
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
