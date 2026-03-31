import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/visit_data.dart';
import '../../models/place_type_config.dart';
import '../../repositories/visit_repository.dart';
import '../../services/scoring_config_service.dart';
import '../../services/form_field_service.dart' hide FormField;
import '../../services/form_field_service.dart' as form_service;
import '../../services/auth_service.dart';
import 'system_overview_page.dart';
import '../../widgets/admin/admin_widgets.dart';
import '../../widgets/admin/admin_dialogs.dart';
import '../../widgets/admin/admin_tabs.dart';
import '../../widgets/ui/app_toast.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/strakata_primitives.dart';
import '../../widgets/ui/glass_ui.dart';
import '../../widgets/maps/shared_map_widget.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'admin_dashboard_tab.dart';
import 'admin_raw_data_tab.dart';

enum AdminSubPage { hub, overview, review, settings, rawData }

// ...


class AdminReviewPage extends StatefulWidget {
  const AdminReviewPage({Key? key}) : super(key: key);

  @override
  State<AdminReviewPage> createState() => _AdminReviewPageState();
}

class _AdminReviewPageState extends State<AdminReviewPage> with TickerProviderStateMixin {
  final VisitRepository _visitRepository = VisitRepository();
  final ScoringConfigService _scoringService = ScoringConfigService();
  final FormFieldService _formFieldService = FormFieldService();
  
  // Core state
  List<VisitData> _visitDataList = [];
  VisitState _selectedFilter = VisitState.PENDING_REVIEW;
  bool _isLoading = true;
  int _tabIndex = 0;
  AdminSubPage _currentSubPage = AdminSubPage.hub;
  
  // Search and filters
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'visitDate';
  bool _sortDesc = true;

  // Scoring config state
  ScoringConfig? _scoringConfig;
  bool _isScoringLoading = true;
  bool _savingScoring = false;
  final TextEditingController _pointsPerKmController = TextEditingController();
  final TextEditingController _minDistanceKmController = TextEditingController();
  bool _requireAtLeastOnePlace = true;

  // Form fields state
  List<form_service.FormField> _dynamicFormFields = [];
  bool _isFormEditorOpen = false;
  bool _isSavingForm = false;
  
  // Place types state
  List<PlaceTypeConfig> _placeTypes = [];
  bool _isPlaceTypesLoading = false;
  bool _hasPendingFormChanges = false;
  bool _hasPendingPlaceTypeChanges = false;

  // Bulk actions
  Set<String> _selectedVisitIds = {};
  bool _isBulkMode = false;
  
  // Activity tracking
  List<Map<String, dynamic>> _adminActions = [];
  
  // Collapsible state for form tab
  bool _isScoringExpanded = true;
  bool _isFormFieldsExpanded = true;
  bool _isPlaceTypesExpanded = true;
  
  // Animation controllers
  late TabController _tabController;
  late AnimationController _fadeController;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fadeController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _slideController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    
    _loadVisitData();
    _loadScoringConfig();
    _loadFormFields();
    _loadPlaceTypes();
    _logAdminAction('Admin panel opened');
    
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadVisitData() async {
    setState(() => _isLoading = true);
    try {
      // Use repository. Default getVisits returns map {data: [], total: int}
      // state param is not directly supported in getVisits for specific enum, only 'approved' boolean.
      // We fetch all non-approved (or all) and filter.
      final result = await _visitRepository.getVisits(
        page: 1,
        limit: 100, // Or higher if needed
        searchQuery: _searchQuery,
        onlyApproved: false,
      );
      
      var visits = (result['data'] as List<dynamic>).cast<VisitData>();
      
      // Local filter for state
      if (_selectedFilter != null) {
         visits = visits.where((v) => v.state == _selectedFilter).toList();
      }
      
      // Local sort if needed (Repository does date desc by default)
      if (_sortBy == 'visitDate') {
        visits.sort((a, b) {
           final d1 = a.visitDate ?? DateTime(2000);
           final d2 = b.visitDate ?? DateTime(2000);
           return _sortDesc ? d2.compareTo(d1) : d1.compareTo(d2);
        });
      } else if (_sortBy == 'points') {
         visits.sort((a, b) => _sortDesc ? b.points.compareTo(a.points) : a.points.compareTo(b.points));
      }

      if (mounted) {
        setState(() {
          _visitDataList = visits;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Chyba při načítání dat: $e');
      }
    }
  }

  Future<void> _openVisitDetails(VisitData visit) async {
    await _showRouteDetailsSheet(visit);
  }

  Future<void> _loadScoringConfig() async {
    setState(() => _isScoringLoading = true);
    try {
      final config = await _scoringService.getConfig();
      if (mounted) {
        setState(() {
          _scoringConfig = config;
          _isScoringLoading = false;
          _updateControllersFromConfig();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScoringLoading = false);
        _showErrorSnackBar('Chyba při načítání konfigurace bodování: $e');
      }
    }
  }

  Future<void> _loadFormFields() async {
    try {
      final fields = await _formFieldService.getFormFields(showInactive: true);
      if (mounted) {
        setState(() => _dynamicFormFields = fields);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Chyba při načítání polí formuláře: $e');
      }
    }
  }

  Future<void> _loadPlaceTypes() async {
    setState(() => _isPlaceTypesLoading = true);
    try {
      final placeTypeService = PlaceTypeConfigService();
      final placeTypes = await placeTypeService.getPlaceTypeConfigs();
      if (mounted) {
        setState(() {
          _placeTypes = placeTypes;
          _isPlaceTypesLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPlaceTypesLoading = false);
        _showErrorSnackBar('Chyba při načítání typů míst: $e');
      }
    }
  }

  // Place type management methods
  void _showAddPlaceTypeDialog() {
    AdminDialogs.showAddPlaceTypeDialog(
      context,
      onPlaceTypeAdded: (placeType) async {
        // Prevent duplicates by id
        if (_placeTypes.any((pt) => pt.id == placeType.id)) {
          _showErrorSnackBar('Typ s tímto ID již existuje');
          return;
        }
        setState(() => _placeTypes.add(placeType));
        try {
          final placeTypeService = PlaceTypeConfigService();
          final ok = await placeTypeService.savePlaceTypeConfigs(_placeTypes);
          if (!ok) throw Exception('Uložení do databáze selhalo');
          await _loadPlaceTypes();
          _showSuccessSnackBar('Typ místa byl přidán');
          _logAdminAction('Place type added: ${placeType.label}');
        } catch (e) {
          _showErrorSnackBar('Chyba při ukládání typu místa: $e');
        }
      },
    );
  }

  void _showEditPlaceTypeDialog(PlaceTypeConfig placeType) {
    AdminDialogs.showEditPlaceTypeDialog(
      context,
      placeType,
      onPlaceTypeUpdated: (updatedPlaceType) async {
        setState(() {
          final index = _placeTypes.indexWhere((pt) => pt.id == updatedPlaceType.id);
          if (index != -1) {
            _placeTypes[index] = updatedPlaceType;
          }
        });
        try {
          final placeTypeService = PlaceTypeConfigService();
          final ok = await placeTypeService.updatePlaceTypeConfig(updatedPlaceType);
          if (!ok) throw Exception('Uložení do databáze selhalo');
          await _loadPlaceTypes();
          _showSuccessSnackBar('Typ místa byl upraven');
          _logAdminAction('Place type edited: ${updatedPlaceType.label}');
        } catch (e) {
          _showErrorSnackBar('Chyba při ukládání typu místa: $e');
        }
      },
    );
  }

  void _showDeletePlaceTypeDialog(PlaceTypeConfig placeType) {
    AdminDialogs.showDeletePlaceTypeDialog(
      context,
      placeType,
      onConfirm: () async {
        try {
          final placeTypeService = PlaceTypeConfigService();
          await placeTypeService.deletePlaceTypeConfig(placeType.id);
          setState(() => _placeTypes.removeWhere((pt) => pt.id == placeType.id));
          _logAdminAction('Place type deleted: ${placeType.label}');
          _showSuccessSnackBar('Typ místa byl smazán');
        } catch (e) {
          _showErrorSnackBar('Chyba při mazání typu místa: $e');
        }
      },
    );
  }

  Future<void> _togglePlaceTypeStatus(PlaceTypeConfig placeType, bool isActive) async {
    try {
      final placeTypeService = PlaceTypeConfigService();
      await placeTypeService.updatePlaceTypeStatus(placeType.id, isActive);
      setState(() {
        final index = _placeTypes.indexWhere((pt) => pt.id == placeType.id);
        if (index != -1) {
          _placeTypes[index] = placeType.copyWith(isActive: isActive);
        }
      });
      _logAdminAction('Place type status toggled: ${placeType.label} -> ${isActive ? "Aktivní" : "Neaktivní"}');
    } catch (e) {
      _showErrorSnackBar('Chyba při změně stavu typu místa: $e');
    }
  }

  Future<void> _reorderPlaceTypes(List<String> placeTypeIds) async {
    try {
      final placeTypeService = PlaceTypeConfigService();
      await placeTypeService.reorderPlaceTypes(placeTypeIds);
      await _loadPlaceTypes(); // Reload to get new order
      _logAdminAction('Place types reordered');
    } catch (e) {
      _showErrorSnackBar('Chyba při změně pořadí typů míst: $e');
    }
  }

  void _updateControllersFromConfig() {
    if (_scoringConfig != null) {
      _pointsPerKmController.text = _scoringConfig!.pointsPerKm.toString();
      _minDistanceKmController.text = _scoringConfig!.minDistanceKm.toString();
      _requireAtLeastOnePlace = _scoringConfig!.requireAtLeastOnePlace;
    }
  }

  // Tab management
  void _onTabChanged(int index) {
    setState(() => _tabIndex = index);
    _tabController.animateTo(index);
    _logAdminAction('Switched to tab: ${['Kontrola', 'Formulář', 'Typy míst'][index]}');
  }

  // Search and filtering
  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    _loadVisitData();
  }

  void _onSortChanged(String sortBy) {
    setState(() => _sortBy = sortBy);
    _loadVisitData();
  }

  void _onSortDirectionChanged() {
    setState(() => _sortDesc = !_sortDesc);
    _loadVisitData();
  }

  // Bulk actions
  void _toggleBulkMode() {
    setState(() {
      _isBulkMode = !_isBulkMode;
      if (!_isBulkMode) {
        _selectedVisitIds.clear();
      }
    });
    _logAdminAction(_isBulkMode ? 'Bulk mode enabled' : 'Bulk mode disabled');
  }

  void _toggleVisitSelection(String visitId) {
    setState(() {
      if (_selectedVisitIds.contains(visitId)) {
        _selectedVisitIds.remove(visitId);
      } else {
        _selectedVisitIds.add(visitId);
      }
    });
  }

  Future<void> _bulkApprove() async {
    if (_selectedVisitIds.isEmpty) return;
    
    try {
      await _visitRepository.bulkUpdateVisitStates(_selectedVisitIds, VisitState.APPROVED);
      _showSuccessSnackBar('${_selectedVisitIds.length} návštěv bylo schváleno');
      _logAdminAction('Bulk approved ${_selectedVisitIds.length} visits');
      
        setState(() {
        _selectedVisitIds.clear();
        _isBulkMode = false;
      });
      _loadVisitData();
    } catch (e) {
      _showErrorSnackBar('Chyba při hromadném schvalování: $e');
    }
  }

  Future<void> _bulkReject() async {
    if (_selectedVisitIds.isEmpty) return;
    
    try {
      await _visitRepository.bulkUpdateVisitStates(_selectedVisitIds, VisitState.REJECTED);
      _showSuccessSnackBar('${_selectedVisitIds.length} návštěv bylo odmítnuto');
      _logAdminAction('Bulk rejected ${_selectedVisitIds.length} visits');
      
      setState(() {
        _selectedVisitIds.clear();
        _isBulkMode = false;
      });
      _loadVisitData();
    } catch (e) {
      _showErrorSnackBar('Chyba při hromadném odmítání: $e');
    }
  }

  // Form and scoring actions
  Future<void> _saveScoringConfig() async {
    if (_scoringConfig == null) return;
    
    setState(() => _savingScoring = true);
    try {
      final updatedConfig = ScoringConfig(
        id: _scoringConfig?.id ?? 'default_scoring_config',
        pointsPerKm: double.tryParse(_pointsPerKmController.text) ?? 0,
        minDistanceKm: double.tryParse(_minDistanceKmController.text) ?? 0,
        requireAtLeastOnePlace: _requireAtLeastOnePlace,
        placeTypePoints: _scoringConfig?.placeTypePoints ?? {
          'PEAK': 1.0,
          'TOWER': 1.0,
          'TREE': 1.0,
          'OTHER': 0.0,
        },
        active: true,
        updatedAt: DateTime.now(),
        updatedBy: AuthService.currentUser?.id,
      );
      
      final success = await _scoringService.saveConfig(updatedConfig);
      if (success) {
        _showSuccessSnackBar('Konfigurace bodování byla uložena');
        _logAdminAction('Scoring config updated');
        
        setState(() {
          _scoringConfig = updatedConfig;
          _savingScoring = false;
        });
      } else {
        setState(() => _savingScoring = false);
        _showErrorSnackBar('Chyba při ukládání do databáze. Zkuste to znovu.');
      }
    } catch (e) {
      setState(() => _savingScoring = false);
      if (e.toString().contains('MongoDB ConnectionException')) {
        _showErrorSnackBar('Chyba připojení k databázi. Zkontrolujte internetové připojení.');
      } else {
        _showErrorSnackBar('Chyba při ukládání konfigurace: $e');
      }
    }
  }

  // Nové metody pro správu place type points
  Future<void> _addPlaceTypePoints(String placeType, double points) async {
    if (_scoringConfig == null) return;
    
    // Pokud je placeType prázdný, zobrazíme dialog
    if (placeType.isEmpty) {
      final result = await AdminDialogs.showAddPlaceTypePointsDialog(
        context,
        _scoringConfig!,
      );
      if (result != null) {
        await _savePlaceTypePoints(result['placeType'] as String, result['points'] as double);
      }
      return;
    }
    
    // Jinak uložíme přímo
    await _savePlaceTypePoints(placeType, points);
  }

  Future<void> _savePlaceTypePoints(String placeType, double points) async {
    if (_scoringConfig == null) return;
    
    setState(() => _savingScoring = true);
    try {
      final updatedPlaceTypePoints = Map<String, double>.from(_scoringConfig!.placeTypePoints);
      updatedPlaceTypePoints[placeType] = points;
      
      final updatedConfig = _scoringConfig!.copyWith(
        placeTypePoints: updatedPlaceTypePoints,
        updatedAt: DateTime.now(),
        updatedBy: AuthService.currentUser?.id,
      );
      
      final success = await _scoringService.saveConfig(updatedConfig);
      if (success) {
        _showSuccessSnackBar('Typ místa "$placeType" byl přidán s ${points} body');
        _logAdminAction('Place type added: $placeType with $points points');
        
                                setState(() {
          _scoringConfig = updatedConfig;
          _savingScoring = false;
        });
      } else {
        setState(() => _savingScoring = false);
        _showErrorSnackBar('Chyba při ukládání do databáze. Zkuste to znovu.');
      }
    } catch (e) {
      setState(() => _savingScoring = false);
      if (e.toString().contains('MongoDB ConnectionException')) {
        _showErrorSnackBar('Chyba připojení k databázi. Zkontrolujte internetové připojení.');
      } else {
        _showErrorSnackBar('Chyba při přidávání typu místa: $e');
      }
    }
  }

  Future<void> _removePlaceTypePoints(String placeType) async {
    if (_scoringConfig == null) return;
    
    // Zobrazíme potvrzovací dialog
    final shouldRemove = await AdminDialogs.showRemovePlaceTypePointsDialog(
      context,
      placeType,
      _scoringConfig!.getPointsForPlaceType(placeType),
    );
    
    if (!shouldRemove) return;
    
    setState(() => _savingScoring = true);
    try {
      final updatedPlaceTypePoints = Map<String, double>.from(_scoringConfig!.placeTypePoints);
      updatedPlaceTypePoints.remove(placeType);
      
      final updatedConfig = _scoringConfig!.copyWith(
        placeTypePoints: updatedPlaceTypePoints,
      updatedAt: DateTime.now(),
        updatedBy: AuthService.currentUser?.id,
      );
      
      final success = await _scoringService.saveConfig(updatedConfig);
      if (success) {
        _showSuccessSnackBar('Typ místa "$placeType" byl odebrán');
        _logAdminAction('Place type removed: $placeType');
    
    setState(() {
          _scoringConfig = updatedConfig;
          _savingScoring = false;
        });
      } else {
        setState(() => _savingScoring = false);
        _showErrorSnackBar('Chyba při ukládání do databáze. Zkuste to znovu.');
      }
    } catch (e) {
      setState(() => _savingScoring = false);
      if (e.toString().contains('MongoDB ConnectionException')) {
        _showErrorSnackBar('Chyba připojení k databázi. Zkontrolujte internetové připojení.');
      } else {
        _showErrorSnackBar('Chyba při odebírání typu místa: $e');
      }
    }
  }

  Future<void> _saveDynamicForm() async {
    setState(() => _isSavingForm = true);
    try {
      await _formFieldService.saveFormFields(_dynamicFormFields);
      _showSuccessSnackBar('Formulář byl uložen');
      _logAdminAction('Dynamic form updated');
      setState(() => _isSavingForm = false);
    } catch (e) {
      setState(() => _isSavingForm = false);
      _showErrorSnackBar('Chyba při ukládání formuláře: $e');
    }
  }

  void _addNewFormField() {
    AdminDialogs.showAddFormFieldDialog(
      context,
      onFieldAdded: (field) {
        setState(() => _dynamicFormFields.add(field));
        _logAdminAction('Form field added: ${field.label}');
        _markFormChangedAndSuggestSave();
      },
    );
  }

  void _editFormField(form_service.FormField field) {
    AdminDialogs.showEditFormFieldDialog(
      context,
      field,
      onFieldUpdated: (updatedField) {
        setState(() {
          final index = _dynamicFormFields.indexWhere((f) => f.id == updatedField.id);
          if (index != -1) {
            _dynamicFormFields[index] = updatedField;
          }
        });
        _logAdminAction('Form field edited: ${updatedField.label}');
        _markFormChangedAndSuggestSave();
      },
    );
  }

  void _deleteFormField(String fieldId) {
    AdminDialogs.showDeleteFormFieldDialog(
      context,
      onConfirm: () {
        setState(() {
          _dynamicFormFields.removeWhere((f) => f.id == fieldId);
        });
        _logAdminAction('Form field deleted');
        _markFormChangedAndSuggestSave();
      },
    );
  }

  void _showFormPreview() {
    AdminDialogs.showFormPreviewSheet(
      context,
      _dynamicFormFields,
      _scoringConfig,
    );
  }

  void _markFormChangedAndSuggestSave() {
    _hasPendingFormChanges = true;
    _suggestSave(
      message: 'Změny ve formuláři nejsou uloženy.',
      actionLabel: 'Uložit formulář',
      onAction: _saveDynamicForm,
    );
  }

  void _markPlaceTypesChangedAndSuggestSave() {
    _hasPendingPlaceTypeChanges = true;
    _suggestSave(
      message: 'Změny v typech míst nejsou uloženy.',
      actionLabel: 'Uložit pořadí',
      onAction: () async {
        final ids = _placeTypes.map((e) => e.id).toList();
        await _reorderPlaceTypes(ids);
      },
    );
  }

  void _suggestSave({
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    AppToast.showSuccess(
      context, 
      message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  // Utility methods
  void _showErrorSnackBar(String message) {
    AppToast.showError(context, message);
  }

  void _showSuccessSnackBar(String message) {
    AppToast.showSuccess(context, message);
  }

  void _showManagePlaceTypesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const StrakataSheetHandle(margin: EdgeInsets.only(top: 12)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Správa typů míst',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: _placeTypes.length,
                      onReorder: (oldIndex, newIndex) {
                        setSheetState(() {
                          if (oldIndex < newIndex) newIndex -= 1;
                          final item = _placeTypes.removeAt(oldIndex);
                          _placeTypes.insert(newIndex, item);
                        });
                        setState(() {});
                        _markPlaceTypesChangedAndSuggestSave();
                      },
                      itemBuilder: (context, index) {
                        final placeType = _placeTypes[index];
                        return Container(
                          key: ValueKey(placeType.id),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: AdminWidgets.buildPlaceTypeCard(
                            placeType: placeType,
                            onEdit: () {
                              Navigator.of(ctx).pop();
                              _showEditPlaceTypeDialog(placeType);
                            },
                            onDelete: () {
                              Navigator.of(ctx).pop();
                              _showDeletePlaceTypeDialog(placeType);
                            },
                            onToggleStatus: (active) async {
                              await _togglePlaceTypeStatus(placeType, active);
                              setSheetState(() {});
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAdminActivityHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const StrakataSheetHandle(
              margin: EdgeInsets.only(top: 12),
              width: 32,
              color: Color(0xFFF3F4F6),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      color: Color(0xFF2E7D32),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Historie aktivit',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'PŘEHLED VŠECH ADMIN AKCÍ'.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey[500],
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildActivityItem(
                      icon: Icons.check_circle_rounded,
                      title: 'Schválení návštěvy',
                      description: 'Návštěva "Krkonoše - Sněžka" byla schválena',
                      time: '2 hodiny zpět',
                      color: const Color(0xFF10B981),
                    ),
                    _buildActivityItem(
                      icon: Icons.cancel_rounded,
                      title: 'Odmítnutí návštěvy',
                      description: 'Návštěva "Praha - Petřín" byla odmítnuta',
                      time: '4 hodiny zpět',
                      color: const Color(0xFFEF4444),
                    ),
                    _buildActivityItem(
                      icon: Icons.edit_rounded,
                      title: 'Úprava konfigurace',
                      description: 'Bodování bylo upraveno na 2.5 bodů/km',
                      time: '1 den zpět',
                      color: const Color(0xFF3B82F6),
                    ),
                    _buildActivityItem(
                      icon: Icons.add_rounded,
                      title: 'Přidání typu místa',
                      description: 'Nový typ místa "Rozhledna" byl přidán',
                      time: '2 dny zpět',
                      color: const Color(0xFF8B5CF6),
                    ),
                    _buildActivityItem(
                      icon: Icons.person_add_rounded,
                      title: 'Registrace uživatele',
                      description: 'Nový uživatel se zaregistroval',
                      time: '3 dny zpět',
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String description,
    required String time,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  time.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[400],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAdminActivityLogs() {
    _showAdminActivityHistorySheet();
  }

  Future<void> _showRouteDetailsSheet(VisitData visit) async {
    // Load full visit with route if needed
    VisitData fullVisit = visit;
    try {
      final loaded = await _visitRepository.getVisitById(visit.id);
      if (loaded != null) fullVisit = loaded;
    } catch (_) {}

    final hasRoute = () {
      if (fullVisit.route == null) return false;
      final List? track = (fullVisit.route!['trackPoints'] as List?) ?? (fullVisit.route!['points'] as List?) ?? (fullVisit.route!['path'] as List?);
      return track != null && track.isNotEmpty;
    }();
    
    // Check if this is a screenshot upload (no GPS data)
    final legacy = fullVisit.photos ?? [];
    final firstPhoto = legacy.isNotEmpty ? legacy.first : null;
    final isScreenshot = !hasRoute && firstPhoto != null && (
      (firstPhoto['title']?.toString().toLowerCase().contains('screenshot') ?? false) ||
      (firstPhoto['title']?.toString().toLowerCase().contains('watch') ?? false) ||
      (firstPhoto['description']?.toString().toLowerCase().contains('screenshot') ?? false)
    );
    
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Stack(
        children: [
          // Blur background
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(color: Colors.black.withOpacity(0.2)),
              ),
            ),
          ),
          // Sheet Content
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(ctx).size.height * 0.9,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const Center(
                    child: StrakataSheetHandle(margin: EdgeInsets.only(top: 12)),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _getStatusColor(visit.state).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getStatusIcon(visit.state),
                            color: _getStatusColor(visit.state),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                visit.routeTitle ?? visit.visitedPlaces,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                visit.displayName ?? 'Neznámý uživatel',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Detailed info chips
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _buildDetailChip(Icons.calendar_today, _formatDate(visit.visitDate), Colors.blue),
                              _buildDetailChip(Icons.star, '${visit.points} bodů', Colors.amber),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          if (visit.routeDescription != null && visit.routeDescription!.isNotEmpty) ...[
                            Text('Poznámka', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Text(visit.routeDescription!, style: const TextStyle(fontSize: 14)),
                            ),
                          ],
                          
                          // Check for screenshots or map data
                           if (hasRoute) ...[
                            const SizedBox(height: 24),
                            const Text(
                              'Mapa trasy',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 350,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.withOpacity(0.2)),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Builder(builder: (context) {
                                final r = visit.route ?? {};
                                final raw = (r['trackPoints'] as List?) ?? (r['points'] as List?) ?? (r['path'] as List?) ?? [];
                                final points = <LatLng>[];
                                for (final item in raw) {
                                  if (item is Map) {
                                    final lat = (item['latitude'] ?? item['lat'] ?? item['y']) as num?;
                                    final lon = (item['longitude'] ?? item['lng'] ?? item['lon'] ?? item['x']) as num?;
                                    if (lat != null && lon != null) {
                                      points.add(LatLng(lat.toDouble(), lon.toDouble()));
                                    }
                                  }
                                }
                                
                                if (points.isEmpty) return const Center(child: Text('Chybí data trasy'));

                                // Calculate bounds
                                double minLat = points.first.latitude;
                                double maxLat = points.first.latitude;
                                double minLng = points.first.longitude;
                                double maxLng = points.first.longitude;
                                
                                for (var p in points) {
                                  if (p.latitude < minLat) minLat = p.latitude;
                                  if (p.latitude > maxLat) maxLat = p.latitude;
                                  if (p.longitude < minLng) minLng = p.longitude;
                                  if (p.longitude > maxLng) maxLng = p.longitude;
                                }
                                final centerLat = (minLat + maxLat) / 2;
                                final centerLng = (minLng + maxLng) / 2;
                                
                                return SharedMapWidget(
                                  center: LatLng(centerLat, centerLng),
                                  zoom: 13,
                                  polylines: [
                                    Polyline(
                                      points: points,
                                      strokeWidth: 4,
                                      color: Colors.blue,
                                    ),
                                  ],
                                  markers: [
                                     Marker(
                                      point: points.first,
                                      width: 12,
                                      height: 12,
                                      child: Container(
                                        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                      ),
                                    ),
                                    Marker(
                                      point: points.last,
                                      width: 12,
                                      height: 12,
                                      child: Container(
                                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ] else if (isScreenshot && firstPhoto != null) ...[
                            const SizedBox(height: 24),
                            const Text(
                              'Snímek trasy',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 300,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.withOpacity(0.2)),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.network(
                                firstPhoto['url'] ?? '',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  // Actions Footer
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey[200]!)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (visit.state == VisitState.PENDING_REVIEW) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: AppButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _approveVisit(visit.id);
                                    },
                                    text: 'Schválit',
                                    icon: Icons.check_circle_outline,
                                    type: AppButtonType.primary,
                                    size: AppButtonSize.large,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: AppButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _rejectVisit(visit.id);
                                    },
                                    text: 'Zamítnout',
                                    icon: Icons.cancel_outlined,
                                    type: AppButtonType.destructive,
                                    size: AppButtonSize.large,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          AppButton(
                            onPressed: () async {
                              // We can close manual sheet or keep it open?
                              // Dialog logic usually pops dialog.
                              // Let's call the dialog helper for editing points
                              await AdminDialogs.showEditPointsDialog(context, visit);
                              // Refresh logic? Dialog updates DB.
                              // We might need to refresh the list after edit.
                            },
                            text: 'Upravit body',
                            icon: Icons.edit_outlined,
                            type: AppButtonType.secondary,
                            size: AppButtonSize.medium,
                            expand: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Neznámé datum';
    return '${date.day}.${date.month}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }


  IconData _getPlaceTypeIcon(PlaceType type) {
    switch (type) {
      case PlaceType.PEAK:
        return Icons.landscape;
      case PlaceType.TOWER:
        return Icons.location_city;
      case PlaceType.TREE:
        return Icons.park;
      case PlaceType.OTHER:
        return Icons.place;
    }
  }

  Color _getStatusColor(VisitState state) {
    switch (state) {
      case VisitState.APPROVED:
        return const Color(0xFF4CAF50);
      case VisitState.PENDING_REVIEW:
        return const Color(0xFFFFA726);
      case VisitState.REJECTED:
        return const Color(0xFFEF5350);
      case VisitState.DRAFT:
        return const Color(0xFF9E9E9E);
    }
  }

  IconData _getStatusIcon(VisitState state) {
    switch (state) {
      case VisitState.APPROVED:
        return Icons.check_circle_outline;
      case VisitState.PENDING_REVIEW:
        return Icons.schedule;
      case VisitState.REJECTED:
        return Icons.cancel_outlined;
      case VisitState.DRAFT:
        return Icons.edit_outlined;
    }
  }

  String _getStatusText(VisitState state) {
    switch (state) {
      case VisitState.APPROVED:
        return 'Schváleno';
      case VisitState.PENDING_REVIEW:
        return 'Čeká na schválení';
      case VisitState.REJECTED:
        return 'Odmítnuto';
      case VisitState.DRAFT:
        return 'Návrh';
    }
  }

  void _logAdminAction(String action) {
    _adminActions.add({
      'timestamp': DateTime.now(),
      'action': action,
    });
    
    // Keep only last 100 actions
    if (_adminActions.length > 100) {
      _adminActions.removeAt(0);
    }
  }

  // Review actions
  Future<void> _approveVisit(String visitId) async {
    try {
      await _visitRepository.updateVisitState(visitId, VisitState.APPROVED);
      _logAdminAction('Approved visit: $visitId');
      _showSuccessSnackBar('Návštěva byla schválena');
      _loadVisitData();
    } catch (e) {
      _showErrorSnackBar('Chyba při schvalování návštěvy: $e');
    }
  }

  Future<void> _rejectVisit(String visitId) async {
    try {
      await _visitRepository.updateVisitState(visitId, VisitState.REJECTED);
      _logAdminAction('Rejected visit: $visitId');
      _showSuccessSnackBar('Návštěva byla zamítnuta');
      _loadVisitData();
    } catch (e) {
      _showErrorSnackBar('Chyba při zamítání návštěvy: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isLoggedIn) {
      return GlassScaffold(
        body: Center(
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block, size: 64, color: Colors.red[300]),
                const SizedBox(height: 24),
                Text(
                  'Přístup odepřen',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.red[600],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Vyžadována oprávnění administrátora',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                AppButton(
                  onPressed: () => Navigator.pop(context),
                  text: 'Zpět',
                  type: AppButtonType.secondary,
                  size: AppButtonSize.medium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GlassScaffold(
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeController,
              child: _buildCurrentPage(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    String title = 'Admin Hub';
    String subtitle = 'Správa aplikace';
    bool showBack = false;

    switch (_currentSubPage) {
      case AdminSubPage.hub:
        title = 'Admin Hub';
        subtitle = 'Vyberte sekci ke správě';
        break;
      case AdminSubPage.overview:
        title = 'Přehled systému';
        subtitle = 'Statistiky a logy';
        showBack = true;
        break;
      case AdminSubPage.review:
        title = 'Kontrola návštěv';
        subtitle = 'Schvalování tras';
        showBack = true;
        break;
      case AdminSubPage.settings:
        title = 'Nastavení';
        subtitle = 'Formulář a bodování';
        showBack = true;
        break;
      case AdminSubPage.rawData:
        title = 'Raw Data';
        subtitle = 'Prohlížení databáze';
        showBack = true;
        break;
    }

    return GlassHeader(
      title: title,
      subtitle: subtitle,
      leading: IconButton(
        onPressed: () {
          if (_currentSubPage == AdminSubPage.hub) {
            Navigator.pop(context);
          } else {
            setState(() => _currentSubPage = AdminSubPage.hub);
          }
        },
        icon: Icon(showBack ? Icons.arrow_back : Icons.close, size: 24, color: const Color(0xFF1A1A1A)),
      ),
      trailing: _currentSubPage == AdminSubPage.hub ? IconButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SystemOverviewPage()),
          );
        },
        icon: const Icon(Icons.info_outline, size: 24, color: Color(0xFF1A1A1A)),
      ) : null,
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentSubPage) {
      case AdminSubPage.hub:
        return _buildAdminHub();
      case AdminSubPage.overview:
        return const AdminDashboardTab();
      case AdminSubPage.review:
        return AdminTabs.buildControlTab(
          visitDataList: _visitDataList,
          isLoading: _isLoading,
          isRefreshing: false,
          onVisitTap: (visit) => _openVisitDetails(visit),
          onRefresh: () async {
            await _loadVisitData();
            _showSuccessSnackBar('Data byla aktualizována');
          },
          searchQuery: _searchQuery,
          onSearchChanged: _onSearchChanged,
          sortBy: _sortBy,
          onSortChanged: _onSortChanged,
          sortDesc: _sortDesc,
          onSortDirectionChanged: _onSortDirectionChanged,
          isBulkMode: _isBulkMode,
          selectedVisitIds: _selectedVisitIds,
          onToggleVisitSelection: _toggleVisitSelection,
          onToggleBulkMode: _toggleBulkMode,
          onShowAdminActivityLogs: _showAdminActivityLogs,
          onBulkApprove: _bulkApprove,
          onBulkReject: _bulkReject,
          searchController: _searchController,
          onShowRouteDetailsSheet: (visit) => _openVisitDetails(visit),
        );
      case AdminSubPage.settings:
        return AdminTabs.buildFormTab(
          formFields: _dynamicFormFields,
          isLoading: _isScoringLoading || _isPlaceTypesLoading,
          scoringConfig: _scoringConfig,
          pointsPerKmController: _pointsPerKmController,
          minDistanceKmController: _minDistanceKmController,
          requireAtLeastOnePlace: _requireAtLeastOnePlace,
          onRequireAtLeastOnePlaceChanged: (val) {
            setState(() => _requireAtLeastOnePlace = val ?? true);
          },
          onPreview: _showFormPreview,
          onAddField: _addNewFormField,
          onEditField: _editFormField,
          onDeleteField: _deleteFormField,
          onSaveScoring: _saveScoringConfig,
          onSaveForm: _saveDynamicForm,
          savingScoring: _savingScoring,
          savingForm: _isSavingForm,
          placeTypes: _placeTypes,
          isPlaceTypesLoading: _isPlaceTypesLoading,
          onEditPlaceType: _showEditPlaceTypeDialog,
          onTogglePlaceTypeStatus: (pt, active) => _togglePlaceTypeStatus(pt, active),
          onDeletePlaceType: (id) {
            final pt = _placeTypes.firstWhere((e) => e.id == id);
            _showDeletePlaceTypeDialog(pt);
          },
          onManagePlaceTypes: _showManagePlaceTypesSheet,
          isScoringExpanded: _isScoringExpanded,
          isFormFieldsExpanded: _isFormFieldsExpanded,
          isPlaceTypesExpanded: _isPlaceTypesExpanded,
          onScoringExpandedChanged: (val) => setState(() => _isScoringExpanded = val),
          onFormFieldsExpandedChanged: (val) => setState(() => _isFormFieldsExpanded = val),
          onPlaceTypesExpandedChanged: (val) => setState(() => _isPlaceTypesExpanded = val),
          onReorderFields: (oldIdx, newIdx) async {
            setState(() {
              if (oldIdx < newIdx) newIdx -= 1;
              final item = _dynamicFormFields.removeAt(oldIdx);
              _dynamicFormFields.insert(newIdx, item);
            });
            try {
              final ids = _dynamicFormFields.map((f) => f.id).toList();
              await _formFieldService.reorderFormFields(ids);
              _logAdminAction('Form fields reordered');
            } catch (e) {
              _showErrorSnackBar('Chyba při změně pořadí: $e');
            }
          },
          onReorderPlaceTypes: (oldIdx, newIdx) async {
            setState(() {
              if (oldIdx < newIdx) newIdx -= 1;
              final item = _placeTypes.removeAt(oldIdx);
              _placeTypes.insert(newIdx, item);
            });
            try {
              final ids = _placeTypes.map((p) => p.id).toList();
              await PlaceTypeConfigService().reorderPlaceTypes(ids);
              _logAdminAction('Place types reordered');
            } catch (e) {
              _showErrorSnackBar('Chyba při změně pořadí: $e');
            }
          },
        );
      case AdminSubPage.rawData:
        return const AdminRawDataTab();
    }
  }

  Widget _buildAdminHub() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _buildHubCard(
                'Přehled',
                'Statistiky systému',
                Icons.dashboard_outlined,
                const Color(0xFF3B82F6),
                AdminSubPage.overview,
              ),
              _buildHubCard(
                'Kontrola',
                'Schvalování tras',
                Icons.fact_check_outlined,
                const Color(0xFF10B981),
                AdminSubPage.review,
              ),
              _buildHubCard(
                'Nastavení',
                'Formulář a body',
                Icons.settings_suggest_outlined,
                const Color(0xFFF59E0B),
                AdminSubPage.settings,
              ),
              _buildHubCard(
                'Raw Data',
                'Prohlížení DB',
                Icons.data_object_outlined,
                const Color(0xFF8B5CF6),
                AdminSubPage.rawData,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildActivityQuickView(),
        ],
      ),
    );
  }

  Widget _buildHubCard(String title, String subtitle, IconData icon, Color color, AdminSubPage target) {
    return GestureDetector(
      onTap: () => setState(() => _currentSubPage = target),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF111827),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityQuickView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, size: 20, color: Color(0xFF111827)),
              const SizedBox(width: 10),
              Text(
                'POSLEDNÍ AKTIVITA'.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF111827),
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _showAdminActivityLogs,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'ZOBRAZIT VŠE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_adminActions.isEmpty)
             Text(
              'Žádná nedávná aktivita',
              style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w500),
            )
          else
            ..._adminActions.reversed.take(3).map((action) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.bolt_rounded, size: 20, color: Colors.blue[600]),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action['action'] as String,
                          style: const TextStyle(
                            fontSize: 14, 
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Před chvílí', // Could be formatted time
                          style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildScreenshotPreview(Map<String, dynamic> photo) {
    final url = (photo['url'] ?? '').toString();
    final title = photo['title']?.toString();
    final description = photo['description']?.toString();
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screenshot image
          Stack(
            children: [
              Image.network(
                url,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 250,
                  color: const Color(0xFFF5F6F7),
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Color(0xFF9E9E9E), size: 48),
                  ),
                ),
              ),
              // Badge
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.watch, size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'GPS Screenshot z hodinek',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Info
          if (title != null || description != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFFF8FAFC),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (description != null) const SizedBox(height: 4),
                  ],
                  if (description != null)
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRouteMap(VisitData visit) {
    final r = visit.route ?? {};
    final raw = (r['trackPoints'] as List?) ?? (r['points'] as List?) ?? (r['path'] as List?) ?? [];
    final points = <LatLng>[];
    for (final item in raw) {
      if (item is Map) {
        final lat = (item['latitude'] ?? item['lat'] ?? item['y']) as num?;
        final lon = (item['longitude'] ?? item['lng'] ?? item['lon'] ?? item['x']) as num?;
        if (lat != null && lon != null) {
          points.add(LatLng(lat.toDouble(), lon.toDouble()));
        }
      } else if (item is List && item.length >= 2) {
        final a = item[0];
        final b = item[1];
        if (a is num && b is num) {
          points.add(LatLng(a.toDouble(), b.toDouble()));
        }
      }
    }
    
    // Calculate bounds
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    
    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    
    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: points.isNotEmpty ? points[points.length ~/ 2] : points.first,
          initialZoom: 13,
          minZoom: 5,
          maxZoom: 18,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.strakataturistika',
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                strokeWidth: 4,
                color: const Color(0xFF3B82F6),
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: points.first,
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(Icons.flag, color: Colors.white, size: 20),
                ),
              ),
              Marker(
                point: points.last,
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(Icons.flag, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<bool?> _showApproveDialog(BuildContext context, VisitData visit) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Schválit návštěvu?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              visit.routeTitle ?? visit.visitedPlaces,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${visit.points.toStringAsFixed(1)} bodů',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Opravdu chcete schválit tuto návštěvu?',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Schválit'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showRejectDialog(BuildContext context, VisitData visit) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.cancel, color: Color(0xFFEF4444), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Odmítnout návštěvu?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              visit.routeTitle ?? visit.visitedPlaces,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${visit.points.toStringAsFixed(1)} bodů',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Opravdu chcete odmítnout tuto návštěvu?',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Odmítnout'),
          ),
        ],
      ),
    );
  }

  // Build photos section for bottom sheet
  Widget _buildPhotosSection(BuildContext context, VisitData visit) {
    final legacy = visit.photos ?? [];
    final placePhotos = visit.places
        .expand((p) => p.photos)
        .map((ph) => ph.url)
        .toList();
    
    // Combine photos with metadata
    final allPhotoData = <Map<String, dynamic>>[];
    
    // Legacy photos (may include screenshots from web)
    for (final photo in legacy) {
      final url = (photo['url'] ?? '').toString();
      if (url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('/') || url.startsWith('file://'))) {
        allPhotoData.add({
          'url': url,
          'title': photo['title']?.toString(),
          'description': photo['description']?.toString(),
          'isScreenshot': (photo['title']?.toString().toLowerCase().contains('screenshot') ?? false) ||
                         (photo['title']?.toString().toLowerCase().contains('watch') ?? false) ||
                         (photo['description']?.toString().toLowerCase().contains('screenshot') ?? false),
        });
      }
    }
    
    // Place photos
    for (final url in placePhotos) {
      if (url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('/') || url.startsWith('file://'))) {
        allPhotoData.add({
          'url': url,
          'isScreenshot': false,
        });
      }
    }
    
    final allPhotos = allPhotoData.map((p) => p['url'] as String).toList();

    if (allPhotos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Fotografie',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${allPhotos.length} ${allPhotos.length == 1 ? 'fotka' : allPhotos.length < 5 ? 'fotky' : 'fotek'}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: allPhotos.length,
          itemBuilder: (context, index) {
            final photoData = allPhotoData[index];
            return _buildPhotoThumbnail(
              context, 
              allPhotos[index], 
              allPhotos, 
              index,
              isScreenshot: photoData['isScreenshot'] as bool? ?? false,
              title: photoData['title'] as String?,
            );
          },
        ),
      ],
    );
  }

  Widget _buildPhotoThumbnail(
    BuildContext context, 
    String photoUrl, 
    List<String> allPhotos, 
    int index, {
    bool isScreenshot = false,
    String? title,
  }) {
    final cleanPath = photoUrl.startsWith('file://') ? photoUrl.substring(7) : photoUrl;
    final isLocalFile = cleanPath.startsWith('/');

    return GestureDetector(
      onTap: () => _showPhotoViewer(context, allPhotos, index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            isLocalFile
                ? Image.file(
                    File(cleanPath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFFFFEBEE),
                      child: const Icon(Icons.broken_image, color: Color(0xFFE53935)),
                    ),
                  )
                : Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: const Color(0xFFF5F6F7),
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                            color: const Color(0xFF4CAF50),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFFFFF3E0),
                      child: const Icon(Icons.broken_image, color: Color(0xFFFF9800)),
                    ),
                  ),
            // Screenshot badge (top left)
            if (isScreenshot)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.watch, size: 10, color: Colors.white),
                      const SizedBox(width: 2),
                      Text(
                        'GPS',
                        style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            // Index badge (top right)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPhotoViewer(BuildContext context, List<String> photos, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (context) => _PhotoViewerDialog(photos: photos, initialIndex: initialIndex),
    );
  }
}

// Fullscreen Photo Viewer Dialog
class _PhotoViewerDialog extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;

  const _PhotoViewerDialog({
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<_PhotoViewerDialog> createState() => _PhotoViewerDialogState();
}

class _PhotoViewerDialogState extends State<_PhotoViewerDialog> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _downloadPhoto() async {
    setState(() => _isDownloading = true);
    try {
      final photoUrl = widget.photos[_currentIndex];
      final cleanPath = photoUrl.startsWith('file://') ? photoUrl.substring(7) : photoUrl;
      final isLocal = cleanPath.startsWith('/');

      if (isLocal) {
        final sourceFile = File(cleanPath);
        if (await sourceFile.exists()) {
          final downloadsDir = await getExternalStorageDirectory();
          final fileName = 'strakata_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final targetPath = '${downloadsDir!.path}/$fileName';
          await sourceFile.copy(targetPath);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Fotka uložena: $targetPath'),
                backgroundColor: const Color(0xFF4CAF50),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        final response = await http.get(Uri.parse(photoUrl));
        if (response.statusCode == 200) {
          final downloadsDir = await getExternalStorageDirectory();
          final fileName = 'strakata_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final filePath = '${downloadsDir!.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Fotka stažena: $filePath'),
                backgroundColor: const Color(0xFF4CAF50),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba při stahování: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Photo viewer with zoom and swipe
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photos.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final photoUrl = widget.photos[index];
              final cleanPath = photoUrl.startsWith('file://') ? photoUrl.substring(7) : photoUrl;
              final isLocal = cleanPath.startsWith('/');

              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: isLocal
                      ? Image.file(
                          File(cleanPath),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFF1F2937),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, size: 64, color: Colors.white70),
                                  SizedBox(height: 16),
                                  Text('Soubor nenalezen', style: TextStyle(color: Colors.white70)),
                                ],
                              ),
                            ),
                          ),
                        )
                      : Image.network(
                          photoUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                                color: Colors.white,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFF1F2937),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, size: 64, color: Colors.white70),
                                  SizedBox(height: 16),
                                  Text('Chyba načítání', style: TextStyle(color: Colors.white70)),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              );
            },
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                ),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.5)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${widget.photos.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),

          // Bottom bar with download button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: AppButton(
                    onPressed: _isDownloading ? null : _downloadPhoto,
                    text: _isDownloading ? 'Stahování...' : 'Stáhnout fotku',
                    icon: _isDownloading ? null : Icons.download,
                    type: AppButtonType.primary,
                    size: AppButtonSize.medium,
                    isLoading: _isDownloading,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}