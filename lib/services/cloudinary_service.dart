import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/forms/form_image_attachment.dart';

class CloudinaryService {
  static CloudinaryPublic? _cloudinary;

  static CloudinaryPublic get cloudinary {
    if (_cloudinary == null) {
      _cloudinary = CloudinaryPublic(
        dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '',
        'ffenzeso', // Use your existing unsigned preset
        cache: false,
      );
    }
    return _cloudinary!;
  }

  static Future<CloudinaryResponse?> uploadImageResponse(File imageFile) async {
    try {
      if (!await imageFile.exists()) {
        print('❌ Image file does not exist: ${imageFile.path}');
        return null;
      }
      return cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          resourceType: CloudinaryResourceType.Image,
          folder: 'strakataturistika',
        ),
      );
    } catch (e) {
      print('❌ Error uploading image to Cloudinary: $e');
      return null;
    }
  }

  static Future<String?> uploadImage(File imageFile) async {
    final r = await uploadImageResponse(imageFile);
    return r?.secureUrl;
  }

  /// Stejný tvar metadat jako na webu (`public_id`, `title`, `adminBypassPhotoDate`, …).
  static Future<List<Map<String, dynamic>>> uploadVisitPhotoPayloads(
    List<FormImageAttachment> attachments,
  ) async {
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < attachments.length; i++) {
      final att = attachments[i];
      print('📤 Uploading image ${i + 1}/${attachments.length}');
      final response = await uploadImageResponse(att.file);
      if (response == null) continue;
      final title = response.originalFilename.trim().isEmpty
          ? 'foto_${i + 1}'
          : response.originalFilename.trim();
      out.add({
        'url': response.secureUrl,
        'public_id': response.publicId,
        'title': title,
        'description': '',
        'uploadedAt': DateTime.now().toIso8601String(),
        if (att.adminBypassPhotoDate) 'adminBypassPhotoDate': true,
      });
    }
    print('✅ Successfully uploaded ${out.length}/${attachments.length} images');
    return out;
  }

  static Future<List<String>> uploadMultipleImages(List<File> imageFiles) async {
    final wrapped =
        imageFiles.map((f) => FormImageAttachment(f)).toList();
    final payloads = await uploadVisitPhotoPayloads(wrapped);
    return payloads.map((m) => m['url'] as String).toList();
  }
} 