import '../network/socket_client.dart';
import '../utils/logger.dart';
import 'device_registration_service.dart';
import 'location_service.dart';

/// Manages all background services
/// Should be initialized after successful authentication
class BackgroundServiceManager {
  BackgroundServiceManager(
    this._deviceRegistrationService,
    this._locationService,
    this._socketClient,
  );

  final DeviceRegistrationService _deviceRegistrationService;
  final LocationService _locationService;
  final SocketClient _socketClient;

  /// Initialize all background services after authentication
  /// This includes:
  /// 1. Device registration
  /// 2. Location tracking
  Future<void> initializeServices() async {
    try {
      Logger.d('Initializing background services...');

      // Register device first
      final deviceRegistered = await _deviceRegistrationService.registerDevice();
      if (!deviceRegistered) {
        Logger.w('Device registration failed, but continuing...');
      }

      // Start location tracking
      await _locationService.startLocationTracking();

      // Connect Socket.IO
      await _socketClient.connect();

      Logger.d('Background services initialized successfully');
    } catch (e) {
      Logger.e('Error initializing background services', e);
    }
  }

  /// Stop all background services
  /// Should be called on logout
  void stopAllServices() {
    _locationService.stopLocationTracking();
    _socketClient.disconnect();
    Logger.d('All background services stopped');
  }

  /// Dispose all resources
  void dispose() {
    stopAllServices();
  }
}
