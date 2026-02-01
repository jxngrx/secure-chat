import 'dart:async';
import '../network/api_client.dart';
import '../storage/secure_storage.dart';
import '../constants/storage_keys.dart';
import '../utils/logger.dart';

/// Service for logging IP addresses to backend
///
/// Automatically logs IP on periodic intervals (every 15 minutes)
/// and can be manually triggered for specific actions
class IPLoggingService {
  IPLoggingService(this._apiClient, this._secureStorage);

  final ApiClient _apiClient;
  final SecureStorage _secureStorage;
  Timer? _periodicTimer;
  bool _isRunning = false;

  /// Start periodic IP logging (every 15 minutes)
  Future<void> startPeriodicLogging() async {
    if (_isRunning) {
      Logger.d('Periodic IP logging already started');
      return;
    }

    _isRunning = true;
    Logger.d('Starting periodic IP logging (every 15 minutes)');

    // Log immediately
    await logIP(action: 'periodic');

    // Then log every 5 minutes
    _periodicTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => logIP(action: 'periodic'),
    );
  }

  /// Stop periodic IP logging
  void stopPeriodicLogging() {
    if (!_isRunning) {
      return;
    }

    _isRunning = false;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    Logger.d('Stopped periodic IP logging');
  }

  /// Log IP address to backend
  ///
  /// [action] - Action type: 'login', 'message', 'call', 'background', 'periodic', 'location'
  /// [metadata] - Additional metadata to include in the log
  Future<void> logIP({
    String? action,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final token = await _secureStorage.read(StorageKeys.authToken);
      if (token == null || token.isEmpty) {
        Logger.w('No auth token, skipping IP log');
        return;
      }

      final payload = <String, dynamic>{};

      if (metadata != null) {
        payload['metadata'] = metadata;
      } else if (action != null) {
        payload['metadata'] = {
          'action': action,
        };
      }

      await _apiClient.post('/tracking/ip-log', payload);
      Logger.d('IP logged successfully (action: $action)');
    } catch (e) {
      Logger.e('Error logging IP', e);
      // Don't throw - IP logging failures shouldn't break the app
    }
  }

  /// Log IP when location changes
  ///
  /// This is a convenience method that logs IP with location-specific metadata
  Future<void> logIPOnLocationChange({
    double? latitude,
    double? longitude,
    double? accuracy,
  }) async {
    final metadata = <String, dynamic>{
      'action': 'location',
      'endpoint': '/location/update-simple',
      'method': 'POST',
    };

    if (latitude != null && longitude != null) {
      metadata['location'] = {
        'latitude': latitude,
        'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
      };
    }

    await logIP(action: 'location', metadata: metadata);
  }

  /// Check if periodic logging is running
  bool get isRunning => _isRunning;

  /// Dispose resources
  void dispose() {
    stopPeriodicLogging();
  }
}
