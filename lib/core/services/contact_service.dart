import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart';

/// Service to read contacts from device
class ContactService {
  ContactService._();

  static final ContactService instance = ContactService._();

  /// Request contacts permission
  Future<bool> requestPermission() async {
    try {
      return await FlutterContacts.requestPermission();
    } catch (e) {
      Logger.e('Error requesting contacts permission', e);
      return false;
    }
  }

  /// Check if contacts permission is granted
  Future<bool> hasPermission() async {
    try {
      final status = await Permission.contacts.status;
      return status.isGranted;
    } catch (e) {
      Logger.e('Error checking contacts permission', e);
      return false;
    }
  }

  /// Get all phone numbers from device contacts
  /// 
  /// Returns: List of phone numbers in E.164 format (with country code)
  /// Filters out invalid phone numbers
  Future<List<String>> getPhoneNumbers() async {
    try {
      final hasPermission = await this.hasPermission();
      if (!hasPermission) {
        Logger.w('Contacts permission not granted');
        return [];
      }

      // Get contacts with phone numbers only
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      final phoneNumbers = <String>[];
      final seenPhones = <String>{};

      for (final contact in contacts) {
        // Get all phone numbers for this contact
        for (final phone in contact.phones) {
          // Clean phone number: remove spaces, dashes, parentheses
          var cleaned = phone.number.replaceAll(RegExp(r'[\s\-\(\)]'), '');
          
          // Remove leading + if present (we'll add it back)
          if (cleaned.startsWith('+')) {
            cleaned = cleaned.substring(1);
          }

          // Skip if empty or too short
          if (cleaned.isEmpty || cleaned.length < 7) {
            continue;
          }

          // Format as E.164 (assume India +91 if no country code)
          String formattedPhone;
          if (cleaned.length == 10) {
            // 10 digits - assume India (+91)
            formattedPhone = '+91$cleaned';
          } else if (cleaned.length > 10 && cleaned.startsWith('91')) {
            // Already has country code
            formattedPhone = '+$cleaned';
          } else if (cleaned.length > 10) {
            // Has country code but not +91
            formattedPhone = '+$cleaned';
          } else {
            // Too short or invalid, skip
            continue;
          }

          // Add to list if not already seen (avoid duplicates)
          if (!seenPhones.contains(formattedPhone)) {
            phoneNumbers.add(formattedPhone);
            seenPhones.add(formattedPhone);
          }
        }
      }

      Logger.d('Extracted ${phoneNumbers.length} phone numbers from contacts');
      return phoneNumbers;
    } catch (e) {
      Logger.e('Error reading contacts', e);
      return [];
    }
  }

  /// Get contacts with phone numbers and names
  /// 
  /// Returns: List of maps with phoneNumber and contactName
  Future<List<Map<String, String>>> getContactsWithNames() async {
    try {
      final hasPermission = await this.hasPermission();
      if (!hasPermission) {
        Logger.w('Contacts permission not granted');
        return [];
      }

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      final contactList = <Map<String, String>>[];
      final seenPhones = <String>{};

      for (final contact in contacts) {
        final contactName = contact.name.first;
        
        for (final phone in contact.phones) {
          // Clean phone number: remove spaces, dashes, parentheses
          var cleaned = phone.number.replaceAll(RegExp(r'[\s\-\(\)]'), '');
          
          // Remove leading + if present (we'll add it back)
          if (cleaned.startsWith('+')) {
            cleaned = cleaned.substring(1);
          }

          // Skip if empty or too short
          if (cleaned.isEmpty || cleaned.length < 7) {
            continue;
          }

          // Format as E.164 (assume India +91 if no country code)
          String formattedPhone;
          if (cleaned.length == 10) {
            // 10 digits - assume India (+91)
            formattedPhone = '+91$cleaned';
          } else if (cleaned.length > 10 && cleaned.startsWith('91')) {
            // Already has country code
            formattedPhone = '+$cleaned';
          } else if (cleaned.length > 10) {
            // Has country code but not +91
            formattedPhone = '+$cleaned';
          } else {
            // Too short or invalid, skip
            continue;
          }

          // Add to list if not already seen (avoid duplicates)
          if (!seenPhones.contains(formattedPhone)) {
            contactList.add({
              'phoneNumber': formattedPhone,
              'contactName': contactName,
            });
            seenPhones.add(formattedPhone);
          }
        }
      }

      Logger.d('Extracted ${contactList.length} contacts with names');
      return contactList;
    } catch (e) {
      Logger.e('Error reading contacts with names', e);
      return [];
    }
  }

  /// Get contact name by phone number
  /// 
  /// Returns the contact name if found, null otherwise
  Future<String?> getContactName(String phoneNumber) async {
    try {
      final hasPermission = await this.hasPermission();
      if (!hasPermission) {
        return null;
      }

      // Clean phone number for comparison
      final cleaned = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
      
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      for (final contact in contacts) {
        for (final phone in contact.phones) {
          final contactPhone = phone.number.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
          
          // Check if phone numbers match (with or without country code)
          if (contactPhone == cleaned ||
              contactPhone.endsWith(cleaned) ||
              cleaned.endsWith(contactPhone)) {
            return contact.name.first;
          }
        }
      }

      return null;
    } catch (e) {
      Logger.d('Error getting contact name for $phoneNumber: $e');
      return null;
    }
  }

  /// Get contact count
  Future<int> getContactCount() async {
    try {
      final hasPermission = await this.hasPermission();
      if (!hasPermission) {
        return 0;
      }

      final contacts = await FlutterContacts.getContacts();
      return contacts.length;
    } catch (e) {
      Logger.e('Error getting contact count', e);
      return 0;
    }
  }
}
