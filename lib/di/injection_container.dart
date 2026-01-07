import 'package:get_it/get_it.dart';

import '../core/network/api_client.dart';
import '../core/services/device_info_service.dart';
import '../core/storage/local_storage.dart';
import '../core/storage/secure_storage.dart';
import '../features/auth/data/datasources/auth_remote_ds.dart';
import '../features/auth/data/repositories/auth_repo_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';

class InjectionContainer {
  InjectionContainer._();

  static final GetIt _getIt = GetIt.instance;

  static Future<void> init() async {
    _registerCore();
    _registerAuth();
  }

  static T resolve<T extends Object>() => _getIt<T>();

  static void _registerCore() {
    if (!_getIt.isRegistered<ApiClient>()) {
      _getIt.registerLazySingleton<ApiClient>(() => ApiClient.instance);
    }

    if (!_getIt.isRegistered<SecureStorage>()) {
      _getIt.registerLazySingleton<SecureStorage>(() => SecureStorage.instance);
    }

    if (!_getIt.isRegistered<LocalStorage>()) {
      _getIt.registerLazySingleton<LocalStorage>(() => LocalStorage.instance);
    }

    if (!_getIt.isRegistered<DeviceInfoService>()) {
      _getIt.registerLazySingleton<DeviceInfoService>(
        () => DeviceInfoService(_getIt<SecureStorage>()),
      );
    }
  }

  static void _registerAuth() {
    if (!_getIt.isRegistered<AuthRemoteDataSource>()) {
      _getIt.registerLazySingleton<AuthRemoteDataSource>(
        () => AuthRemoteDataSource(_getIt<ApiClient>()),
      );
    }

    if (!_getIt.isRegistered<AuthRepository>()) {
      _getIt.registerLazySingleton<AuthRepository>(
        () => AuthRepositoryImpl(
          _getIt<AuthRemoteDataSource>(),
          secureStorage: _getIt<SecureStorage>(),
          localStorage: _getIt<LocalStorage>(),
        ),
      );
    }
  }
}
