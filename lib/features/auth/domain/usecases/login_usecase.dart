import '../repositories/auth_repository.dart';

class LoginUseCase {
  LoginUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call(String phoneNumber) async {
    await _repository.sendOtp(phoneNumber);
  }
}
