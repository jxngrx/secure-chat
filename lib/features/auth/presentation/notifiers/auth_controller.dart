import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../device/domain/entities/device_entity.dart';
import '../../../session/domain/entities/session_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(AuthState.initial());

  final AuthRepository _repository;

  Future<void> requestOtp(String phoneNumber) async {
    state = state.copyWith(
      status: AuthStatus.otpSending,
      phoneNumber: phoneNumber,
      clearError: true,
    );
    try {
      await _repository.requestOtp(phoneNumber);
      state = state.copyWith(status: AuthStatus.otpSent);
    } catch (error) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> verifyOtp({
    required String phoneNumber,
    required String otp,
    DeviceEntity? device,
    Map<String, dynamic>? location,
  }) async {
    state = state.copyWith(
      status: AuthStatus.verifyingOtp,
      clearError: true,
    );
    try {
      final result = await _repository.verifyOtp(
        phoneNumber: phoneNumber,
        otp: otp,
        deviceId: device?.deviceId,
        location: location,
      );
      state = state.copyWith(
        status: AuthStatus.otpVerified,
        user: result.user,
        session: result.session,
      );
    } catch (error) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: error.toString(),
      );
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
