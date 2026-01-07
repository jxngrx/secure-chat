import '../../../session/domain/entities/session_entity.dart';
import 'user_entity.dart';

class AuthResultEntity {
  const AuthResultEntity({
    required this.token,
    required this.user,
    this.session,
  });

  final String token;
  final UserEntity user;
  final SessionEntity? session;
}
