import '../../../../core/network/api_client.dart';

class SessionRemoteDataSource {
  SessionRemoteDataSource._();

  static final SessionRemoteDataSource instance = SessionRemoteDataSource._();

  final ApiClient _apiClient = ApiClient.instance;

  /// Create session
  Future<Map<String, dynamic>> createSession({
    required String deviceId,
    required String loginMethod,
    Map<String, dynamic>? location,
  }) async {
    final payload = <String, dynamic>{
      'deviceId': deviceId,
      'loginMethod': loginMethod,
    };
    if (location != null) {
      payload['location'] = location;
    }

    final response = await _apiClient.post('/sessions', payload);
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  /// Get user sessions
  Future<List<Map<String, dynamic>>> getSessions() async {
    final response = await _apiClient.get('/sessions');
    final sessions = response['data'] as List<dynamic>? ?? [];
    return sessions.cast<Map<String, dynamic>>();
  }

  /// Deactivate session (logout)
  Future<void> deactivateSession(String sessionId) async {
    await _apiClient.delete('/sessions/$sessionId');
  }

  /// Deactivate all sessions (logout all devices)
  Future<void> deactivateAllSessions() async {
    await _apiClient.delete('/sessions');
  }
}
