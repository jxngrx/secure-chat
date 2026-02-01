import '../../domain/repositories/message_repository.dart';
import '../../domain/entities/message_entity.dart';
import '../datasources/message_remote_ds.dart';
import '../models/message_model.dart';
import '../../../../core/models/paginated_result.dart';

class MessageRepositoryImpl implements MessageRepository {
  MessageRepositoryImpl._();

  static final MessageRepositoryImpl instance = MessageRepositoryImpl._();

  final MessageRemoteDataSource _remoteDataSource = MessageRemoteDataSource.instance;

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
  Future<PaginatedResult<MessageEntity>> getChatMessages({
    required String chatId,
    int limit = 50,
    String? before,
  }) async {
    final result = await _remoteDataSource.getChatMessages(
      chatId: chatId,
      limit: limit,
      before: before,
    );

    final entities = result.items.map((json) {
      final model = MessageModel.fromJson(json);
      return model.toEntity();
    }).toList();

    return PaginatedResult(
      items: entities,
      hasMore: result.hasMore,
      nextCursor: result.nextCursor,
    );
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
