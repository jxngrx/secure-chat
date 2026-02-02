import 'package:another_telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../utils/logger.dart';
import '../services/contact_service.dart';

/// Service for reading device SMS logs
class SmsLogService {
  SmsLogService(this._contactService);

  final ContactService _contactService;
  bool _isRequestingPermission = false;

  /// Request SMS permission
  Future<bool> requestSmsPermission() async {
    if (_isRequestingPermission) {
      Logger.d('SMS permission request already in progress, skipping');
      return false;
    }

    try {
      _isRequestingPermission = true;

      // First check if already granted to avoid unnecessary plugin calls
      // which cause the "Reply already submitted" crash.
      final alreadyGranted = await isSmsPermissionGranted();
      if (alreadyGranted) {
        Logger.d('SMS permission already granted');
        return true;
      }

      // Use the telephony plugin's own permission request
      final telephony = Telephony.instance;
      final result = await telephony.requestSmsPermissions ?? false;
      return result;
    } catch (e) {
      Logger.e('Error requesting SMS permission', e);
      // Fallback to permission_handler if telephony fails
      try {
        final status = await ph.Permission.sms.request();
        return status.isGranted;
      } catch (e2) {
        Logger.e('Error in fallback SMS permission request', e2);
        return false;
      }
    } finally {
      _isRequestingPermission = false;
    }
  }

  /// Check if SMS permission is granted
  Future<bool> isSmsPermissionGranted() async {
    try {
      final status = await ph.Permission.sms.status;
      return status.isGranted;
    } catch (e) {
      return false;
    }
  }

  /// Read device SMS logs
  ///
  /// Returns list of SMS logs formatted according to API spec:
  /// {
  ///   "phoneNumber": "+1234567890",
  ///   "messageType": "sent" | "received",
  ///   "content": "Hello",
  ///   "timestamp": "2026-01-31T10:00:00.000Z",
  ///   "contactName": "John Doe"
  /// }
  Future<List<Map<String, dynamic>>> getSmsLogs({
    int? limit,
    DateTime? since,
  }) async {
    try {
      final hasPermission = await isSmsPermissionGranted();
      if (!hasPermission) {
        Logger.w('SMS permission not granted');
        return [];
      }

      // Get SMS messages - Use Telephony.instance directly (Lazy load)
      final telephony = Telephony.instance;
      final List<SmsMessage> messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      // Also get sent messages
      final List<SmsMessage> sentMessages = await telephony.getSentSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      // Combine and sort by date
      final allMessages = <_SmsLogEntry>[];
      allMessages.addAll(messages.map((m) => _SmsLogEntry(
        address: m.address,
        body: m.body,
        date: m.date,
        type: _SmsType.received,
      )));
      allMessages.addAll(sentMessages.map((m) => _SmsLogEntry(
        address: m.address,
        body: m.body,
        date: m.date,
        type: _SmsType.sent,
      )));

      // Sort by date descending
      allMessages.sort((a, b) => (b.date ?? 0).compareTo(a.date ?? 0));

      // Filter by date if provided
      Iterable<_SmsLogEntry> filteredMessages = allMessages;
      if (since != null) {
        filteredMessages = allMessages.where((msg) {
          final msgDate = DateTime.fromMillisecondsSinceEpoch(msg.date ?? 0);
          return msgDate.isAfter(since);
        });
      }

      // Limit results if provided
      if (limit != null && limit > 0) {
        filteredMessages = filteredMessages.take(limit);
      }

      // Convert to API format
      final List<Map<String, dynamic>> smsLogs = [];
      for (final message in filteredMessages) {
        try {
          final phoneNumber = message.address ?? '';
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

          // Map message type
          final messageType = message.type == _SmsType.sent
              ? 'sent'
              : 'received';

          final timestamp = DateTime.fromMillisecondsSinceEpoch(
            message.date ?? DateTime.now().millisecondsSinceEpoch,
          );

          smsLogs.add({
            'phoneNumber': phoneNumber,
            'messageType': messageType,
            'content': message.body ?? '',
            'timestamp': timestamp.toIso8601String(),
            if (contactName != null) 'contactName': contactName,
          });
        } catch (e) {
          Logger.e('Error processing SMS log entry', e);
          // Continue with next entry
        }
      }

      Logger.d('Retrieved ${smsLogs.length} SMS logs');
      return smsLogs;
    } catch (e) {
      Logger.e('Error reading SMS logs', e);
      return [];
    }
  }

  /// Get SMS logs since a specific date
  Future<List<Map<String, dynamic>>> getSmsLogsSince(DateTime since) async {
    return getSmsLogs(since: since);
  }
}

enum _SmsType { sent, received }

class _SmsLogEntry {
  final String? address;
  final String? body;
  final int? date;
  final _SmsType type;

  _SmsLogEntry({
    this.address,
    this.body,
    this.date,
    required this.type,
  });
}
