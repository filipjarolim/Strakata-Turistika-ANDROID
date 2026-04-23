import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/forms/form_config.dart';
import '../../../models/forms/form_context.dart';
import '../form_design.dart';

class TitleInputWidget extends StatelessWidget {
  final FormFieldWidget field;

  const TitleInputWidget({Key? key, required this.field}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formContext = Provider.of<FormContext>(context);

    return FormSectionCard(
      title: field.label,
      icon: Icons.route_rounded,
      child: TextFormField(
        initialValue: formContext.routeTitle,
        decoration: FormDesign.inputDecoration(
          label: field.label,
          hint: 'Např. Výstup na Sněžku',
        ),
        onChanged: (value) => formContext.updateField('routeTitle', value),
        validator: field.required
            ? (value) => (value == null || value.isEmpty) ? 'Povinné pole' : null
            : null,
      ),
    );
  }
}
