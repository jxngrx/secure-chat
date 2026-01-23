import '../../domain/repositories/call_repository.dart';
import '../../domain/entities/call_entity.dart';
import '../datasources/call_remote_ds.dart';
import '../datasources/call_socket_ds.dart';
import '../models/call_model.dart';

class CallRepositoryImpl implements CallRepository {
  CallRepositoryImpl._();

  static final CallRepositoryImpl instance = CallRepositoryImpl._();

  final CallRemoteDataSource _remoteDataSource = CallRemoteDataSource.instance;
  final CallSocketDataSource _socketDataSource = CallSocketDataSource.instance;

  @override
  Future<CallEntity> initiateCall(String receiverId) async {
    final response = await _remoteDataSource.initiateCall(receiverId);
    final model = CallModel.fromJson(response);
    return model.toEntity();
  }

  @override
  Future<CallEntity> answerCall(String callId) async {
    final response = await _remoteDataSource.answerCall(callId);
    final model = CallModel.fromJson(response);
    return model.toEntity();
  }

  @override
  Future<void> rejectCall(String callId) async {
    await _remoteDataSource.rejectCall(callId);
  }

  @override
  Future<CallEntity> endCall(String callId) async {
    final response = await _remoteDataSource.endCall(callId);
    final model = CallModel.fromJson(response);
    return model.toEntity();
  }

  @override
  Future<List<CallEntity>> getCallHistory({int limit = 50}) async {
    final response = await _remoteDataSource.getCallHistory(limit: limit);
    return response
        .map((json) => CallModel.fromJson(json))
        .map((model) => model.toEntity())
        .toList();
  }

  // Socket methods for real-time communication
  void initiateCallSocket(String receiverId) {
    _socketDataSource.initiateCall(receiverId);
  }

  void answerCallSocket(String callId) {
    _socketDataSource.answerCall(callId);
  }

  void rejectCallSocket(String callId) {
    _socketDataSource.rejectCall(callId);
  }

  void endCallSocket(String callId) {
    _socketDataSource.endCall(callId);
  }

  void sendWebRTCOffer({
    required String callId,
    required Map<String, dynamic> offer,
    required String receiverId,
  }) {
    _socketDataSource.sendWebRTCOffer(
      callId: callId,
      offer: offer,
      receiverId: receiverId,
    );
  }

  void sendWebRTCAnswer({
    required String callId,
    required Map<String, dynamic> answer,
    required String callerId,
  }) {
    _socketDataSource.sendWebRTCAnswer(
      callId: callId,
      answer: answer,
      callerId: callerId,
    );
  }

  void sendWebRTCIceCandidate({
    required String callId,
    required Map<String, dynamic> candidate,
    required String receiverId,
  }) {
    _socketDataSource.sendWebRTCIceCandidate(
      callId: callId,
      candidate: candidate,
      receiverId: receiverId,
    );
  }
}
