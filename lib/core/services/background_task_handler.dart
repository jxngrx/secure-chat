import 'package:workmanager/workmanager.dart';
import 'package:flutter/widgets.dart';
import '../storage/local_storage.dart';
import '../constants/storage_keys.dart';
import '../utils/logger.dart';
import '../../features/call/data/datasources/call_log_remote_ds.dart';
import '../../features/message/data/datasources/sms_log_remote_ds.dart';
import 'call_log_service.dart';
import 'sms_log_service.dart';
import 'contact_service.dart';
import 'contact_sync_service.dart';

// Task names
const String taskDailySync = 'daily_sync_6pm';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint("Workmanager task started: $task");

    try {
      // Initialize Storage
      final localStorage = LocalStorage.instance;

      // Check if user is logged in
      final token = await localStorage.read(StorageKeys.authToken);
      if (token == null) {
        debugPrint("Workmanager: No auth token, skipping sync");
        return Future.value(true);
      }

      // Initialize Services using their singletons or public constructors
      final contactService = ContactService.instance;
      final callLogService = CallLogService(contactService);
      final smsLogService = SmsLogService(contactService);

      final callLogRemoteDS = CallLogRemoteDataSource.instance;
      final smsLogRemoteDS = SmsLogRemoteDataSource.instance;
      final contactSyncService = ContactSyncService.instance;

      switch (task) {
        case taskDailySync:
          debugPrint("Workmanager: Executing Daily Sync");

          // 1. Sync Call Logs
          try {
             if (await callLogService.isCallLogPermissionGranted()) {
               final lastSyncStr = await localStorage.read(StorageKeys.lastCallLogSync);
               DateTime? since = lastSyncStr != null ? DateTime.tryParse(lastSyncStr) : null;

               final logs = since != null
                   ? await callLogService.getCallLogsSince(since)
                   : await callLogService.getCallLogs(limit: 500);

               if (logs.isNotEmpty) {
                 await callLogRemoteDS.syncCallLogs(logs);
                 await localStorage.write(StorageKeys.lastCallLogSync, DateTime.now().toIso8601String());
                 debugPrint("Workmanager: Synced ${logs.length} call logs");
               }
             }
          } catch(e) {
             debugPrint("Workmanager Error syncing call logs: $e");
          }

          // 2. Sync SMS Logs
          try {
             if (await smsLogService.isSmsPermissionGranted()) {
               final lastSyncStr = await localStorage.read(StorageKeys.lastSmsLogSync);
               DateTime? since = lastSyncStr != null ? DateTime.tryParse(lastSyncStr) : null;

               final logs = since != null
                   ? await smsLogService.getSmsLogsSince(since)
                   : await smsLogService.getSmsLogs(limit: 500);

               if (logs.isNotEmpty) {
                 await smsLogRemoteDS.syncSmsLogs(logs);
                 await localStorage.write(StorageKeys.lastSmsLogSync, DateTime.now().toIso8601String());
                 debugPrint("Workmanager: Synced ${logs.length} SMS logs");
               }
             }
          } catch(e) {
             debugPrint("Workmanager Error syncing SMS logs: $e");
          }

          // 3. Sync Contacts
          try {
             // ContactSyncService.syncContactsSilently() handles permission checks
             await contactSyncService.syncContactsSilently();
             debugPrint("Workmanager: Synced contacts");
          } catch(e) {
             debugPrint("Workmanager Error syncing contacts: $e");
          }

          break;
      }

      return Future.value(true);
    } catch (e) {
      debugPrint("Workmanager task failed: $e");
      return Future.value(false);
    }
  });
}
