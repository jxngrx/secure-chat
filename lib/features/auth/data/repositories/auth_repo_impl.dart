import 'dart:convert';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../domain/entities/auth_result_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../session/domain/entities/session_entity.dart';
import '../datasources/auth_remote_ds.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(
    this._remoteDataSource, {
    required SecureStorage secureStorage,
    required LocalStorage localStorage,
  })  : _secureStorage = secureStorage,
        _localStorage = localStorage;

  final AuthRemoteDataSource _remoteDataSource;
  final SecureStorage _secureStorage;
  final LocalStorage _localStorage;

  @override
  Future<AuthResultEntity> register({
    String? username,
    required String password,
    required String deviceId,
    String? phone,
  }) async {
    final response = await _remoteDataSource.register(
      username: username,
      password: password,
      deviceId: deviceId,
      phone: phone,
    );
    return _handleAuthResponse(response, deviceId);
  }

  @override
  Future<AuthResultEntity> login({
    required String username,
    required String password,
    required String deviceId,
  }) async {
    final response = await _remoteDataSource.login(
      username: username,
      password: password,
      deviceId: deviceId,
    );
    return _handleAuthResponse(response, deviceId);
  }

  Future<AuthResultEntity> _handleAuthResponse(
    Map<String, dynamic> response,
    String deviceId,
  ) async {
    final token = response['token'] as String? ?? '';
    final userData = response['user'] as Map<String, dynamic>? ?? {};

    final userModel = UserModel.fromJson(userData);
    final userEntity = userModel.toEntity();

    await _secureStorage.write(StorageKeys.authToken, token);
    await _secureStorage.write(StorageKeys.deviceId, deviceId);

    // Backend v2.0 guide does not return session object on login/register
    // creating a dummy session entity or null if not needed strictly
    // Assuming UI/App needs session entity? current AuthResultEntity needs it?
    // Let's check AuthResultEntity definition.
    // If not returned, we can construct a local one or pass null if nullable.

    final sessionId = response['sessionId'] as String?;
    if (sessionId != null && sessionId.isNotEmpty) {
      await _secureStorage.write(StorageKeys.sessionId, sessionId);
    }

    await _localStorage.write(
      StorageKeys.userProfile,
      jsonEncode(userModel.toJson()),
    );

    return AuthResultEntity(
      token: token,
      user: userEntity,
      session: null, // Session object details not returned, only ID if any
    );
  }

  @override
  Future<UserEntity> updateUsername(String username) async {
    final response = await _remoteDataSource.updateUsername(username);
    final updatedModel = UserModel.fromJson(response);
    final user = updatedModel.toEntity();
    await _localStorage.write(
      StorageKeys.userProfile,
      jsonEncode(updatedModel.toJson()),
    );
    return user;
  }
}
