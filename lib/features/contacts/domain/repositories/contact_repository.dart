import '../entities/contact_entity.dart';

abstract class ContactRepository {
  Future<List<ContactEntity>> syncContacts(List<Map<String, String>> contacts);
  Future<List<ContactEntity>> getContacts();
}
