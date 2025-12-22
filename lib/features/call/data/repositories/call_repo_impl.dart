import '../../domain/repositories/call_repository.dart';
import '../datasources/call_socket_ds.dart';

class CallRepositoryImpl implements CallRepository {
  CallRepositoryImpl._();

  static final CallRepositoryImpl instance = CallRepositoryImpl._();

  final CallSocketDataSource _socketDataSource = CallSocketDataSource.instance;

  @override
  Future<void> startCall(String recipientId) async {
    _socketDataSource.startCall(recipientId);
  }

  @override
  Future<void> endCall(String callId) async {
    _socketDataSource.endCall(callId);
  }
}
