import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class VerifyOtpUseCase {
  VerifyOtpUseCase(this._repository);

  final AuthRepository _repository;

  Future<UserEntity> call(String phoneNumber, String otp) async {
    return await _repository.verifyOtp(phoneNumber, otp);
  }
}
