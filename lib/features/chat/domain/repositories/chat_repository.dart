import '../entities/chat_entity.dart';
import '../../../message/domain/entities/message_entity.dart';

abstract class ChatRepository {
  Future<List<ChatEntity>> getChats();
  Future<ChatEntity> getChatById(String chatId);
  Future<ChatEntity> createOrGetChat(String otherUserId);
  Future<List<MessageEntity>> getMessages(String chatId);
  Future<MessageEntity> sendMessage(String chatId, String content);
}
