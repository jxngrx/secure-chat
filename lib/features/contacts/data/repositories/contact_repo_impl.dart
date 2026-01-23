import '../../domain/repositories/contact_repository.dart';
import '../../domain/entities/contact_entity.dart';
import '../datasources/contact_remote_ds.dart';
import '../models/contact_model.dart';

class ContactRepositoryImpl implements ContactRepository {
  ContactRepositoryImpl._();

  static final ContactRepositoryImpl instance = ContactRepositoryImpl._();

  final ContactRemoteDataSource _remoteDataSource = ContactRemoteDataSource.instance;

  @override
  Future<List<ContactEntity>> syncContacts(List<String> phoneNumbers) async {
    final response = await _remoteDataSource.syncContacts(phoneNumbers);
    return response
        .map((json) => ContactModel.fromJson(json))
        .map((model) => ContactEntity(
              userId: model.id,
              phone: model.phoneNumber ?? '',
              username: model.username,
              isOnline: model.isOnline,
              lastSeen: null, // Add if available in response
            ))
        .toList();
  }

  @override
  Future<List<ContactEntity>> getContacts() async {
    final response = await _remoteDataSource.getContacts();
    return response
        .map((json) => ContactModel.fromJson(json))
        .map((model) => ContactEntity(
              userId: model.id,
              phone: model.phoneNumber ?? '',
              username: model.username,
              isOnline: model.isOnline,
              lastSeen: null,
            ))
        .toList();
  }
}
