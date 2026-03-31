import '../../utils/type_converter.dart';

class FormConfig {
  final String slug;
  final String name;
  final List<FormStep> steps;

  FormConfig({
    required this.slug,
    required this.name,
    required this.steps,
  });

  factory FormConfig.fromJson(Map<String, dynamic> json) {
    return FormConfig(
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      steps: (json['steps'] as List<dynamic>)
          .map((v) => FormStep.fromJson(v as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order)),
    );
  }
}

class FormStep {
  final String id;
  final String label;
  final int order;
  final List<FormFieldWidget> fields;

  FormStep({
    required this.id,
    required this.label,
    required this.order,
    required this.fields,
  });

  factory FormStep.fromJson(Map<String, dynamic> json) {
    return FormStep(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      order: TypeConverter.toIntWithDefault(json['order'], 0),
      fields: (json['fields'] as List<dynamic>)
          .map((v) => FormFieldWidget.fromJson(v as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order)),
    );
  }
}

class FormFieldWidget {
  final String id;
  final String type;
  final String label;
  final int order;
  final bool required;
  final Map<String, dynamic> metadata;

  FormFieldWidget({
    required this.id,
    required this.type,
    required this.label,
    required this.order,
    this.required = false,
    this.metadata = const {},
  });

  factory FormFieldWidget.fromJson(Map<String, dynamic> json) {
    return FormFieldWidget(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      order: TypeConverter.toIntWithDefault(json['order'], 0),
      required: json['required'] == true,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }
}
