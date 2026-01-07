import 'dart:convert';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../domain/entities/auth_result_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
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
  Future<void> requestOtp(String phoneNumber) async {
    await _remoteDataSource.requestOtp(phoneNumber);
  }

  @override
  Future<AuthResultEntity> verifyOtp({
    required String phoneNumber,
    required String otp,
    String? deviceId,
    Map<String, dynamic>? location,
  }) async {
    final response = await _remoteDataSource.verifyOtp(
      phoneNumber: phoneNumber,
      otp: otp,
      deviceId: deviceId,
      location: location,
    );

    final token = response['token'] as String? ?? '';
    final sessionData = response['session'] as Map<String, dynamic>?;
    final userData = response['user'] as Map<String, dynamic>? ?? {};

    final userModel = UserModel.fromJson(userData);
    final userEntity = userModel.toEntity();

    await _secureStorage.write(StorageKeys.authToken, token);
    if (sessionData != null && sessionData['sessionId'] != null) {
      await _secureStorage.write(
        StorageKeys.sessionId,
        sessionData['sessionId'] as String,
      );
      if (sessionData['deviceId'] != null) {
        await _secureStorage.write(
          StorageKeys.deviceId,
          sessionData['deviceId'] as String,
        );
      }
    }

    await _localStorage.write(
      StorageKeys.userProfile,
      jsonEncode(userModel.toJson()),
    );

    return AuthResultEntity(
      token: token,
      user: userEntity,
      session: sessionData == null
          ? null
          : SessionEntity(
              sessionId: sessionData['sessionId'] as String,
              deviceId: sessionData['deviceId'] as String? ?? '',
              loginMethod: sessionData['loginMethod'] as String? ?? 'phone',
              isActive: sessionData['isActive'] as bool? ?? true,
              expiresAt: sessionData['expiresAt'] is String
                  ? DateTime.tryParse(sessionData['expiresAt'] as String)
                  : null,
            ),
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
