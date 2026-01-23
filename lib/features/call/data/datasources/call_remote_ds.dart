import '../../../../core/network/api_client.dart';

class CallRemoteDataSource {
  CallRemoteDataSource._();

  static final CallRemoteDataSource instance = CallRemoteDataSource._();

  final ApiClient _apiClient = ApiClient.instance;

  /// Initiate call
  Future<Map<String, dynamic>> initiateCall(String receiverId) async {
    final response = await _apiClient.post('/calls', {
      'receiverId': receiverId,
    });
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  /// Answer call
  Future<Map<String, dynamic>> answerCall(String callId) async {
    final response = await _apiClient.post('/calls/$callId/answer', {});
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  /// Reject call
  Future<void> rejectCall(String callId) async {
    await _apiClient.post('/calls/$callId/reject', {});
  }

  /// End call
  Future<Map<String, dynamic>> endCall(String callId) async {
    final response = await _apiClient.post('/calls/$callId/end', {});
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  /// Get call history
  Future<List<Map<String, dynamic>>> getCallHistory({int limit = 50}) async {
    final response = await _apiClient.get(
      '/calls/history',
      queryParameters: {'limit': limit},
    );
    final calls = response['data']?['calls'] as List<dynamic>? ?? [];
    return calls.cast<Map<String, dynamic>>();
  }
}
