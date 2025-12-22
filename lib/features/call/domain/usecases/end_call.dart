import '../repositories/call_repository.dart';

class EndCallUseCase {
  EndCallUseCase(this._repository);

  final CallRepository _repository;

  Future<void> call(String callId) async {
    await _repository.endCall(callId);
  }
}
