import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/contact_repository.dart';
import '../../domain/entities/contact_entity.dart';
import '../../../../core/utils/logger.dart';
import '../providers/contact_providers.dart';

class ContactState {
  final List<ContactEntity> contacts;
  final bool isLoading;
  final String? error;

  ContactState({
    this.contacts = const [],
    this.isLoading = false,
    this.error,
  });

  ContactState copyWith({
    List<ContactEntity>? contacts,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ContactState(
      contacts: contacts ?? this.contacts,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ContactController extends StateNotifier<ContactState> {
  ContactController(this._repository) : super(ContactState()) {
    loadContacts();
  }

  final ContactRepository _repository;

  Future<void> loadContacts() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final contacts = await _repository.getContacts();
      state = state.copyWith(contacts: contacts, isLoading: false);
    } catch (e) {
      Logger.e('Error loading contacts', e);
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> syncContacts(List<Map<String, String>> contacts) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final syncedContacts = await _repository.syncContacts(contacts);
      state = state.copyWith(contacts: syncedContacts, isLoading: false);
    } catch (e) {
      Logger.e('Error syncing contacts', e);
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

/// Contact controller provider
final contactControllerProvider = StateNotifierProvider<ContactController, ContactState>((ref) {
  final repository = ref.watch(contactRepositoryProvider);
  return ContactController(repository);
});
