import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/forms/form_config.dart';
import '../../models/forms/form_context.dart';
import '../../services/form_service.dart';
import 'form_widget_factory.dart';
import 'form_design.dart';

class FormRenderer extends StatefulWidget {
  final String slug;
  final Function(FormContext) onSave;

  const FormRenderer({
    Key? key,
    required this.slug,
    required this.onSave,
  }) : super(key: key);

  @override
  State<FormRenderer> createState() => _FormRendererState();
}

class _FormRendererState extends State<FormRenderer> {
  late FormContext _formContext;
  FormConfig? _config;
  int _currentStepIndex = 0;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _formContext = FormContext();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await FormService().getFormBySlug(widget.slug);
      if (mounted) {
        setState(() {
          _config = config;
          _loadError = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _config = null;
          _loadError = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _nextStep() {
    if (_config == null) return;
    final validationError = _validateStep(_config!.steps[_currentStepIndex]);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }
    if (_currentStepIndex < _config!.steps.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
    } else {
      widget.onSave(_formContext);
    }
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
        final value = _formContext.extraData[name] ?? _formContext.extraData[field.id];
        final missing = value == null ||
            (value is String && value.trim().isEmpty) ||
            (value is List && value.isEmpty);
        if (missing) return 'Pole "${field.label}" je povinné.';
        return null;
    }
  }

  void _previousStep() {
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const FormPageShell(
        title: 'Načítání…',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_config == null) {
      return FormPageShell(
        title: 'Formulář',
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _loadError ??
                  'Nepodařilo se načíst konfiguraci formuláře v strict režimu.',
              textAlign: TextAlign.center,
              style: GoogleFonts.libreFranklin(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    final currentStep = _config!.steps[_currentStepIndex];
    final isUploadStep = currentStep.id == 'upload';

    return ChangeNotifierProvider<FormContext>.value(
      value: _formContext,
      child: FormPageShell(
        title: currentStep.label,
        leading: _currentStepIndex > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _previousStep,
              )
            : null,
        body: Column(
          children: [
            _buildProgressBar(),
            Expanded(
              child: ListView.builder(
                padding: FormDesign.pagePadding,
                itemCount: currentStep.fields.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FormStepHeaderCard(
                            title: currentStep.label,
                            subtitle: 'Vyplňte všechna povinná pole.',
                            stepIndex: _currentStepIndex + 1,
                            totalSteps: _config!.steps.length,
                          ),
                          if (isUploadStep) ...[
                            const SizedBox(height: 12),
                            _buildUploadStepHero(_config!.slug),
                            const SizedBox(height: 12),
                            _buildUploadRulesOverview(),
                          ],
                        ],
                      ),
                    );
                  }
                  final field = currentStep.fields[index - 1];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FormWidgetFactory.build(field),
                  );
                },
              ),
            ),
          ],
        ),
        bottomBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildProgressBar() {
    if (_config == null) return const SizedBox.shrink();
    
    return LinearProgressIndicator(
      value: (_currentStepIndex + 1) / _config!.steps.length,
      backgroundColor: const Color(0xFFE8E4DC).withValues(alpha: 0.5),
      valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
    );
  }

  Widget _buildBottomNav() {
    final isLastStep = _currentStepIndex == _config!.steps.length - 1;

    return FormBottomActionBar(
      primaryLabel: isLastStep ? 'Dokončit' : 'Pokračovat',
      onPrimaryPressed: _nextStep,
      secondaryLabel: _currentStepIndex > 0 ? 'Zpět' : null,
      onSecondaryPressed: _currentStepIndex > 0 ? _previousStep : null,
    );
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
            style: GoogleFonts.libreFranklin(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
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
          _UploadRuleRow(
            icon: Icons.photo_camera_back_outlined,
            text: 'Důkazní fotky mají být v časové návaznosti k datu návštěvy.',
          ),
          SizedBox(height: 8),
          _UploadRuleRow(
            icon: Icons.directions_walk_rounded,
            text: 'Body se počítají jen pro chůzi a korektně vyplněná bodovaná místa.',
          ),
        ],
      ),
    );
  }
}

class _UploadRuleRow extends StatelessWidget {
  const _UploadRuleRow({required this.icon, required this.text});

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
