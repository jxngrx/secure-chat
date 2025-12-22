import '../entities/message_entity.dart';
import '../repositories/chat_repository.dart';

class EditMessageUseCase {
  EditMessageUseCase(this._repository);

  final ChatRepository _repository;

  Future<MessageEntity> call(String messageId, String newContent) async {
    // TODO: Implement edit message
    throw UnimplementedError('EditMessageUseCase.call not implemented');
  }
}

class DeleteMessageUseCase {
  DeleteMessageUseCase(this._repository);

  final ChatRepository _repository;

  Future<void> call(String messageId) async {
    // TODO: Implement delete message
    throw UnimplementedError('DeleteMessageUseCase.call not implemented');
  }
}
