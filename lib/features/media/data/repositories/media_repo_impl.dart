import '../../domain/repositories/media_repository.dart';
import '../../domain/entities/media_entity.dart';
import '../datasources/media_remote_ds.dart';

class MediaRepositoryImpl implements MediaRepository {
  MediaRepositoryImpl._();

  static final MediaRepositoryImpl instance = MediaRepositoryImpl._();

  final MediaRemoteDataSource _remoteDataSource = MediaRemoteDataSource.instance;

  @override
  Future<MediaEntity> uploadFile(String filePath) async {
    final response = await _remoteDataSource.uploadFile(filePath);
    return MediaEntity(
      url: response['url'] as String? ?? '',
      filename: response['filename'] as String? ?? '',
      size: response['size'] as int? ?? 0,
      mimetype: response['mimetype'] as String? ?? '',
    );
  }

  @override
  Future<void> deleteFile(String url) async {
    await _remoteDataSource.deleteFile(url);
  }
}
