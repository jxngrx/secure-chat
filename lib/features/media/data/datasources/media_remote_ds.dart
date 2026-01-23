import 'package:dio/dio.dart';
import '../../../../core/config/env.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/constants/storage_keys.dart';

class MediaRemoteDataSource {
  MediaRemoteDataSource._();

  static final MediaRemoteDataSource instance = MediaRemoteDataSource._();

  final SecureStorage _secureStorage = SecureStorage.instance;
  Dio? _dio;

  Dio _getDio() {
    if (_dio != null) return _dio!;

    _dio = Dio(
      BaseOptions(
        baseUrl: Env.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.read(StorageKeys.authToken);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );

    return _dio;
  }

  /// Upload file (multipart/form-data, max 10MB)
  Future<Map<String, dynamic>> uploadFile(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });

    final response = await _getDio().post(
      '/media/upload',
      data: formData,
      options: Options(
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      ),
    );

    final data = response.data as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>? ?? {};
  }

  /// Delete file
  Future<void> deleteFile(String url) async {
    await _getDio().delete(
      '/media',
      data: {'url': url},
      options: Options(
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );
  }
}
