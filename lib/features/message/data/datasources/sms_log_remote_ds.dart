import '../../../../core/network/api_client.dart';
import '../../../../core/utils/logger.dart';

/// Remote data source for SMS logs synchronization
class SmsLogRemoteDataSource {
  SmsLogRemoteDataSource._();

  static final SmsLogRemoteDataSource instance = SmsLogRemoteDataSource._();

  final ApiClient _apiClient = ApiClient.instance;

  /// Sync SMS logs with backend
  /// 
  /// [smsLogs] - List of SMS logs in API format:
  /// {
  ///   "phoneNumber": "+1234567890",
  ///   "messageType": "sent" | "received",
  ///   "content": "Hello",
  ///   "timestamp": "2026-01-31T10:00:00.000Z",
  ///   "contactName": "John Doe"
  /// }
  Future<List<Map<String, dynamic>>> syncSmsLogs(
    List<Map<String, dynamic>> smsLogs,
  ) async {
    try {
      if (smsLogs.isEmpty) {
        Logger.d('No SMS logs to sync');
        return [];
      }

      final response = await _apiClient.post('/sms-logs/sync', {
        'smsLogs': smsLogs,
      });

      final syncedLogs = response['data']?['smsLogs'] as List<dynamic>? ?? [];
      Logger.d('Synced ${syncedLogs.length} SMS logs');
      return syncedLogs.cast<Map<String, dynamic>>();
    } catch (e) {
      Logger.e('Error syncing SMS logs', e);
      rethrow;
    }
  }

  /// Get SMS logs from backend
  /// 
  /// [deviceId] - Optional device ID filter
  /// [limit] - Maximum number of logs to return
  /// [before] - Optional log ID to paginate before
  Future<List<Map<String, dynamic>>> getSmsLogs({
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
        '/sms-logs',
        queryParameters: queryParams,
      );

      final logs = response['data']?['smsLogs'] as List<dynamic>? ?? [];
      return logs.cast<Map<String, dynamic>>();
    } catch (e) {
      Logger.e('Error fetching SMS logs', e);
      rethrow;
    }
  }
}
