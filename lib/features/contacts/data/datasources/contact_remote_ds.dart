import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../../core/network/api_client.dart';

class ContactRemoteDataSource {
  ContactRemoteDataSource._();

  static final ContactRemoteDataSource instance = ContactRemoteDataSource._();

  final ApiClient _apiClient = ApiClient.instance;

  /// Hash phone number using SHA-256
  String _hashPhoneNumber(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final bytes = utf8.encode(cleaned);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Sync contacts with backend (phone numbers are hashed)
  Future<List<Map<String, dynamic>>> syncContacts(List<String> phoneNumbers) async {
    final phoneHashes = phoneNumbers.map(_hashPhoneNumber).toList();

    final response = await _apiClient.post('/contacts/sync', {
      'phoneHashes': phoneHashes,
    });

    final contacts = response['data']?['contacts'] as List<dynamic>? ?? [];
    return contacts.cast<Map<String, dynamic>>();
  }

  /// Get contacts
  Future<List<Map<String, dynamic>>> getContacts() async {
    final response = await _apiClient.get('/contacts');
    final contacts = response['data']?['contacts'] as List<dynamic>? ?? [];
    return contacts.cast<Map<String, dynamic>>();
  }
}
