import 'dart:io';

/// Jedna nahraná fotka ve formuláři (stejná sémantika jako na webu u `adminBypassPhotoDate`).
class FormImageAttachment {
  final File file;
  final bool adminBypassPhotoDate;

  const FormImageAttachment(
    this.file, {
    this.adminBypassPhotoDate = false,
  });
}
