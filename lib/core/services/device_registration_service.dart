import '../network/api_client.dart';
import '../services/device_info_service.dart';
import '../services/fcm_service.dart';
import '../utils/logger.dart';
import '../../features/device/domain/entities/device_entity.dart';

class DeviceRegistrationService {
  DeviceRegistrationService(this._apiClient, this._deviceInfoService);

  final ApiClient _apiClient;
  final DeviceInfoService _deviceInfoService;

  /// Register device with backend
  /// Should be called after successful authentication
  Future<bool> registerDevice() async {
    try {
      final deviceDetails = await _deviceInfoService.getDeviceDetails();

      final payload = <String, dynamic>{
        'deviceId': deviceDetails.deviceId,
        'deviceModel': deviceDetails.deviceModel,
        'manufacturer': deviceDetails.manufacturer,
        'osName': deviceDetails.osName,
        'osVersion': deviceDetails.osVersion,
        'appVersion': deviceDetails.appVersion,
        'platform': deviceDetails.platform,
      };

      if (deviceDetails.imei != null && deviceDetails.imei!.isNotEmpty) {
        payload['imei'] = deviceDetails.imei;
      }

      // Add FCM token if available
      final fcmToken = FCMService.instance.currentToken;
      if (fcmToken != null && fcmToken.isNotEmpty) {
        payload['fcmToken'] = fcmToken;
      }

      await _apiClient.post('/devices/register', payload);
      Logger.d('Device registered successfully: ${deviceDetails.deviceId}');
      return true;
    } catch (e) {
      Logger.e('Error registering device', e);
      return false;
    }
  }

  /// Check if device is already registered
  Future<bool> isDeviceRegistered() async {
    try {
      await _apiClient.get('/devices');
      return true;
    } catch (e) {
      Logger.e('Error checking device registration', e);
      return false;
    }
  }

  /// Get user devices
  Future<List<Map<String, dynamic>>> getUserDevices() async {
    try {
      final response = await _apiClient.get('/devices');
      final devices = response['data'] as List<dynamic>? ?? [];
      return devices.cast<Map<String, dynamic>>();
    } catch (e) {
      Logger.e('Error getting user devices', e);
      return [];
    }
  }
}
