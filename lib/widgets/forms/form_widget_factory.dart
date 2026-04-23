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
      default:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('Unknown widget type: ${field.type}'),
        );
    }
  }
}
