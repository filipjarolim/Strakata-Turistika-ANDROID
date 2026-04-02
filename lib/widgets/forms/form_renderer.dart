import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/forms/form_config.dart';
import '../../models/forms/form_context.dart';
import '../../services/form_service.dart';
import '../strakata_editorial_background.dart';
import '../ui/app_button.dart';
import 'form_widget_factory.dart';

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

  @override
  void initState() {
    super.initState();
    _formContext = FormContext();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await FormService().getFormBySlug(widget.slug);
    if (mounted) {
      setState(() {
        _config = config;
        _isLoading = false;
      });
    }
  }

  void _nextStep() {
    if (_config == null) return;
    if (_currentStepIndex < _config!.steps.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
    } else {
      widget.onSave(_formContext);
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
      return Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: StrakataEditorialBackground()),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: Text(
                'Načítání…',
                style: GoogleFonts.libreFranklin(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            body: Center(child: CircularProgressIndicator(color: AppColors.brand)),
          ),
        ],
      );
    }

    if (_config == null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: StrakataEditorialBackground()),
          Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nepodařilo se načíst konfiguraci formuláře.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.libreFranklin(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final currentStep = _config!.steps[_currentStepIndex];

    return ChangeNotifierProvider<FormContext>.value(
      value: _formContext,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: StrakataEditorialBackground()),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: Text(
                currentStep.label,
                style: GoogleFonts.libreFranklin(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: AppColors.textPrimary,
                ),
              ),
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              elevation: 0,
              foregroundColor: AppColors.textPrimary,
              leading: _currentStepIndex > 0
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: _previousStep,
                    )
                  : null,
            ),
            body: Column(
              children: [
                _buildProgressBar(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: currentStep.fields.length,
                    itemBuilder: (context, index) {
                      final field = currentStep.fields[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: FormWidgetFactory.build(field),
                      );
                    },
                  ),
                ),
              ],
            ),
            bottomNavigationBar: _buildBottomNav(),
          ),
        ],
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
    
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF7),
        border: Border(top: BorderSide(color: const Color(0xFFE8E4DC))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: AppButton(
        onPressed: _nextStep,
        text: isLastStep ? 'Dokončit' : 'Pokračovat',
        type: AppButtonType.primary,
        size: AppButtonSize.large,
        expand: true,
      ),
    );
  }
}
