import '../entities/call_entity.dart';

abstract class CallRepository {
  Future<void> initiateCall(String receiverId);
  Future<void> answerCall(String callId);
  Future<void> rejectCall(String callId);
  Future<void> endCall(String callId);
  Future<List<CallEntity>> getCallHistory({int limit = 20});

  // Socket methods are usually used directly by Controller in this architecture,
  // or via a Stream exposed by Repository.
  // Let's expose Streams for cleaner architecture

  Stream<dynamic> get onIncomingCall;
  Stream<dynamic> get onCallInitiated; // For sender to know it's ringing
  Stream<dynamic> get onCallAnswered;
  Stream<dynamic> get onCallConnected;
  Stream<dynamic> get onCallRejected;
  Stream<dynamic> get onCallEnded;
  Stream<dynamic> get onCallError;
  Stream<dynamic> get onWebRTCOffer;
  Stream<dynamic> get onWebRTCAnswer;
  Stream<dynamic> get onWebRTCIceCandidate;

  void sendWebRTCOffer(String callId, Map<String, dynamic> offer, String receiverId);
  void sendWebRTCAnswer(String callId, Map<String, dynamic> answer, String callerId);
  void sendWebRTCIceCandidate(String callId, Map<String, dynamic> candidate, String receiverId);

  void dispose();
}
