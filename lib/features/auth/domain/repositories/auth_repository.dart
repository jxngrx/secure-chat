import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<void> sendOtp(String phoneNumber);
  Future<UserEntity> verifyOtp(String phoneNumber, String otp);
  Future<void> setUsername(String username);
}
