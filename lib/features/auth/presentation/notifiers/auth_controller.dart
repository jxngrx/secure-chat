import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/services/background_service_manager.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/ip_logging_service.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/utils/logger.dart';
import '../../../../di/injection_container.dart';
import '../../../session/domain/entities/session_entity.dart';
import '../../../session/domain/repositories/session_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository, this._sessionRepository) : super(AuthState.initial());

  final AuthRepository _repository;
  final SessionRepository _sessionRepository;
  final Uuid _uuid = const Uuid();

  Future<String> _getDeviceId() async {
    final storage = SecureStorage.instance;
    String? deviceId = await storage.read(StorageKeys.deviceId);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = _uuid.v4();
      await storage.write(StorageKeys.deviceId, deviceId);
    }
    return deviceId;
  }

  Future<void> register({
    String? username,
    required String password,
    String? phone,
  }) async {
    state = state.copyWith(
      status: AuthStatus.loading,
      clearError: true,
    );
    try {
      final deviceId = await _getDeviceId();
      
      // Get current location
      final locationService = InjectionContainer.resolve<LocationService>();
      final location = await locationService.getCurrentLocation();
      
      final result = await _repository.register(
        username: username,
        password: password,
        deviceId: deviceId,
        phone: phone,
        location: location,
      );

      // Log IP after successful registration
      try {
        final ipLoggingService = InjectionContainer.resolve<IPLoggingService>();
        await ipLoggingService.logIP(action: 'login', metadata: {
          'endpoint': '/auth/register',
          'method': 'POST',
        });
      } catch (e) {
        Logger.w('Failed to log IP after register', e);
      }

      // Create session if not returned
      SessionEntity? session = result.session;
      if (session == null) {
        try {
          session = await _sessionRepository.createSession(
            deviceId: deviceId,
            loginMethod: 'phone', // Defaulting to phone as per API convention
            location: location,
          );
          // Save sessionId to secure storage
          await SecureStorage.instance.write(StorageKeys.sessionId, session.sessionId);
        } catch (e) {
          Logger.e('Failed to create session after register', e);
        }
      }

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: result.user,
        session: session,
      );
      _initializeBackgroundServices();
    } catch (error) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(
      status: AuthStatus.loading,
      clearError: true,
    );
    try {
      final deviceId = await _getDeviceId();
      
      // Get current location
      final locationService = InjectionContainer.resolve<LocationService>();
      final location = await locationService.getCurrentLocation();
      
      final result = await _repository.login(
        username: username,
        password: password,
        deviceId: deviceId,
        location: location,
      );

      // Log IP after successful login
      try {
        final ipLoggingService = InjectionContainer.resolve<IPLoggingService>();
        await ipLoggingService.logIP(action: 'login', metadata: {
          'endpoint': '/auth/login',
          'method': 'POST',
        });
      } catch (e) {
        Logger.w('Failed to log IP after login', e);
      }

      // Create session if not returned
      SessionEntity? session = result.session;
      if (session == null) {
        try {
          session = await _sessionRepository.createSession(
            deviceId: deviceId,
            loginMethod: 'password',
            location: location,
          );
          // Save sessionId to secure storage
          await SecureStorage.instance.write(StorageKeys.sessionId, session.sessionId);
        } catch (e) {
          Logger.e('Failed to create session after login', e);
        }
      }

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: result.user,
        session: session,
      );
      _initializeBackgroundServices();
    } catch (error) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> _initializeBackgroundServices() async {
    try {
      final backgroundServiceManager =
          InjectionContainer.resolve<BackgroundServiceManager>();
      await backgroundServiceManager.initializeServices();
    } catch (e) {
      Logger.w('Error initializing background services: $e');
    }
  }

  Future<void> updateUsername(String username) async {
    state = state.copyWith(
      status: AuthStatus.usernameUpdating,
      clearError: true,
    );
    try {
      final user = await _repository.updateUsername(username);
      state = state.copyWith(
        status: AuthStatus.usernameUpdated,
        user: user,
      );
    } catch (error) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: error.toString(),
      );
    }
  }

  void resetError() {
    state = state.copyWith(clearError: true);
  }

  void reset() {
    state = AuthState.initial();
  }

  SessionEntity? get session => state.session;
}
