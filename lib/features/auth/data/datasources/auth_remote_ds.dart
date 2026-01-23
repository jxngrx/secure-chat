import '../../../../core/network/api_client.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<void> requestOtp(String phoneNumber) async {
    await _apiClient.post('/auth/request-otp', {
      'phone': phoneNumber,
    });
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phoneNumber,
    required String otp,
    String? deviceId,
    Map<String, dynamic>? location,
  }) async {
    final payload = <String, dynamic>{
      'phone': phoneNumber,
      'otp': otp,
    };

    if (deviceId != null) {
      payload['deviceId'] = deviceId;
    }
    if (location != null) {
      payload['location'] = location;
    }

    final response = await _apiClient.post('/auth/verify-otp', payload);
    return response['data'] as Map<String, dynamic>?
        ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateUsername(String username) async {
    final response = await _apiClient.put(
      '/users/username',
      {
        'username': username,
      },
    );
    return response['data'] as Map<String, dynamic>?
        ?? <String, dynamic>{};
  }

  /// Google OAuth authentication
  Future<Map<String, dynamic>> googleAuth({
    required String idToken,
    required String phone,
    String? deviceId,
    Map<String, dynamic>? location,
  }) async {
    final payload = <String, dynamic>{
      'idToken': idToken,
      'phone': phone,
    };

    if (deviceId != null) {
      payload['deviceId'] = deviceId;
    }
    if (location != null) {
      payload['location'] = location;
    }

    final response = await _apiClient.post('/auth/google', payload);
    return response['data'] as Map<String, dynamic>?
        ?? <String, dynamic>{};
  }
}
