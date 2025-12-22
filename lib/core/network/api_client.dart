import '../config/env.dart';

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  String get baseUrl => Env.baseUrl;

  // TODO: Implement HTTP client (Dio/HTTP)
  Future<Map<String, dynamic>> get(String endpoint) async {
    // Placeholder implementation
    throw UnimplementedError('ApiClient.get not implemented');
  }

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    // Placeholder implementation
    throw UnimplementedError('ApiClient.post not implemented');
  }

  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    // Placeholder implementation
    throw UnimplementedError('ApiClient.put not implemented');
  }

  Future<void> delete(String endpoint) async {
    // Placeholder implementation
    throw UnimplementedError('ApiClient.delete not implemented');
  }
}
