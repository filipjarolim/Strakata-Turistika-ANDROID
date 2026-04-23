import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  
  static Future<String?> uploadImage(File imageFile) async {
    try {
      if (!await imageFile.exists()) {
        print('❌ Image file does not exist: ${imageFile.path}');
        return null;
      }
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          resourceType: CloudinaryResourceType.Image,
          folder: 'strakataturistika',
        ),
      );
      return response.secureUrl;
    } catch (e) {
      print('❌ Error uploading image to Cloudinary: $e');
      return null;
    }
  }
  
  static Future<List<String>> uploadMultipleImages(List<File> imageFiles) async {
    List<String> uploadedUrls = [];
    
    for (int i = 0; i < imageFiles.length; i++) {
      print('📤 Uploading image ${i + 1}/${imageFiles.length}');
      String? url = await uploadImage(imageFiles[i]);
      if (url != null) {
        uploadedUrls.add(url);
      }
    }
    
    print('✅ Successfully uploaded ${uploadedUrls.length}/${imageFiles.length} images');
    return uploadedUrls;
  }
} 