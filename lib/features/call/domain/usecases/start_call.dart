import '../repositories/call_repository.dart';

class StartCallUseCase {
  StartCallUseCase(this._repository);

  final CallRepository _repository;

  Future<void> call(String recipientId) async {
    await _repository.startCall(recipientId);
  }
}
