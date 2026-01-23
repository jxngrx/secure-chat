import '../entities/media_entity.dart';

abstract class MediaRepository {
  Future<MediaEntity> uploadFile(String filePath);
  Future<void> deleteFile(String url);
}
