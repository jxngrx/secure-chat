import '../entities/contact_entity.dart';

abstract class ContactRepository {
  Future<List<ContactEntity>> syncContacts(List<String> phoneNumbers);
  Future<List<ContactEntity>> getContacts();
}
