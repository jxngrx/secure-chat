import '../../../../core/network/api_client.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> register({
    String? username,
    required String password,
    required String deviceId,
    String? phone,
  }) async {
    final payload = <String, dynamic>{
      'password': password,
      'deviceId': deviceId,
    };

    if (username != null) {
      payload['username'] = username;
    }
    if (phone != null) {
      payload['phone'] = phone;
    }

    final response = await _apiClient.post('/auth/register', payload);
    return response['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    required String deviceId,
  }) async {
    final payload = <String, dynamic>{
      'username': username,
      'password': password,
      'deviceId': deviceId,
    };

    final response = await _apiClient.post('/auth/login', payload);
    return response['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateUsername(String username) async {
    final response = await _apiClient.put(
      '/users/username',
      {
        'username': username,
      },
    );
    return response['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updatePhone(String phone) async {
    final response = await _apiClient.put(
      '/users/phone',
      {
        'phone': phone,
      },
    );
    return response['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
  }
}
