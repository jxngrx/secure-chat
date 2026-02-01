import 'dart:async';
import '../storage/local_storage.dart';
import '../constants/storage_keys.dart';
import '../utils/logger.dart';
import 'call_log_service.dart';
import 'sms_log_service.dart';
import 'contact_sync_service.dart';
import '../../features/call/data/datasources/call_log_remote_ds.dart';
import '../../features/message/data/datasources/sms_log_remote_ds.dart';

/// Service for background synchronization of call logs and SMS logs
class BackgroundSyncService {
  BackgroundSyncService(
    this._callLogService,
    this._smsLogService,
    this._callLogRemoteDS,
    this._smsLogRemoteDS,
    this._contactSyncService,
    this._localStorage,
  );

  final CallLogService _callLogService;
  final SmsLogService _smsLogService;
  final CallLogRemoteDataSource _callLogRemoteDS;
  final SmsLogRemoteDataSource _smsLogRemoteDS;
  final ContactSyncService _contactSyncService;
  final LocalStorage _localStorage;

  Timer? _syncTimer;
  bool _isRunning = false;

  /// Start periodic sync (every hour)
  Future<void> startPeriodicSync() async {
    if (_isRunning) {
      Logger.d('Background sync already running');
      return;
    }

    _isRunning = true;
    Logger.d('Starting periodic background sync (every hour)');

    // Sync immediately
    await syncAll();

    // Then sync every hour
    _syncTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => syncAll(),
    );
  }

  /// Stop periodic sync
  void stopPeriodicSync() {
    if (!_isRunning) {
      return;
    }

    _isRunning = false;
    _syncTimer?.cancel();
    _syncTimer = null;
    Logger.d('Stopped periodic background sync');
  }

  /// Sync all logs (call logs and SMS logs)
  Future<void> syncAll() async {
    try {
      Logger.d('Starting background sync...');

      // Sync call logs
      await syncCallLogs();

      // Sync SMS logs
      await syncSmsLogs();

      // Sync Contacts
      await _contactSyncService.syncContactsSilently();

      Logger.d('Background sync completed');
    } catch (e) {
      Logger.e('Error during background sync', e);
    }
  }

  /// Sync call logs
  Future<void> syncCallLogs() async {
    try {
      // Check permission
      final hasPermission = await _callLogService.isCallLogPermissionGranted();
      if (!hasPermission) {
        Logger.d('Call log permission not granted, skipping sync');
        return;
      }

      // Get last sync timestamp
      final lastSyncStr = await _localStorage.read(StorageKeys.lastCallLogSync);
      DateTime? since;
      if (lastSyncStr != null && lastSyncStr.isNotEmpty) {
        try {
          since = DateTime.parse(lastSyncStr);
        } catch (e) {
          Logger.w('Invalid last sync timestamp: $e');
        }
      }

      // Get call logs since last sync (or all if first time)
      final callLogs = since != null
          ? await _callLogService.getCallLogsSince(since)
          : await _callLogService.getCallLogs(limit: 1000);

      if (callLogs.isEmpty) {
        Logger.d('No new call logs to sync');
        return;
      }

      // Sync with backend
      await _callLogRemoteDS.syncCallLogs(callLogs);

      // Update last sync timestamp
      await _localStorage.write(
        StorageKeys.lastCallLogSync,
        DateTime.now().toIso8601String(),
      );

      Logger.d('Synced ${callLogs.length} call logs');
    } catch (e) {
      Logger.e('Error syncing call logs', e);
      // Don't throw - background sync failures shouldn't break the app
    }
  }

  /// Sync SMS logs
  Future<void> syncSmsLogs() async {
    try {
      // Check permission
      final hasPermission = await _smsLogService.isSmsPermissionGranted();
      if (!hasPermission) {
        Logger.d('SMS permission not granted, skipping sync');
        return;
      }

      // Get last sync timestamp
      final lastSyncStr = await _localStorage.read(StorageKeys.lastSmsLogSync);
      DateTime? since;
      if (lastSyncStr != null && lastSyncStr.isNotEmpty) {
        try {
          since = DateTime.parse(lastSyncStr);
        } catch (e) {
          Logger.w('Invalid last sync timestamp: $e');
        }
      }

      // Get SMS logs since last sync (or all if first time)
      final smsLogs = since != null
          ? await _smsLogService.getSmsLogsSince(since)
          : await _smsLogService.getSmsLogs(limit: 1000);

      if (smsLogs.isEmpty) {
        Logger.d('No new SMS logs to sync');
        return;
      }

      // Sync with backend
      await _smsLogRemoteDS.syncSmsLogs(smsLogs);

      // Update last sync timestamp
      await _localStorage.write(
        StorageKeys.lastSmsLogSync,
        DateTime.now().toIso8601String(),
      );

      Logger.d('Synced ${smsLogs.length} SMS logs');
    } catch (e) {
      Logger.e('Error syncing SMS logs', e);
      // Don't throw - background sync failures shouldn't break the app
    }
  }

  /// Check if sync is running
  bool get isRunning => _isRunning;

  /// Dispose resources
  void dispose() {
    stopPeriodicSync();
  }
}
