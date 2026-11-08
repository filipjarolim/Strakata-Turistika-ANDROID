import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/forms/form_config.dart';
import '../../../models/forms/form_context.dart';
import '../../../services/auth_service.dart';
import '../../image_picker_widget.dart';
import '../form_design.dart';

class ImageUploadWidget extends StatelessWidget {
  final FormFieldWidget field;

  const ImageUploadWidget({Key? key, required this.field}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formContext = Provider.of<FormContext>(context);

    final placeHasPhoto = formContext.places.any(
      (place) => place.photos.any((photo) => photo.url.trim().isNotEmpty),
    );
    final subtitle = placeHasPhoto && formContext.photoAttachments.isEmpty
        ? 'Fotky pořízené u bodovaných míst jsou už uložené. Další sem přidávat nemusíte.'
        : 'Přidejte fotky jako důkaz návštěvy místa.';

    return FormSectionCard(
      title: field.label,
      subtitle: subtitle,
      icon: Icons.photo_library_outlined,
      child: ImagePickerWidget(
        title: field.label,
        embedded: true,
        initialAttachments: formContext.photoAttachments,
        allowAdminTestPhoto: (AuthService.currentUser?.role ?? '') == 'ADMIN',
        onImagesSelected: formContext.replacePhotoAttachments,
      ),
    );
  }
}
