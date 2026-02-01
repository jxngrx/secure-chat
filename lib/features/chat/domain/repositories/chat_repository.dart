import '../entities/chat_entity.dart';
import '../../../../core/models/paginated_result.dart';
import '../../../message/domain/entities/message_entity.dart';

abstract class ChatRepository {
  Future<PaginatedResult<ChatEntity>> getChats({
    int limit = 50,
    String? before,
  });
  Future<ChatEntity> getChatById(String chatId);
  Future<ChatEntity> createOrGetChat(String otherUserId);
  Future<List<MessageEntity>> getMessages(String chatId);
  Future<MessageEntity> sendMessage(String chatId, String content);
  Future<void> deleteChat(String chatId);
}
