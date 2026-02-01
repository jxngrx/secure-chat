import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../utils/logger.dart';
import '../services/contact_service.dart';

/// Service for reading device call logs
class CallLogService {
  CallLogService(this._contactService);

  final ContactService _contactService;

  /// Request call log permission
  Future<bool> requestCallLogPermission() async {
    try {
      final status = await ph.Permission.phone.request();
      return status.isGranted;
    } catch (e) {
      Logger.e('Error requesting call log permission', e);
      return false;
    }
  }

  /// Check if call log permission is granted
  Future<bool> isCallLogPermissionGranted() async {
    try {
      final status = await ph.Permission.phone.status;
      return status.isGranted;
    } catch (e) {
      return false;
    }
  }

  /// Read device call logs
  /// 
  /// Returns list of call logs formatted according to API spec:
  /// {
  ///   "phoneNumber": "+1234567890",
  ///   "callType": "outgoing" | "incoming" | "missed",
  ///   "duration": 120,
  ///   "timestamp": "2026-01-31T10:00:00.000Z",
  ///   "contactName": "John Doe"
  /// }
  Future<List<Map<String, dynamic>>> getCallLogs({
    int? limit,
    DateTime? since,
  }) async {
    try {
      final hasPermission = await isCallLogPermissionGranted();
      if (!hasPermission) {
        Logger.w('Call log permission not granted');
        return [];
      }

      final Iterable<CallLogEntry> entries = await CallLog.get();

      // Filter by date if provided
      Iterable<CallLogEntry> filteredEntries = entries;
      if (since != null) {
        filteredEntries = entries.where((entry) {
          final entryDate = DateTime.fromMillisecondsSinceEpoch(entry.timestamp ?? 0);
          return entryDate.isAfter(since);
        });
      }

      // Limit results if provided
      if (limit != null && limit > 0) {
        filteredEntries = filteredEntries.take(limit);
      }

      // Convert to API format
      final List<Map<String, dynamic>> callLogs = [];
      for (final entry in filteredEntries) {
        try {
          final phoneNumber = entry.number ?? '';
          if (phoneNumber.isEmpty) {
            continue;
          }

          // Get contact name if available
          String? contactName;
          try {
            contactName = await _contactService.getContactName(phoneNumber);
          } catch (e) {
            Logger.d('Could not get contact name for $phoneNumber: $e');
          }

          // Map call type
          String callType;
          switch (entry.callType) {
            case CallType.outgoing:
              callType = 'outgoing';
              break;
            case CallType.incoming:
              callType = 'incoming';
              break;
            case CallType.missed:
              callType = 'missed';
              break;
            default:
              callType = 'incoming'; // Default fallback
          }

          final timestamp = DateTime.fromMillisecondsSinceEpoch(
            entry.timestamp ?? DateTime.now().millisecondsSinceEpoch,
          );

          callLogs.add({
            'phoneNumber': phoneNumber,
            'callType': callType,
            'duration': entry.duration ?? 0,
            'timestamp': timestamp.toIso8601String(),
            if (contactName != null) 'contactName': contactName,
          });
        } catch (e) {
          Logger.e('Error processing call log entry', e);
          // Continue with next entry
        }
      }

      Logger.d('Retrieved ${callLogs.length} call logs');
      return callLogs;
    } catch (e) {
      Logger.e('Error reading call logs', e);
      return [];
    }
  }

  /// Get call logs since a specific date
  Future<List<Map<String, dynamic>>> getCallLogsSince(DateTime since) async {
    return getCallLogs(since: since);
  }
}
