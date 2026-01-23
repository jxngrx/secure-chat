import '../network/api_client.dart';
import '../services/device_info_service.dart';
import '../storage/secure_storage.dart';
import '../constants/storage_keys.dart';
import '../utils/logger.dart';
import '../../features/session/data/datasources/session_remote_ds.dart';
import '../../features/session/domain/entities/session_entity.dart';
import '../../features/session/data/models/session_model.dart';

class SessionService {
  SessionService(
    this._sessionDataSource,
    this._deviceInfoService,
    this._secureStorage,
  );

  final SessionRemoteDataSource _sessionDataSource;
  final DeviceInfoService _deviceInfoService;
  final SecureStorage _secureStorage;

  /// Create session if not created during auth
  Future<SessionEntity?> createSession({
    required String loginMethod,
    Map<String, dynamic>? location,
  }) async {
    try {
      final deviceDetails = await _deviceInfoService.getDeviceDetails();
      final response = await _sessionDataSource.createSession(
        deviceId: deviceDetails.deviceId,
        loginMethod: loginMethod,
        location: location,
      );

      final model = SessionModel.fromJson(response);

      // Store session ID if not already stored
      final existingSessionId = await _secureStorage.read(StorageKeys.sessionId);
      if (existingSessionId == null || existingSessionId.isEmpty) {
        await _secureStorage.write(StorageKeys.sessionId, model.sessionId);
      }

      Logger.d('Session created: ${model.sessionId}');
      return model.toEntity();
    } catch (e) {
      Logger.e('Error creating session', e);
      return null;
    }
  }

  /// Get all user sessions
  Future<List<SessionEntity>> getSessions() async {
    try {
      final response = await _sessionDataSource.getSessions();
      return response
          .map((json) => SessionModel.fromJson(json))
          .map((model) => model.toEntity())
          .toList();
    } catch (e) {
      Logger.e('Error getting sessions', e);
      return [];
    }
  }

  /// Deactivate session (logout)
  Future<bool> deactivateSession(String sessionId) async {
    try {
      await _sessionDataSource.deactivateSession(sessionId);

      // Clear stored session if it's the current one
      final currentSessionId = await _secureStorage.read(StorageKeys.sessionId);
      if (currentSessionId == sessionId) {
        await _secureStorage.delete(StorageKeys.sessionId);
      }

      Logger.d('Session deactivated: $sessionId');
      return true;
    } catch (e) {
      Logger.e('Error deactivating session', e);
      return false;
    }
  }

  /// Deactivate all sessions (logout all devices)
  Future<bool> deactivateAllSessions() async {
    try {
      await _sessionDataSource.deactivateAllSessions();
      await _secureStorage.delete(StorageKeys.sessionId);
      Logger.d('All sessions deactivated');
      return true;
    } catch (e) {
      Logger.e('Error deactivating all sessions', e);
      return false;
    }
  }
}
