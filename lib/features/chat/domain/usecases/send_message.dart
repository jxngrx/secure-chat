import '../entities/message_entity.dart';
import '../repositories/chat_repository.dart';

class SendMessageUseCase {
  SendMessageUseCase(this._repository);

  final ChatRepository _repository;

  Future<MessageEntity> call(String chatId, String content) async {
    return await _repository.sendMessage(chatId, content);
  }
}
