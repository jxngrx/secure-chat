import '../entities/session_entity.dart';

abstract class SessionRepository {
  Future<SessionEntity> createSession({
    required String deviceId,
    required String loginMethod,
    Map<String, dynamic>? location,
  });

  Future<List<SessionEntity>> getSessions();
  Future<void> deactivateSession(String sessionId);
  Future<void> deactivateAllSessions();
}
