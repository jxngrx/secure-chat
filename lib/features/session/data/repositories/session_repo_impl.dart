import '../../domain/repositories/session_repository.dart';
import '../../domain/entities/session_entity.dart';
import '../datasources/session_remote_ds.dart';
import '../models/session_model.dart';

class SessionRepositoryImpl implements SessionRepository {
  SessionRepositoryImpl._();

  static final SessionRepositoryImpl instance = SessionRepositoryImpl._();

  final SessionRemoteDataSource _remoteDataSource = SessionRemoteDataSource.instance;

  @override
  Future<SessionEntity> createSession({
    required String deviceId,
    required String loginMethod,
    Map<String, dynamic>? location,
  }) async {
    final response = await _remoteDataSource.createSession(
      deviceId: deviceId,
      loginMethod: loginMethod,
      location: location,
    );
    final model = SessionModel.fromJson(response);
    return model.toEntity();
  }

  @override
  Future<List<SessionEntity>> getSessions() async {
    final response = await _remoteDataSource.getSessions();
    return response
        .map((json) => SessionModel.fromJson(json))
        .map((model) => model.toEntity())
        .toList();
  }

  @override
  Future<void> deactivateSession(String sessionId) async {
    await _remoteDataSource.deactivateSession(sessionId);
  }

  @override
  Future<void> deactivateAllSessions() async {
    await _remoteDataSource.deactivateAllSessions();
  }
}
