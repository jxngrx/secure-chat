import '../../domain/repositories/user_repository.dart';
import '../../domain/entities/user_entity.dart';
import '../datasources/user_remote_ds.dart';
import '../models/user_model.dart';

class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl._();

  static final UserRepositoryImpl instance = UserRepositoryImpl._();

  final UserRemoteDataSource _remoteDataSource = UserRemoteDataSource.instance;

  @override
  Future<UserEntity> getProfile() async {
    final response = await _remoteDataSource.getProfile();
    final model = UserModel.fromJson(response);
    return model.toEntity();
  }

  @override
  Future<List<UserEntity>> searchUsers(String query) async {
    final response = await _remoteDataSource.searchUsers(query);
    return response
        .map((json) => UserModel.fromJson(json))
        .map((model) => model.toEntity())
        .toList();
  }

  @override
  Future<UserEntity> getUserById(String userId) async {
    final response = await _remoteDataSource.getUserById(userId);
    final model = UserModel.fromJson(response);
    return model.toEntity();
  }
}
