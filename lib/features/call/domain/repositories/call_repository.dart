abstract class CallRepository {
  Future<void> startCall(String recipientId);
  Future<void> endCall(String callId);
}
