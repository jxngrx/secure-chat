import '../entities/user_entity.dart';

abstract class UserRepository {
  Future<UserEntity> getProfile();
  Future<List<UserEntity>> searchUsers(String query);
  Future<UserEntity> getUserById(String userId);
}
