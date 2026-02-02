import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
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
    } on CloudinaryException catch (e) {
      Logger.e('Cloudinary specific error: ${e.message}', e);
      if (e.message?.contains('preset') ?? false) {
        Logger.e('TIP: Check if your Cloudinary upload preset is set to "unsigned".');
      }
      return null;
    } on DioException catch (e) {
      Logger.e('Cloudinary Network Error: ${e.response?.statusCode}', e);
      if (e.response?.data != null) {
        Logger.e('Cloudinary Error Data: ${e.response?.data}');
      }
      return null;
    } catch (e) {
      Logger.e('General error uploading image to Cloudinary', e);
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
