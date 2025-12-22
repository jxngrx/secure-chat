import '../entities/message_entity.dart';
import '../repositories/chat_repository.dart';

class ReceiveMessageUseCase {
  ReceiveMessageUseCase(this._repository);

  final ChatRepository _repository;

  Stream<MessageEntity> call() {
    // TODO: Implement message receiving stream
    throw UnimplementedError('ReceiveMessageUseCase.call not implemented');
  }
}
