import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/forms/form_config.dart';
import '../models/forms/form_context.dart';
import '../models/visit_data.dart';
import '../models/tracking_summary.dart';
import '../services/form_service.dart';
import '../widgets/forms/form_widget_factory.dart';
import '../widgets/ui/app_button.dart';
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
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          title: FutureBuilder<FormConfig?>(
            future: _formConfigFuture,
            builder: (context, snapshot) {
              return Text(snapshot.data?.name ?? 'Načítání...');
            },
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: FutureBuilder<FormConfig?>(
          future: _formConfigFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return Center(child: Text('Chyba při načítání formuláře: ${snapshot.error}'));
            }

            final config = snapshot.data!;
            return _buildForm(context, config);
          },
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, FormConfig config) {
    if (config.steps.isEmpty) return const Center(child: Text('Prázdný formulář'));

    // If only one step, show it without stepper navigation
    // But usually we have upload/edit/finish
    // For now, simple logic: Render current step
    
    final step = config.steps[_currentStep];
    final isLastStep = _currentStep == config.steps.length - 1;

    return Column(
      children: [
        // Progress Indicator
        if (config.steps.length > 1)
          LinearProgressIndicator(
            value: (_currentStep + 1) / config.steps.length,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
          ),
        
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.label,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...step.fields.map((field) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: FormWidgetFactory.build(field),
                )),
              ],
            ),
          ),
        ),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
          ),
          child: Row(
            children: [
              if (_currentStep > 0)
                Expanded(
                  child: AppButton(
                    onPressed: () => setState(() => _currentStep--),
                    text: 'Zpět',
                    type: AppButtonType.secondary,
                  ),
                ),
              if (_currentStep > 0) const SizedBox(width: 16),
              Expanded(
                child: AppButton(
                  onPressed: _isSubmitting 
                    ? null 
                    : () {
                        if (isLastStep) {
                          _handleSubmit();
                        } else {
                          // Validate requirements here if needed
                          setState(() => _currentStep++);
                        }
                      },
                  text: isLastStep ? 'Dokončit' : 'Další',
                  type: AppButtonType.primary,
                  isLoading: _isSubmitting,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
        final typeConfig = placeTypeConfigs.firstWhere(
          (c) => c.name == place.type.name,
          orElse: () => PlaceTypeConfig(
            id: 'unknown',
            name: place.type.name,
            label: 'Neznámé',
            icon: Icons.help_outline,
            points: 0,
            color: Colors.grey,
            order: 99,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          )
        );
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
           print("Error uploading images: $e");
           // Fallback or continue without images? user requested robust flow.
           // For now, we continue without them or with local paths if offline support is needed.
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
        extraPoints: {},
      );

      final success = await VisitRepository().saveVisit(visit);
      
      if (success) {
        if (mounted) {
           Navigator.of(context).popUntil((route) => route.isFirst);
           // Show success dialog or snackbar
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Návštěva úspěšně uložena')));
        }
      } else {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chyba při ukládání')));
         }
      }

    } catch (e) {
      print('Submission error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chyba: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
