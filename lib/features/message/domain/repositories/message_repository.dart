import '../entities/message_entity.dart';
import '../../../../core/models/paginated_result.dart';

abstract class MessageRepository {
  Future<MessageEntity> sendMessage({
    required String chatId,
    required String type,
    required String content,
  });

  Future<PaginatedResult<MessageEntity>> getChatMessages({
    required String chatId,
    int limit = 50,
    String? before,
  });

  Future<void> markAsRead(String chatId);
  Future<void> markAsDelivered(String chatId);
  Future<MessageEntity> editMessage({
    required String messageId,
    required String content,
  });
  Future<void> deleteMessage({
    required String messageId,
    bool deleteForEveryone = false,
  });
}
