import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/forms/form_config.dart';
import '../../../models/forms/form_context.dart';
import '../../image_picker_widget.dart';
import '../form_design.dart';

class ImageUploadWidget extends StatelessWidget {
  final FormFieldWidget field;

  const ImageUploadWidget({Key? key, required this.field}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formContext = Provider.of<FormContext>(context);

    return FormSectionCard(
      title: field.label,
      subtitle: 'Přidejte fotky jako důkaz návštěvy místa.',
      icon: Icons.photo_library_outlined,
      child: ImagePickerWidget(
        title: field.label,
        initialImages: formContext.selectedImages,
        onImagesSelected: (images) {
           // Clear and add all to keep in sync
           formContext.selectedImages.clear();
           for(var image in images) {
             formContext.addPhoto(image);
           }
        },
      ),
    );
  }
}
