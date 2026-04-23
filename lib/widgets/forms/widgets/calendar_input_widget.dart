import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/forms/form_config.dart';
import '../../../models/forms/form_context.dart';
import '../../../config/app_colors.dart';
import '../form_design.dart';

class CalendarInputWidget extends StatelessWidget {
  final FormFieldWidget field;

  const CalendarInputWidget({Key? key, required this.field}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formContext = Provider.of<FormContext>(context);

    return FormSectionCard(
      title: field.label,
      icon: Icons.calendar_today_rounded,
      child: InkWell(
        onTap: () async {
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: formContext.visitDate,
            firstDate: DateTime(2000),
            lastDate: DateTime(2101),
          );
          if (picked != null) {
            formContext.updateField('visitDate', picked);
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration: FormDesign.inputDecoration(
            label: field.label,
            prefixIcon: const Icon(Icons.event_rounded),
          ),
          child: Text(
            '${formContext.visitDate.day}.${formContext.visitDate.month}.${formContext.visitDate.year}',
            style: GoogleFonts.libreFranklin(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
