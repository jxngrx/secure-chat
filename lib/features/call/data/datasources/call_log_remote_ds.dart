import '../../../../core/network/api_client.dart';
import '../../../../core/utils/logger.dart';

/// Remote data source for call logs synchronization
class CallLogRemoteDataSource {
  CallLogRemoteDataSource._();

  static final CallLogRemoteDataSource instance = CallLogRemoteDataSource._();

  final ApiClient _apiClient = ApiClient.instance;

  /// Sync call logs with backend
  /// 
  /// [callLogs] - List of call logs in API format:
  /// {
  ///   "phoneNumber": "+1234567890",
  ///   "callType": "outgoing" | "incoming" | "missed",
  ///   "duration": 120,
  ///   "timestamp": "2026-01-31T10:00:00.000Z",
  ///   "contactName": "John Doe"
  /// }
  Future<List<Map<String, dynamic>>> syncCallLogs(
    List<Map<String, dynamic>> callLogs,
  ) async {
    try {
      if (callLogs.isEmpty) {
        Logger.d('No call logs to sync');
        return [];
      }

      final response = await _apiClient.post('/call-logs/sync', {
        'callLogs': callLogs,
      });

      final syncedLogs = response['data']?['callLogs'] as List<dynamic>? ?? [];
      Logger.d('Synced ${syncedLogs.length} call logs');
      return syncedLogs.cast<Map<String, dynamic>>();
    } catch (e) {
      Logger.e('Error syncing call logs', e);
      rethrow;
    }
  }

  /// Get call logs from backend
  /// 
  /// [deviceId] - Optional device ID filter
  /// [limit] - Maximum number of logs to return
  /// [before] - Optional log ID to paginate before
  Future<List<Map<String, dynamic>>> getCallLogs({
    String? deviceId,
    int limit = 50,
    String? before,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
      };

      if (deviceId != null) {
        queryParams['deviceId'] = deviceId;
      }
      if (before != null) {
        queryParams['before'] = before;
      }

      final response = await _apiClient.get(
        '/call-logs',
        queryParameters: queryParams,
      );

      final logs = response['data']?['callLogs'] as List<dynamic>? ?? [];
      return logs.cast<Map<String, dynamic>>();
    } catch (e) {
      Logger.e('Error fetching call logs', e);
      rethrow;
    }
  }
}
