import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/user_entity.dart';
import '../datasources/auth_remote_ds.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl._();

  static final AuthRepositoryImpl instance = AuthRepositoryImpl._();

  final AuthRemoteDataSource _remoteDataSource = AuthRemoteDataSource.instance;

  @override
  Future<void> sendOtp(String phoneNumber) async {
    await _remoteDataSource.sendOtp(phoneNumber);
  }

  @override
  Future<UserEntity> verifyOtp(String phoneNumber, String otp) async {
    final response = await _remoteDataSource.verifyOtp(phoneNumber, otp);
    final userModel = UserModel.fromJson(response);
    return UserEntity(
      id: userModel.id,
      phoneNumber: userModel.phoneNumber,
      username: userModel.username,
      displayName: userModel.displayName,
      avatarUrl: userModel.avatarUrl,
    );
  }

  @override
  Future<void> setUsername(String username) async {
    await _remoteDataSource.setUsername(username);
  }
}
