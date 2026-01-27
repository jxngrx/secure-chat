import 'dart:convert';
import '../../domain/repositories/message_repository.dart';
import '../../domain/entities/message_entity.dart';
import '../datasources/message_remote_ds.dart';
import '../models/message_model.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../di/injection_container.dart';

class MessageRepositoryImpl implements MessageRepository {
  MessageRepositoryImpl._();

  static final MessageRepositoryImpl instance = MessageRepositoryImpl._();

  final MessageRemoteDataSource _remoteDataSource = MessageRemoteDataSource.instance;

  Future<String?> _getCurrentUserId() async {
    try {
      final localStorage = InjectionContainer.resolve<LocalStorage>();
      final userProfileJson = await localStorage.read(StorageKeys.userProfile);
      if (userProfileJson != null && userProfileJson.isNotEmpty) {
        final userProfile = jsonDecode(userProfileJson) as Map<String, dynamic>;
        return userProfile['id'] as String?;
      }
    } catch (e) {
      // Silently fail
    }
    return null;
  }

  @override
  Future<MessageEntity> sendMessage({
    required String chatId,
    required String type,
    required String content,
  }) async {
    final response = await _remoteDataSource.sendMessage(
      chatId: chatId,
      type: type,
      content: content,
    );
    final model = MessageModel.fromJson(response);
    return model.toEntity();
  }

  @override
  Future<List<MessageEntity>> getChatMessages({
    required String chatId,
    int limit = 50,
    String? before,
  }) async {
    final response = await _remoteDataSource.getChatMessages(
      chatId: chatId,
      limit: limit,
      before: before,
    );
    final currentUserId = await _getCurrentUserId();
    
    return response
        .map((json) {
          final model = MessageModel.fromJson(json);
          // Check if message is deleted for current user
          final deletedFor = json['deletedFor'] as List<dynamic>? ?? [];
          final isDeleted = currentUserId != null && 
              deletedFor.any((id) => id.toString() == currentUserId);
          return model.toEntity(isDeleted: isDeleted);
        })
        .toList();
  }

  @override
  Future<void> markAsRead(String chatId) async {
    await _remoteDataSource.markAsRead(chatId);
  }

  @override
  Future<void> markAsDelivered(String chatId) async {
    await _remoteDataSource.markAsDelivered(chatId);
  }

  @override
  Future<MessageEntity> editMessage({
    required String messageId,
    required String content,
  }) async {
    final response = await _remoteDataSource.editMessage(
      messageId: messageId,
      content: content,
    );
    final model = MessageModel.fromJson(response);
    return model.toEntity();
  }

  @override
  Future<void> deleteMessage({
    required String messageId,
    bool deleteForEveryone = false,
  }) async {
    await _remoteDataSource.deleteMessage(
      messageId: messageId,
      deleteForEveryone: deleteForEveryone,
    );
  }
}
