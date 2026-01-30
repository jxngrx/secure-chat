import '../../../session/domain/entities/session_entity.dart';
import '../../domain/entities/user_entity.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  usernameUpdating,
  usernameUpdated,
  error,
}

class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.session,
    this.errorMessage,
  });

  final AuthStatus status;
  final UserEntity? user;
  final SessionEntity? session;
  final String? errorMessage;

  factory AuthState.initial() => const AuthState();

  bool get isLoading =>
      status == AuthStatus.loading ||
      status == AuthStatus.usernameUpdating;

  bool get requiresUsername => (user?.username ?? '').isEmpty;

  AuthState copyWith({
    AuthStatus? status,
    UserEntity? user,
    SessionEntity? session,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      session: session ?? this.session,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
