import '../models/visit_data.dart';
import '../models/place_type_config.dart';
import '../services/form_field_service.dart' as form_service;
import '../services/scoring_config_service.dart';
import '../repositories/visit_repository.dart';

class AdminServices {

  // Visit Data Management
  static Future<void> bulkUpdateVisitStates(
    Set<String> visitIds,
    VisitState newState, {
    String? rejectionReason,
  }) async {
    try {
      final visitRepo = VisitRepository();
      
      for (final visitId in visitIds) {
        await visitRepo.updateVisitState(
          visitId,
          newState,
          rejectionReason: rejectionReason, // Note: updateVisitState supports rejectionReason named param? Yes I added it.
        );
      }
    } catch (e) {
      throw Exception('Chyba při hromadné aktualizaci stavů návštěv: $e');
    }
  }

  static Future<void> updateVisitState(
    String visitId,
    VisitState newState, {
    String? rejectionReason,
    String? adminNotes,
  }) async {
    try {
      final visitRepo = VisitRepository();
      await visitRepo.updateVisitState(
        visitId,
        newState,
        rejectionReason: rejectionReason,
      );
    } catch (e) {
      throw Exception('Chyba při aktualizaci stavu návštěvy: $e');
    }
  }

  static Future<List<VisitData>> getVisitDataForReview({
    VisitState? state,
    String? searchQuery,
    String? sortBy,
    bool? sortDescending,
    int? limit,
    int? offset,
  }) async {
    try {
      final visitRepo = VisitRepository();
      // Fetch all visits to filter locally to match legacy service behavior exact match
      // Ideally move filtering to DB but for now robust refactor:
      final result = await visitRepo.getVisits(limit: 1000, onlyApproved: false, searchQuery: searchQuery);
      final allVisits = (result['data'] as List<dynamic>).cast<VisitData>();
      
      var filteredVisits = allVisits;
      
      // Apply state filter
      if (state != null) {
        filteredVisits = filteredVisits.where((visit) => visit.state == state).toList();
      }
      
      // Search query is already applied by repo technically if passed, but repo search is "any match".
      // Previous logic reused.
      
      // Apply sorting
      if (sortBy != null) {
        if (sortBy == 'visitDate') {
          filteredVisits.sort((a, b) {
            final aDate = a.visitDate ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.visitDate ?? DateTime.fromMillisecondsSinceEpoch(0);
            return sortDescending == true ? bDate.compareTo(aDate) : aDate.compareTo(bDate);
          });
        } else if (sortBy == 'points') {
          filteredVisits.sort((a, b) {
            return sortDescending == true ? b.points.compareTo(a.points) : a.points.compareTo(b.points);
          });
        }
      }
      
      // Apply pagination
      if (offset != null && limit != null) {
        final start = offset;
        final end = (start + limit).clamp(0, filteredVisits.length);
        filteredVisits = filteredVisits.sublist(start, end);
      } else if (limit != null) {
        filteredVisits = filteredVisits.take(limit).toList();
      }
      
      return filteredVisits;
    } catch (e) {
      throw Exception('Chyba při načítání návštěv: $e');
    }
  }

  // Scoring Configuration Management
  static Future<ScoringConfig> getScoringConfig() async {
    try {
      final scoringService = ScoringConfigService();
      return await scoringService.getConfig();
    } catch (e) {
      throw Exception('Chyba při načítání konfigurace bodování: $e');
    }
  }

  static Future<void> updateScoringConfig(ScoringConfig config) async {
    try {
      final scoringService = ScoringConfigService();
      await scoringService.saveConfig(config);
    } catch (e) {
      throw Exception('Chyba při ukládání konfigurace bodování: $e');
    }
  }

  // Form Fields Management
  static Future<List<form_service.FormField>> getFormFields() async {
    try {
      final formService = form_service.FormFieldService();
      return await formService.getFormFields();
    } catch (e) {
      throw Exception('Chyba při načítání polí formuláře: $e');
    }
  }

  static Future<void> updateFormFields(List<form_service.FormField> fields) async {
    try {
      final formService = form_service.FormFieldService();
      await formService.saveFormFields(fields);
    } catch (e) {
      throw Exception('Chyba při ukládání polí formuláře: $e');
    }
  }

  static Future<void> addFormField(form_service.FormField field) async {
    try {
      final formService = form_service.FormFieldService();
      await formService.addFormField(field);
    } catch (e) {
      throw Exception('Chyba při přidávání pole formuláře: $e');
    }
  }

  static Future<void> updateFormField(form_service.FormField field) async {
    try {
      final formService = form_service.FormFieldService();
      await formService.updateFormField(field);
    } catch (e) {
      throw Exception('Chyba při aktualizaci pole formuláře: $e');
    }
  }

  static Future<void> deleteFormField(String fieldId) async {
    try {
      final formService = form_service.FormFieldService();
      await formService.deleteFormField(fieldId);
    } catch (e) {
      throw Exception('Chyba při mazání pole formuláře: $e');
    }
  }

  // Place Types Management
  static Future<List<PlaceTypeConfig>> getPlaceTypes() async {
    try {
      final placeTypeService = PlaceTypeConfigService();
      return await placeTypeService.getPlaceTypeConfigs();
    } catch (e) {
      throw Exception('Chyba při načítání typů míst: $e');
    }
  }

  static Future<void> addPlaceType(PlaceTypeConfig placeType) async {
    try {
      final placeTypeService = PlaceTypeConfigService();
      await placeTypeService.savePlaceTypeConfigs([placeType]);
    } catch (e) {
      throw Exception('Chyba při přidávání typu místa: $e');
    }
  }

  static Future<void> updatePlaceType(PlaceTypeConfig placeType) async {
    try {
      final placeTypeService = PlaceTypeConfigService();
      await placeTypeService.updatePlaceTypeConfig(placeType);
    } catch (e) {
      throw Exception('Chyba při aktualizaci typu místa: $e');
    }
  }

  static Future<void> deletePlaceType(String placeTypeId) async {
    try {
      final placeTypeService = PlaceTypeConfigService();
      // This method would need to be implemented
      print('Delete place type not implemented yet');
    } catch (e) {
      throw Exception('Chyba při mazání typu místa: $e');
    }
  }

  static Future<void> togglePlaceTypeStatus(String placeTypeId, bool isActive) async {
    try {
      final placeTypeService = PlaceTypeConfigService();
      // This method would need to be implemented
      print('Toggle place type status not implemented yet');
    } catch (e) {
      throw Exception('Chyba při změně stavu typu místa: $e');
    }
  }

  static Future<void> reorderPlaceTypes(List<String> placeTypeIds) async {
    try {
      final placeTypeService = PlaceTypeConfigService();
      // This method would need to be implemented
      print('Reorder place types not implemented yet');
    } catch (e) {
      throw Exception('Chyba při změně pořadí typů míst: $e');
    }
  }

  // Statistics and Analytics
  static Future<Map<String, dynamic>> getAdminStatistics() async {
    try {
      final stats = <String, dynamic>{};
      
      // Visit statistics
      final visitRepo = VisitRepository();
      final result = await visitRepo.getVisits(limit: 5000, onlyApproved: false);
      final allVisits = (result['data'] as List<dynamic>).cast<VisitData>();
      
      final totalVisits = allVisits.length;
      final pendingVisits = allVisits.where((visit) => visit.state == VisitState.PENDING_REVIEW).length;
      final approvedVisits = allVisits.where((visit) => visit.state == VisitState.APPROVED).length;
      final rejectedVisits = allVisits.where((visit) => visit.state == VisitState.REJECTED).length;
      
      stats['totalVisits'] = totalVisits;
      stats['pendingVisits'] = pendingVisits;
      stats['approvedVisits'] = approvedVisits;
      stats['rejectedVisits'] = rejectedVisits;
      
      // Form fields statistics
      final formService = form_service.FormFieldService();
      final formFields = await formService.getFormFields();
      stats['totalFormFields'] = formFields.length;
      
      // Place types statistics
      final placeTypeService = PlaceTypeConfigService();
      final placeTypes = await placeTypeService.getPlaceTypeConfigs();
      final activePlaceTypes = placeTypes.where((type) => type.isActive).length;
      
      stats['totalPlaceTypes'] = placeTypes.length;
      stats['activePlaceTypes'] = activePlaceTypes;
      
      return stats;
    } catch (e) {
      throw Exception('Chyba při načítání statistik: $e');
    }
  }

  // User Management
  static Future<List<Map<String, dynamic>>> getAdminUsers() async {
    try {
      // This would need to be implemented with your user management system
      return [];
    } catch (e) {
      throw Exception('Chyba při načítání admin uživatelů: $e');
    }
  }

  static Future<void> updateUserRole(String userId, String newRole) async {
    try {
      // This would need to be implemented with your user management system
    } catch (e) {
      throw Exception('Chyba při změně role uživatele: $e');
    }
  }

  // System Maintenance
  static Future<void> clearOldVisitData(DateTime cutoffDate) async {
    try {
      final visitRepo = VisitRepository();
      final result = await visitRepo.getVisits(limit: 5000, onlyApproved: false);
      final allVisits = (result['data'] as List<dynamic>).cast<VisitData>();
      
      for (final visit in allVisits) {
        if (visit.createdAt != null && visit.createdAt!.isBefore(cutoffDate)) {
           await visitRepo.deleteVisit(visit.id);
        }
      }
    } catch (e) {
      throw Exception('Chyba při čištění starých dat: $e');
    }
  }

  static Future<void> backupConfiguration() async {
    try {
      // This could be implemented to export configurations to files
      print('Backup configuration not implemented yet');
    } catch (e) {
      throw Exception('Chyba při zálohování konfigurace: $e');
    }
  }

  static Future<Map<String, dynamic>?> restoreConfiguration(String backupId) async {
    try {
      // This could be implemented to restore configurations from files
      print('Restore configuration not implemented yet');
      return null;
    } catch (e) {
      throw Exception('Chyba při obnovení zálohy: $e');
    }
  }

  // Audit Logging
  static Future<void> logAdminAction(String action, {
    String? userId,
    String? userEmail,
    Map<String, dynamic>? details,
    String? targetId,
    String? targetType,
  }) async {
    try {
      // This could be implemented to log to local storage or a logging service
      print('Admin action logged: $action');
    } catch (e) {
      // Don't throw here as audit logging shouldn't break main functionality
      print('Chyba při logování admin akce: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getAuditLogs({
    DateTime? startDate,
    DateTime? endDate,
    String? action,
    String? userId,
    int? limit,
  }) async {
    try {
      // This would need to be implemented with a proper logging system
      return [];
    } catch (e) {
      throw Exception('Chyba při načítání audit logů: $e');
    }
  }
}
