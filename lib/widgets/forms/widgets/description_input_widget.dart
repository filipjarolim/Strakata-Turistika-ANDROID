import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/forms/form_config.dart';
import '../../../models/forms/form_context.dart';
import '../form_design.dart';

class DescriptionInputWidget extends StatelessWidget {
  final FormFieldWidget field;

  const DescriptionInputWidget({Key? key, required this.field}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formContext = Provider.of<FormContext>(context);

    return FormSectionCard(
      title: field.label,
      subtitle: 'Krátce popište trasu, zážitek nebo důležité detaily.',
      icon: Icons.notes_rounded,
      child: TextFormField(
        initialValue: formContext.routeDescription,
        maxLines: 4,
        decoration: FormDesign.inputDecoration(
          label: field.label,
          hint: 'Popište trasu...',
        ),
        onChanged: (value) => formContext.updateField('routeDescription', value),
        validator: field.required
            ? (value) => (value == null || value.isEmpty) ? 'Povinné pole' : null
            : null,
      ),
    );
  }
}
