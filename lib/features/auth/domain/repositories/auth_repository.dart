import '../entities/auth_result_entity.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<AuthResultEntity> register({
    String? username,
    required String password,
    required String deviceId,
    String? phone,
    Map<String, dynamic>? location,
  });

  Future<AuthResultEntity> login({
    required String username,
    required String password,
    required String deviceId,
    Map<String, dynamic>? location,
  });

  Future<UserEntity> updateUsername(String username);
}
