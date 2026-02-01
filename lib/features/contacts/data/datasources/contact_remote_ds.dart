import '../../../../core/network/api_client.dart';

class ContactRemoteDataSource {
  ContactRemoteDataSource._();

  static final ContactRemoteDataSource instance = ContactRemoteDataSource._();

  final ApiClient _apiClient = ApiClient.instance;

  /// Sync contacts with backend using new format
  /// 
  /// [contacts] - List of maps with phoneNumber and contactName:
  /// [
  ///   {
  ///     "phoneNumber": "+1234567890",
  ///     "contactName": "John Doe"
  ///   }
  /// ]
  Future<List<Map<String, dynamic>>> syncContacts(
    List<Map<String, String>> contacts,
  ) async {
    final response = await _apiClient.post('/contacts/sync', {
      'contacts': contacts,
    });

    final syncedContacts = response['data']?['contacts'] as List<dynamic>? ?? [];
    return syncedContacts.cast<Map<String, dynamic>>();
  }

  /// Get contacts
  Future<List<Map<String, dynamic>>> getContacts() async {
    final response = await _apiClient.get('/contacts');
    final contacts = response['data']?['contacts'] as List<dynamic>? ?? [];
    return contacts.cast<Map<String, dynamic>>();
  }
}
