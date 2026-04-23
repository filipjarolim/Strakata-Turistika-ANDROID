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
    final dynamic definition = json['definition'];
    final dynamic rawSteps = definition is Map<String, dynamic>
        ? definition['steps']
        : json['steps'];
    final List<FormStep> parsedSteps = (rawSteps as List<dynamic>? ?? const [])
        .asMap()
        .entries
        .map(
          (entry) => FormStep.fromJson(
            entry.value as Map<String, dynamic>,
            defaultOrder: entry.key,
          ),
        )
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return FormConfig(
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ??
          (definition is Map<String, dynamic>
              ? definition['name']?.toString() ?? ''
              : ''),
      steps: parsedSteps,
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

  factory FormStep.fromJson(
    Map<String, dynamic> json, {
    int defaultOrder = 0,
  }) {
    final dynamic rawFields = json['fields'];
    final List<FormFieldWidget> parsedFields = (rawFields as List<dynamic>? ?? const [])
        .asMap()
        .entries
        .map(
          (entry) => FormFieldWidget.fromJson(
            entry.value as Map<String, dynamic>,
            defaultOrder: entry.key,
          ),
        )
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return FormStep(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? json['title']?.toString() ?? '',
      order: TypeConverter.toIntWithDefault(json['order'], defaultOrder),
      fields: parsedFields,
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

  factory FormFieldWidget.fromJson(
    Map<String, dynamic> json, {
    int defaultOrder = 0,
  }) {
    return FormFieldWidget(
      id: json['id']?.toString() ?? json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      order: TypeConverter.toIntWithDefault(json['order'], defaultOrder),
      required: json['required'] == true,
      metadata: {
        ...(json['metadata'] as Map<String, dynamic>? ?? {}),
        if (json['name'] != null) 'name': json['name'].toString(),
      },
    );
  }
}
