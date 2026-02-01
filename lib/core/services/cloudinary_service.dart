import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_strings.dart';
import '../utils/logger.dart';

/// Service for handling image uploads to Cloudinary
class CloudinaryService {
  late final CloudinaryPublic _cloudinary;

  CloudinaryService() {
    _cloudinary = CloudinaryPublic(
      AppStrings.cloudinaryCloudName,
      AppStrings.cloudinaryUploadPreset,
      cache: false,
    );
  }

  /// Upload an image file to Cloudinary
  /// Returns the secure URL of the uploaded image
  Future<String?> uploadImage(File imageFile) async {
    try {
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      Logger.d('Image uploaded successfully: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e) {
      Logger.e('Error uploading image to Cloudinary', e);
      return null;
    }
  }

  /// Pick an image from Gallery or Camera
  Future<File?> pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 80, // Compress slightly
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      Logger.e('Error picking image', e);
      return null;
    }
  }
}
