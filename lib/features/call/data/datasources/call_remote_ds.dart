import '../../../../core/network/api_client.dart';
import '../../../../core/utils/logger.dart';

class CallRemoteDataSource {
  CallRemoteDataSource._();

  static final CallRemoteDataSource instance = CallRemoteDataSource._();

  final ApiClient _apiClient = ApiClient.instance;

  /// Initiate a new call
  Future<Map<String, dynamic>> initiateCall(String receiverId) async {
    try {
      final response = await _apiClient.post(
        '/calls',
        {'receiverId': receiverId},
      );
      return response['data'];
    } catch (e) {
      Logger.e('Error initiating call', e);
      rethrow;
    }
  }

  /// Answer a call
  Future<Map<String, dynamic>> answerCall(String callId) async {
    try {
      final response = await _apiClient.post(
        '/calls/$callId/answer',
        {},
      );
      return response['data'];
    } catch (e) {
      Logger.e('Error answering call', e);
      rethrow;
    }
  }

  /// Reject a call
  Future<void> rejectCall(String callId) async {
    try {
      await _apiClient.post(
        '/calls/$callId/reject',
         {},
      );
    } catch (e) {
      Logger.e('Error rejecting call', e);
      rethrow;
    }
  }

  /// End a call
  Future<void> endCall(String callId) async {
    try {
      await _apiClient.post(
        '/calls/$callId/end',
         {},
      );
    } catch (e) {
      Logger.e('Error ending call', e);
      rethrow;
    }
  }

  /// Get call history
  Future<List<Map<String, dynamic>>> getCallHistory({int limit = 20}) async {
    try {
      final response = await _apiClient.get(
        '/calls/history',
        queryParameters: {'limit': limit},
      );
      final List<dynamic> calls = response['data']['calls'];
      return calls.cast<Map<String, dynamic>>();
    } catch (e) {
      Logger.e('Error fetching call history', e);
      rethrow;
    }
  }
}
