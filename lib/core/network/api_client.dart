import 'dart:async';

import 'package:dio/dio.dart';

import '../config/env.dart';
import '../constants/storage_keys.dart';
import '../storage/secure_storage.dart';
import '../utils/logger.dart';

typedef JsonMap = Map<String, dynamic>;

class ApiClient {
  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: Env.baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    )..interceptors.add(_buildInterceptor());
  }

  static final ApiClient instance = ApiClient._();

  late final Dio _dio;
  final SecureStorage _secureStorage = SecureStorage.instance;

  InterceptorsWrapper _buildInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _secureStorage.read(StorageKeys.authToken);
        final sessionId = await _secureStorage.read(StorageKeys.sessionId);
        final deviceId = await _secureStorage.read(StorageKeys.deviceId);

        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        if (sessionId != null) {
          options.headers['X-Session-Id'] = sessionId;
        }
        if (deviceId != null) {
          options.headers['X-Device-Id'] = deviceId;
        }

        Logger.d('[API] => ${options.method} ${options.uri}');
        Logger.d('[API] Headers: ${options.headers}'); // Debug 403 error
        if (options.data != null) {
          Logger.d('[API] Payload: ${options.data}');
        }

        handler.next(options);
      },
      onResponse: (response, handler) {
        Logger.d('[API] <= ${response.statusCode} ${response.requestOptions.uri}');
        handler.next(response);
      },
      onError: (error, handler) async {
        Logger.e('[API] Error ${error.response?.statusCode} => ${error.message}');
        if (error.response?.statusCode == 401) {
          await _secureStorage.delete(StorageKeys.authToken);
          await _secureStorage.delete(StorageKeys.sessionId);
        }
        handler.next(error);
      },
    );
  }

  Future<JsonMap> get(
    String endpoint, {
    JsonMap? queryParameters,
    CancelToken? cancelToken,
  }) async {
    return _handleRequest(
      () => _dio.get<JsonMap>(
        endpoint,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<JsonMap> post(
    String endpoint,
    JsonMap data, {
    JsonMap? queryParameters,
    CancelToken? cancelToken,
  }) async {
    return _handleRequest(
      () => _dio.post<JsonMap>(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<JsonMap> put(
    String endpoint,
    JsonMap data, {
    JsonMap? queryParameters,
    CancelToken? cancelToken,
  }) async {
    return _handleRequest(
      () => _dio.put<JsonMap>(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<JsonMap> patch(
    String endpoint,
    JsonMap data, {
    JsonMap? queryParameters,
    CancelToken? cancelToken,
  }) async {
    return _handleRequest(
      () => _dio.patch<JsonMap>(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<JsonMap> delete(
    String endpoint, {
    JsonMap? data,
    JsonMap? queryParameters,
    CancelToken? cancelToken,
  }) async {
    return _handleRequest(
      () => _dio.delete<JsonMap>(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<JsonMap> _handleRequest(
    Future<Response<JsonMap>> Function() requestFn,
  ) async {
    try {
      final response = await requestFn();
      final data = response.data ?? {};
      if (data['success'] == false) {
        throw ApiException(
          message: data['error']?.toString() ?? 'Unknown error',
          statusCode: response.statusCode ?? -1,
        );
      }
      return data;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode ?? -1;
      final payload = error.response?.data;
      final message = payload is Map<String, dynamic>
          ? payload['error']?.toString() ?? payload['message']?.toString()
          : error.message;

      throw ApiException(
        message: message ?? 'Something went wrong',
        statusCode: statusCode,
      );
    } catch (error, stackTrace) {
      Logger.e('Unhandled API error', error, stackTrace);
      throw ApiException(
        message: 'Unexpected error occurred',
        statusCode: -1,
      );
    }
  }
}

class ApiException implements Exception {
  ApiException({required this.message, required this.statusCode});

  final String message;
  final int statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
