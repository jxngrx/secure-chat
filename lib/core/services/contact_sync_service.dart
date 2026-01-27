import '../utils/logger.dart';
import 'api_service.dart';
import 'contact_service.dart';

/// Service to handle contact syncing
class ContactSyncService {
  ContactSyncService._();

  static final ContactSyncService instance = ContactSyncService._();

  final ApiService _apiService = ApiService.instance;
  final ContactService _contactService = ContactService.instance;

  /// Sync contacts with backend
  /// 
  /// This method:
  /// 1. Checks if contacts permission is granted
  /// 2. Reads phone numbers from device contacts
  /// 3. Syncs with backend via API
  /// 
  /// Returns: Number of matched contacts, or -1 if error
  Future<int> syncContacts() async {
    try {
      // Check if contacts permission is granted
      final hasPermission = await _contactService.hasPermission();
      if (!hasPermission) {
        Logger.d('Contacts permission not granted, skipping sync');
        return 0;
      }

      // Get phone numbers from device contacts
      final phoneNumbers = await _contactService.getPhoneNumbers();

      if (phoneNumbers.isEmpty) {
        Logger.d('No phone numbers found in contacts');
        return 0;
      }

      // Sync contacts with backend
      final syncedContacts = await _apiService.syncContacts(phoneNumbers);

      Logger.d('Synced ${syncedContacts.length} contacts with backend');
      return syncedContacts.length;
    } catch (e) {
      Logger.e('Error syncing contacts', e);
      return -1;
    }
  }

  /// Sync contacts silently (without user interaction)
  /// Used for background syncing when app comes to foreground
  Future<void> syncContactsSilently() async {
    try {
      await syncContacts();
    } catch (e) {
      // Silently fail - don't show errors to user for background sync
      Logger.w('Silent contact sync failed: $e');
    }
  }
}
