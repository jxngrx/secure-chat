import '../../../session/domain/entities/session_entity.dart';
import '../../domain/entities/user_entity.dart';

enum AuthStatus {
  initial,
  otpSending,
  otpSent,
  verifyingOtp,
  otpVerified,
  usernameUpdating,
  usernameUpdated,
  error,
}

class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.phoneNumber,
    this.user,
    this.session,
    this.errorMessage,
  });

  final AuthStatus status;
  final String? phoneNumber;
  final UserEntity? user;
  final SessionEntity? session;
  final String? errorMessage;

  factory AuthState.initial() => const AuthState();

  bool get isLoading =>
      status == AuthStatus.otpSending ||
      status == AuthStatus.verifyingOtp ||
      status == AuthStatus.usernameUpdating;

  bool get requiresUsername => (user?.username ?? '').isEmpty;

  AuthState copyWith({
    AuthStatus? status,
    String? phoneNumber,
    UserEntity? user,
    SessionEntity? session,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      user: user ?? this.user,
      session: session ?? this.session,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
