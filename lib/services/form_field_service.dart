import 'database/database_service.dart';
import 'auth_service.dart';
import '../utils/type_converter.dart';

class FormField {
  final String id; // MongoDB _id (internal)
  final String name; // Field identifier (pro kompatibilitu s webem) - např. "dog_name"
  final String label;
  final String type;
  final bool required;
  final List<String> options;
  final String defaultValue;
  final String? placeholder;
  final int order;
  final bool active; // Pro kompatibilitu s webem
  final bool isEditable;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const FormField({
    required this.id,
    required this.name,
    required this.label,
    required this.type,
    this.required = false,
    this.options = const [],
    this.defaultValue = '',
    this.placeholder,
    required this.order,
    this.active = true,
    this.isEditable = true,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  FormField copyWith({
    String? id,
    String? name,
    String? label,
    String? type,
    bool? required,
    List<String>? options,
    String? defaultValue,
    String? placeholder,
    int? order,
    bool? active,
    bool? isEditable,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) => FormField(
        id: id ?? this.id,
        name: name ?? this.name,
        label: label ?? this.label,
        type: type ?? this.type,
        required: required ?? this.required,
        options: options ?? this.options,
        defaultValue: defaultValue ?? this.defaultValue,
        placeholder: placeholder ?? this.placeholder,
        order: order ?? this.order,
        active: active ?? this.active,
        isEditable: isEditable ?? this.isEditable,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        createdBy: createdBy ?? this.createdBy,
        updatedBy: updatedBy ?? this.updatedBy,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name, // Pro kompatibilitu s webem
        'label': label,
        'type': type,
        'required': required,
        'options': options,
        'defaultValue': defaultValue,
        'placeholder': placeholder,
        'order': order,
        'active': active,
        'isEditable': isEditable,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'createdBy': createdBy,
        'updatedBy': updatedBy,
      };

  static FormField fromMap(Map<String, dynamic> map) => FormField(
        id: (map['_id'] ?? map['id'] ?? '').toString(),
        name: (map['name'] ?? map['id'] ?? '').toString(),
        label: map['label']?.toString() ?? '',
        type: map['type']?.toString() ?? 'text',
        required: map['required'] == true,
        options: (map['options'] as List?)?.map((e) => e.toString()).toList() ?? [],
        defaultValue: map['defaultValue']?.toString() ?? '',
        placeholder: map['placeholder']?.toString(),
        order: TypeConverter.toIntWithDefault(map['order'], 0),
        active: map['active'] != false,
        isEditable: map['isEditable'] != false,
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? DateTime.now(),
        createdBy: map['createdBy']?.toString(),
        updatedBy: map['updatedBy']?.toString(),
      );
}

class FormFieldService {
  static final FormFieldService _instance = FormFieldService._internal();
  factory FormFieldService() => _instance;
  FormFieldService._internal();

  static const String _collection = 'form_fields';
  final DatabaseService _dbService = DatabaseService();

  Future<List<FormField>> getFormFields({bool showInactive = false}) async {
    return _dbService.execute((db) async {
      final collection = db.collection(_collection);
      var query = <String, dynamic>{};
      if (!showInactive) {
        query['active'] = true;
      }
      
      final fields = await collection.find(query).toList();
      
      if (fields.isEmpty) {
        await _createDefaultFormFields();
        final refreshedFields = await collection.find(query).toList();
        if (refreshedFields.isEmpty) return <FormField>[];
        
        refreshedFields.sort((a, b) => TypeConverter.toIntWithDefault(a['order'], 0).compareTo(TypeConverter.toIntWithDefault(b['order'], 0)));
        return refreshedFields.map((doc) => FormField.fromMap(doc)).toList();
      }
      
      fields.sort((a, b) => TypeConverter.toIntWithDefault(a['order'], 0).compareTo(TypeConverter.toIntWithDefault(b['order'], 0)));
      return fields.map((doc) => FormField.fromMap(doc)).toList();
    }).catchError((e) {
      print('❌ Error getting form fields: $e');
      return <FormField>[];
    });
  }


  Future<void> _createDefaultFormFields() async {
    return _dbService.execute((db) async {
      final collection = db.collection(_collection);
      final now = DateTime.now();
      final defaultFields = [
        FormField(
          id: 'dog_name',
          name: 'dog_name',
          label: 'Jméno psa',
          type: 'text',
          required: false,
          order: 0,
          createdAt: now,
          updatedAt: now,
        ),
        FormField(
          id: 'dog_not_allowed',
          name: 'dog_not_allowed',
          label: 'Omezení pro psy',
          type: 'textarea',
          required: false,
          order: 1,
          createdAt: now,
          updatedAt: now,
        ),
        FormField(
          id: 'additional_notes',
          name: 'additional_notes',
          label: 'Dodatečné poznámky',
          type: 'textarea',
          required: false,
          order: 2,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final fieldsToSave = defaultFields.map((field) => field.toMap()).toList();
      await collection.insertAll(fieldsToSave);
      print('✅ Default form fields created');
    }).catchError((e) {
      print('❌ Error creating default form fields: $e');
    });
  }

  Future<bool> saveFormFields(List<FormField> fields) async {
    return _dbService.execute((db) async {
      final collection = db.collection(_collection);
      await collection.deleteMany({});
      final currentUser = AuthService.currentUser?.id;
      final now = DateTime.now();
      
      final fieldsToSave = fields.map((field) {
        return field.copyWith(updatedAt: now, updatedBy: currentUser).toMap();
      }).toList();

      if (fieldsToSave.isNotEmpty) {
        await collection.insertAll(fieldsToSave);
      }
      return true;
    }).catchError((e) {
      print('❌ Error saving form fields: $e');
      return false;
    });
  }

  Future<bool> addFormField(FormField field) async {
    return _dbService.execute((db) async {
      final collection = db.collection(_collection);
      final currentUser = AuthService.currentUser?.id;
      final now = DateTime.now();
      
      final fieldToSave = field.copyWith(
        createdAt: now,
        updatedAt: now,
        createdBy: currentUser,
        updatedBy: currentUser,
      );

      await collection.insert(fieldToSave.toMap());
      return true;
    }).catchError((e) {
      print('❌ Error adding form field: $e');
      return false;
    });
  }

  Future<bool> updateFormField(FormField field) async {
    return _dbService.execute((db) async {
      final collection = db.collection(_collection);
      final currentUser = AuthService.currentUser?.id;
      final now = DateTime.now();
      
      final fieldToUpdate = field.copyWith(updatedAt: now, updatedBy: currentUser);
      final result = await collection.replaceOne({'id': field.id}, fieldToUpdate.toMap());
      return result.isSuccess;
    }).catchError((e) {
      print('❌ Error updating form field: $e');
      return false;
    });
  }

  Future<bool> deleteFormField(String fieldId) async {
    return _dbService.execute((db) async {
      final collection = db.collection(_collection);
      final result = await collection.deleteOne({'id': fieldId});
      return result.isSuccess;
    }).catchError((e) {
      print('❌ Error deleting form field: $e');
      return false;
    });
  }

  Future<bool> reorderFormFields(List<String> fieldIds) async {
    return _dbService.execute((db) async {
      final collection = db.collection(_collection);
      for (int i = 0; i < fieldIds.length; i++) {
        await collection.updateOne(
          {'id': fieldIds[i]},
          {'\$set': {'order': i}},
        );
      }
      return true;
    }).catchError((e) {
      print('❌ Error reordering form fields: $e');
      return false;
    });
  }
}
