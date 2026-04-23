import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/forms/form_config.dart';
import '../../../models/forms/form_context.dart';
import '../../../config/app_colors.dart';
import '../form_design.dart';

class DogSwitchWidget extends StatelessWidget {
  final FormFieldWidget field;

  const DogSwitchWidget({Key? key, required this.field}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formContext = Provider.of<FormContext>(context);

    return FormSectionCard(
      title: field.label,
      subtitle: 'Označte, pokud byl úsek bez možnosti vstupu se psem.',
      icon: Icons.pets_rounded,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8E4DC)),
        ),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Trasa bez vstupu se psem',
            style: GoogleFonts.libreFranklin(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          value: formContext.dogNotAllowed,
          onChanged: (value) => formContext.updateField('dogNotAllowed', value),
        ),
      ),
    );
  }
}
