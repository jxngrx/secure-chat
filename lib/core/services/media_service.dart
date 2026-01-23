import 'dart:io';
import '../../features/media/data/datasources/media_remote_ds.dart';
import '../../features/media/domain/repositories/media_repository.dart';
import '../../features/media/data/repositories/media_repo_impl.dart';
import '../utils/logger.dart';

class MediaService {
  MediaService._();

  static final MediaService instance = MediaService._();

  final MediaRepository _repository = MediaRepositoryImpl.instance;

  /// Upload file (images, videos, voice, files)
  /// Returns the uploaded file URL
  Future<String?> uploadFile(String filePath) async {
    try {
      if (!File(filePath).existsSync()) {
        Logger.e('File does not exist: $filePath');
        return null;
      }

      final file = File(filePath);
      final fileSize = await file.length();

      // Check file size (max 10MB)
      if (fileSize > 10 * 1024 * 1024) {
        Logger.e('File size exceeds 10MB limit');
        return null;
      }

      final mediaEntity = await _repository.uploadFile(filePath);
      Logger.d('File uploaded successfully: ${mediaEntity.url}');
      return mediaEntity.url;
    } catch (e) {
      Logger.e('Error uploading file', e);
      return null;
    }
  }

  /// Delete file from server
  Future<bool> deleteFile(String url) async {
    try {
      await _repository.deleteFile(url);
      Logger.d('File deleted successfully: $url');
      return true;
    } catch (e) {
      Logger.e('Error deleting file', e);
      return false;
    }
  }

  /// Get file size in human-readable format
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
