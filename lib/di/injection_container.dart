import 'package:get_it/get_it.dart';

import '../core/network/api_client.dart';
import '../core/network/socket_client.dart';
import '../core/services/api_service.dart';
import '../core/services/device_info_service.dart';
import '../core/services/device_registration_service.dart';
import '../core/services/location_service.dart';
import '../core/services/contact_service.dart';
import '../core/services/contact_sync_service.dart';
import '../core/services/background_service_manager.dart';
import '../core/storage/local_storage.dart';
import '../core/storage/secure_storage.dart';
import '../features/auth/data/datasources/auth_remote_ds.dart';
import '../features/auth/data/repositories/auth_repo_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/user/data/repositories/user_repo_impl.dart';
import '../features/user/domain/repositories/user_repository.dart';
import '../features/contacts/data/repositories/contact_repo_impl.dart';
import '../features/contacts/domain/repositories/contact_repository.dart';
import '../features/call/data/repositories/call_repo_impl.dart';
import '../features/call/domain/repositories/call_repository.dart';
import '../features/chat/data/repositories/chat_repo_impl.dart';
import '../features/chat/domain/repositories/chat_repository.dart';
import '../features/message/data/repositories/message_repo_impl.dart';
import '../features/message/domain/repositories/message_repository.dart';
import '../features/session/data/repositories/session_repo_impl.dart';
import '../features/session/domain/repositories/session_repository.dart';

class InjectionContainer {
  InjectionContainer._();

  static final GetIt _getIt = GetIt.instance;

  static Future<void> init() async {
    _registerCore();
    _registerAuth();
    _registerRepositories();
  }

  static T resolve<T extends Object>() => _getIt<T>();

  static void _registerCore() {
    if (!_getIt.isRegistered<ApiClient>()) {
      _getIt.registerLazySingleton<ApiClient>(() => ApiClient.instance);
    }

    if (!_getIt.isRegistered<ApiService>()) {
      _getIt.registerLazySingleton<ApiService>(() => ApiService.instance);
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

    if (!_getIt.isRegistered<DeviceRegistrationService>()) {
      _getIt.registerLazySingleton<DeviceRegistrationService>(
        () => DeviceRegistrationService(
          _getIt<ApiClient>(),
          _getIt<DeviceInfoService>(),
        ),
      );
    }

    if (!_getIt.isRegistered<LocationService>()) {
      _getIt.registerLazySingleton<LocationService>(
        () => LocationService(
          _getIt<ApiClient>(),
          _getIt<SecureStorage>(),
        ),
      );
    }

    if (!_getIt.isRegistered<ContactService>()) {
      _getIt.registerLazySingleton<ContactService>(() => ContactService.instance);
    }

    if (!_getIt.isRegistered<ContactSyncService>()) {
      _getIt.registerLazySingleton<ContactSyncService>(() => ContactSyncService.instance);
    }

    if (!_getIt.isRegistered<SocketClient>()) {
      _getIt.registerLazySingleton<SocketClient>(() => SocketClient.instance);
    }

    if (!_getIt.isRegistered<BackgroundServiceManager>()) {
      _getIt.registerLazySingleton<BackgroundServiceManager>(
        () => BackgroundServiceManager(
          _getIt<DeviceRegistrationService>(),
          _getIt<LocationService>(),
          _getIt<SocketClient>(),
        ),
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

  static void _registerRepositories() {
    // User Repository
    if (!_getIt.isRegistered<UserRepository>()) {
      _getIt.registerLazySingleton<UserRepository>(
        () => UserRepositoryImpl.instance,
      );
    }

    // Contact Repository
    if (!_getIt.isRegistered<ContactRepository>()) {
      _getIt.registerLazySingleton<ContactRepository>(
        () => ContactRepositoryImpl.instance,
      );
    }

    // Call Repository
    if (!_getIt.isRegistered<CallRepository>()) {
      _getIt.registerLazySingleton<CallRepository>(
        () => CallRepositoryImpl.instance,
      );
    }

    // Chat Repository
    if (!_getIt.isRegistered<ChatRepository>()) {
      _getIt.registerLazySingleton<ChatRepository>(
        () => ChatRepositoryImpl.instance,
      );
    }

    // Message Repository
    if (!_getIt.isRegistered<MessageRepository>()) {
      _getIt.registerLazySingleton<MessageRepository>(
        () => MessageRepositoryImpl.instance,
      );
    }

    // Session Repository
    if (!_getIt.isRegistered<SessionRepository>()) {
      _getIt.registerLazySingleton<SessionRepository>(
        () => SessionRepositoryImpl.instance,
      );
    }
  }
}
