import '../../models/forms/form_config.dart';
import '../../models/forms/form_context.dart';

String _storageName(FormFieldWidget field) =>
    field.metadata['name']?.toString().trim().isNotEmpty == true
        ? field.metadata['name']!.toString().trim()
        : field.id;

bool _isMissing(dynamic value) {
  if (value == null) return true;
  if (value is String && value.trim().isEmpty) return true;
  if (value is List && value.isEmpty) return true;
  return false;
}

/// Validace pole podle typu z DB (stejný model jako web `competition-form-validation.ts`).
String? validateFormField(FormContext c, FormFieldWidget field) {
  if (!field.required) return null;

  switch (field.type) {
    case 'gpx_upload':
      if (c.trackingSummary == null || c.trackingSummary!.trackPoints.length < 2) {
        return 'Nahrajte platný soubor trasy s alespoň dvěma body.';
      }
      return null;
    case 'image_upload':
      if (c.photoAttachments.isEmpty) {
        return 'Nahrajte alespoň jednu fotografii.';
      }
      return null;
    case 'strakata_route_selector':
      final id = c.extraData['strakataRouteId']?.toString() ?? '';
      if (id.trim().isEmpty) {
        return 'Vyberte kategorii Strakaté trasy.';
      }
      return null;
    case 'title_input':
      if ((c.routeTitle ?? '').trim().isEmpty) {
        return 'Pole "${field.label}" je povinné.';
      }
      return null;
    case 'calendar':
    case 'date':
      if (field.type == 'calendar') {
        if (c.visitDate.isAfter(DateTime.now().add(const Duration(days: 1)))) {
          return 'Datum návštěvy nemůže být v budoucnosti.';
        }
        return null;
      }
      final key = _storageName(field);
      final v = c.extraData[key] ?? c.extraData[field.id];
      if (_isMissing(v)) {
        return 'Pole "${field.label}" je povinné.';
      }
      return null;
    case 'description_input':
      if ((c.routeDescription ?? '').trim().isEmpty) {
        return 'Pole "${field.label}" je povinné.';
      }
      return null;
    case 'dog_switch':
      return null;
    case 'places_manager':
      if (c.places.isEmpty) {
        return 'Přidejte alespoň jedno bodované místo.';
      }
      return null;
    case 'route_summary':
    case 'map_preview':
      return null;
    case 'monthly_theme':
      final n = c.monthlyThemeKeywordCount;
      if (n == null) {
        return 'Chvilku počkejte, načítá se téma měsíce…';
      }
      if (n == 0) return null;
      final raw = c.extraData['themeKeywordsSelected'];
      final picked = raw is List
          ? raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
          : const <String>[];
      if (picked.isEmpty) {
        return 'Vyberte alespoň jedno klíčové slovo tématu měsíce.';
      }
      return null;
    case 'checkbox':
      final key = _storageName(field);
      final v = c.extraData[key] ?? c.extraData[field.id];
      if (v != true) {
        return 'Pole "${field.label}" je povinné.';
      }
      return null;
    case 'number':
      final name = _storageName(field);
      dynamic value = c.extraData[name] ?? c.extraData[field.id];
      final label = field.label.toLowerCase();
      if (_isMissing(value)) {
        if (label.contains('vzdálenost') ||
            name == 'distanceKm' ||
            name == 'distance') {
          final s = c.trackingSummary;
          if (s != null && s.totalDistance > 0) {
            value = (s.totalDistance / 1000).toStringAsFixed(2);
          }
        } else if (name == 'duration' ||
            label.contains('čas') ||
            label.contains('trvání') ||
            label.contains('trvani')) {
          final s = c.trackingSummary;
          if (s != null && s.duration.inSeconds > 0) {
            value = ((s.duration.inSeconds / 60).ceil()).toString();
          }
        }
      }
      if (_isMissing(value)) {
        return 'Pole "${field.label}" je povinné.';
      }
      return null;
    case 'text':
    case 'email':
    case 'textarea':
    case 'select':
      final name = _storageName(field);
      final value = c.extraData[name] ?? c.extraData[field.id];
      if (_isMissing(value)) {
        return 'Pole "${field.label}" je povinné.';
      }
      return null;
    default:
      final name = _storageName(field);
      final value = c.extraData[name] ?? c.extraData[field.id];
      if (_isMissing(value)) {
        return 'Pole "${field.label}" je povinné.';
      }
      return null;
  }
}

/// Doplňková pravidla pro krok „edit“ (název ≥ 3 znaky, místa, datum).
String? validateEditStep(FormContext c) {
  final title = (c.routeTitle ?? '').trim();
  if (title.length < 3) {
    return 'Název trasy musí mít alespoň 3 znaky.';
  }
  if (c.visitDate.isAfter(DateTime.now().add(const Duration(days: 1)))) {
    return 'Datum návštěvy nemůže být v budoucnosti.';
  }
  if (c.places.any((p) => p.name.trim().isEmpty)) {
    return 'Doplňte název u všech přidaných míst.';
  }
  return null;
}

String? validateFormStep(FormContext c, FormStep step) {
  for (final field in step.fields) {
    if (!field.required) continue;
    final err = validateFormField(c, field);
    if (err != null) return err;
  }
  if (step.id == 'edit') {
    return validateEditStep(c);
  }
  return null;
}
