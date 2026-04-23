import 'package:flutter/material.dart';
import '../../models/forms/form_config.dart';
import 'widgets/title_input_widget.dart';
import 'widgets/description_input_widget.dart';
import 'widgets/calendar_input_widget.dart';
import 'widgets/dog_switch_widget.dart';
import 'widgets/gpx_upload_widget.dart';
import 'widgets/map_preview_widget.dart';
import 'widgets/image_upload_widget.dart';
import 'widgets/places_manager_widget.dart';
import 'widgets/route_summary_widget.dart';
import 'widgets/strakata_route_selector_widget.dart';
import 'widgets/monthly_theme_widget.dart';
import 'widgets/extra_data_field_widgets.dart';

class FormWidgetFactory {
  static Widget build(FormFieldWidget field) {
    switch (field.type) {
      case 'title_input':
        return TitleInputWidget(field: field);
      case 'description_input':
        return DescriptionInputWidget(field: field);
      case 'calendar':
        return CalendarInputWidget(field: field);
      case 'dog_switch':
        return DogSwitchWidget(field: field);
      case 'gpx_upload':
        return GpxUploadWidget(field: field);
      case 'map_preview':
        return MapPreviewWidget(field: field);
      case 'image_upload':
        return ImageUploadWidget(field: field);
      case 'places_manager':
        return PlacesManagerWidget(field: field);
      case 'route_summary':
        return RouteSummaryWidget(field: field);
      case 'strakata_route_selector':
        return StrakataRouteSelectorWidget(field: field);
      case 'monthly_theme':
        return MonthlyThemeWidget(field: field);
      case 'text':
        return ExtraDataTextFieldWidget(field: field);
      case 'email':
        return ExtraDataTextFieldWidget(
          field: field,
          keyboardType: TextInputType.emailAddress,
        );
      case 'number':
        return ExtraDataNumberFieldWidget(field: field);
      case 'textarea':
        return ExtraDataTextAreaWidget(field: field);
      case 'select':
        return ExtraDataSelectWidget(field: field);
      case 'checkbox':
        return ExtraDataCheckboxWidget(field: field);
      case 'date':
        return ExtraDataDateFieldWidget(field: field);
      default:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Nepodporovaný typ pole: ${field.type}\n'
            '(${field.label}) — doplňte obsluhu ve FormWidgetFactory.',
            style: const TextStyle(fontSize: 13),
          ),
        );
    }
  }
}
