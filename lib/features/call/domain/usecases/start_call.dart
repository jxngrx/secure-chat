import '../repositories/call_repository.dart';

class StartCallUseCase {
  StartCallUseCase(this._repository);

  final CallRepository _repository;

  Future<Map<String, dynamic>> call(String receiverId) async {
    return await _repository.initiateCall(receiverId);
  }
}
