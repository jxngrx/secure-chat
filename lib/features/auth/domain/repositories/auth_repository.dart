import '../entities/auth_result_entity.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<void> requestOtp(String phoneNumber);
  Future<AuthResultEntity> verifyOtp({
    required String phoneNumber,
    required String otp,
    String? deviceId,
    Map<String, dynamic>? location,
  });
  Future<UserEntity> updateUsername(String username);
}
