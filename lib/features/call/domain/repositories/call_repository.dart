import '../entities/call_entity.dart';

abstract class CallRepository {
  Future<CallEntity> initiateCall(String receiverId);
  Future<CallEntity> answerCall(String callId);
  Future<void> rejectCall(String callId);
  Future<CallEntity> endCall(String callId);
  Future<List<CallEntity>> getCallHistory({int limit = 50});
}
