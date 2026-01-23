import '../../domain/repositories/chat_repository.dart';
import '../../domain/entities/chat_entity.dart';
import '../../../message/domain/entities/message_entity.dart';
import '../datasources/chat_remote_ds.dart';
import '../datasources/chat_socket_ds.dart';
import '../models/chat_model.dart';
import '../../../message/data/models/message_model.dart' as MessageModel;

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl._();

  static final ChatRepositoryImpl instance = ChatRepositoryImpl._();

  final ChatRemoteDataSource _remoteDataSource = ChatRemoteDataSource.instance;
  final ChatSocketDataSource _socketDataSource = ChatSocketDataSource.instance;

  @override
  Future<List<ChatEntity>> getChats() async {
    final response = await _remoteDataSource.getChats();
    return response
        .map((json) => ChatModel.fromJson(json))
        .map((model) => ChatEntity(
              id: model.id,
              name: model.name,
              participantIds: model.participantIds,
              lastMessageId: model.lastMessageId,
              lastMessageTime: model.lastMessageTime,
              isGroup: model.isGroup,
            ))
        .toList();
  }

  @override
  Future<ChatEntity> getChatById(String chatId) async {
    final response = await _remoteDataSource.getChatById(chatId);
    final model = ChatModel.fromJson(response);
    return ChatEntity(
      id: model.id,
      name: model.name,
      participantIds: model.participantIds,
      lastMessageId: model.lastMessageId,
      lastMessageTime: model.lastMessageTime,
      isGroup: model.isGroup,
    );
  }

  @override
  Future<ChatEntity> createOrGetChat(String otherUserId) async {
    final response = await _remoteDataSource.createOrGetChat(otherUserId);
    final model = ChatModel.fromJson(response);
    return ChatEntity(
      id: model.id,
      name: model.name,
      participantIds: model.participantIds,
      lastMessageId: model.lastMessageId,
      lastMessageTime: model.lastMessageTime,
      isGroup: model.isGroup,
    );
  }

  @override
  Future<List<MessageEntity>> getMessages(String chatId) async {
    final response = await _remoteDataSource.getMessages(chatId);
    return response
        .map((json) => MessageModel.MessageModel.fromJson(json))
        .map((model) => MessageEntity(
              id: model.id,
              chatId: model.chatId,
              senderId: model.senderId,
              senderName: model.senderName,
              senderAvatar: model.senderAvatar,
              content: model.content,
              type: model.type,
              timestamp: model.timestamp,
              status: model.status,
              editedAt: model.editedAt,
              mediaUrl: model.mediaUrl,
              mediaSize: model.mediaSize,
              voiceDuration: model.voiceDuration,
            ))
        .toList();
  }

  @override
  Future<MessageEntity> sendMessage(String chatId, String content) async {
    final response = await _remoteDataSource.sendMessage(chatId, content);
    final model = MessageModel.MessageModel.fromJson(response);
    return MessageEntity(
      id: model.id,
      chatId: model.chatId,
      senderId: model.senderId,
      senderName: model.senderName,
      senderAvatar: model.senderAvatar,
      content: model.content,
      type: model.type,
      timestamp: model.timestamp,
      status: model.status,
      editedAt: model.editedAt,
      mediaUrl: model.mediaUrl,
      mediaSize: model.mediaSize,
      voiceDuration: model.voiceDuration,
    );
  }
}
