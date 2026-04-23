import '../models/forms/form_config.dart';
import 'database/database_service.dart';

class FormService {
  static final FormService _instance = FormService._internal();
  factory FormService() => _instance;
  FormService._internal();

  /// Stejná kolekce jako Prisma `FormConfig` na webu (`@@map("form_configs")`).
  /// Dříve aplikace četla legacy `forms` — ta data se od adminu lišila.
  static const String _collection = 'form_configs';
  final DatabaseService _dbService = DatabaseService();

  Future<List<FormConfig>> getForms() async {
    return _dbService.execute((db) async {
      final collection = db.collection(_collection);
      final docs = await collection.find().toList();
      return docs.map((doc) => FormConfig.fromJson(doc)).toList();
    }).catchError((e) {
      print('❌ Error getting forms: $e');
      return <FormConfig>[];
    });
  }

  Future<FormConfig?> getFormBySlug(String slug) async {
    return _dbService.execute((db) async {
      final collection = db.collection(_collection);
      final doc = await collection.findOne({'slug': slug});
      if (doc == null) {
        throw Exception(
          'Strict mode: formulář "$slug" nebyl v databázi nalezen.',
        );
      }

      final parsed = FormConfig.fromJson(doc);
      if (parsed.steps.isEmpty) {
        throw Exception(
          'Strict mode: formulář "$slug" v databázi neobsahuje žádné kroky.',
        );
      }
      print('✅ [FormService] Loaded "$slug" form from DB (strict mode)');
      return parsed;
    });
  }
}
