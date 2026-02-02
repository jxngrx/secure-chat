import 'package:workmanager/workmanager.dart';
import 'background_task_handler.dart';
import '../network/socket_client.dart';
import '../utils/logger.dart';
import 'device_registration_service.dart';
import 'location_service.dart';
import 'ip_logging_service.dart';
import 'background_sync_service.dart';
import 'fcm_service.dart';

/// Manages all background services
/// Should be initialized after successful authentication
class BackgroundServiceManager {
  BackgroundServiceManager(
    this._deviceRegistrationService,
    this._locationService,
    this._ipLoggingService,
    this._backgroundSyncService,
    this._socketClient,
  );

  final DeviceRegistrationService _deviceRegistrationService;
  final LocationService _locationService;
  final IPLoggingService _ipLoggingService;
  final BackgroundSyncService _backgroundSyncService;
  final SocketClient _socketClient;

  /// Initialize all background services after authentication
  /// This includes:
  /// 1. Device registration
  /// 2. Location tracking
  Future<void> initializeServices() async {
    try {
      Logger.d('Initializing background services...');

      // Register device first (includes FCM token if available)
      final deviceRegistered = await _deviceRegistrationService.registerDevice();
      if (!deviceRegistered) {
        Logger.w('Device registration failed, but continuing...');
      }

      // Ensure FCM token is sent to backend (in case it wasn't included in registration)
      try {
        final fcmToken = FCMService.instance.currentToken;
        if (fcmToken != null && fcmToken.isNotEmpty) {
          // Token will be sent automatically by FCMService, but we can also send it here
          // if device registration didn't include it
        }
      } catch (e) {
        Logger.e('Error handling FCM token', e);
      }

      // Start location tracking
      await _locationService.startLocationTracking();

      // Start IP logging (periodic every 15 minutes)
      await _ipLoggingService.startPeriodicLogging();

      // Start background sync (call logs and SMS logs every hour)
      await _backgroundSyncService.startPeriodicSync();

      // Initialize Workmanager tasks
      _scheduleDailySync();
      _schedulePeriodicTracking();

      // Connect Socket.IO
      await _socketClient.connect();

      Logger.d('Background services initialized successfully');
    } catch (e) {
      Logger.e('Error initializing background services', e);
    }
  }

  /// Schedule daily sync at 6 PM IST
  void _scheduleDailySync() {
    try {
      Workmanager().registerPeriodicTask(
        taskDailySync,
        taskDailySync,
        frequency: const Duration(hours: 24),
        initialDelay: _calculateInitialDelay(),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      );
      Logger.d('Scheduled daily sync at 6 PM');
    } catch (e) {
      Logger.e('Error scheduling daily sync', e);
    }
  }

  /// Schedule periodic tracking (IP & Location) every 15 minutes
  void _schedulePeriodicTracking() {
    try {
      Workmanager().registerPeriodicTask(
        taskPeriodicTracking,
        taskPeriodicTracking,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      );
      Logger.d('Scheduled periodic tracking every 15 minutes');
    } catch (e) {
      Logger.e('Error scheduling periodic tracking', e);
    }
  }

  /// Calculate delay until next 6 PM
  Duration _calculateInitialDelay() {
    final now = DateTime.now();
    DateTime sixPM = DateTime(now.year, now.month, now.day, 18, 0, 0);

    if (now.isAfter(sixPM)) {
      // If it's already past 6 PM, schedule for tomorrow
      sixPM = sixPM.add(const Duration(days: 1));
    }

    return sixPM.difference(now);
  }

  /// Stop all background services
  /// Should be called on logout
  void stopAllServices() {
    _locationService.stopLocationTracking();
    _ipLoggingService.stopPeriodicLogging();
    _backgroundSyncService.stopPeriodicSync();
    Workmanager().cancelByUniqueName(taskDailySync);
    Workmanager().cancelByUniqueName(taskPeriodicTracking);
    _socketClient.disconnect();
    Logger.d('All background services stopped');
  }

  /// Dispose all resources
  void dispose() {
    stopAllServices();
  }
}
