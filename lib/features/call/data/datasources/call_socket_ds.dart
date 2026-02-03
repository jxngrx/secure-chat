import '../../../../core/network/socket_client.dart';

class CallSocketDataSource {
  CallSocketDataSource._();

  static final CallSocketDataSource instance = CallSocketDataSource._();

  final SocketClient _socketClient = SocketClient.instance;

  // --- Listeners ---

  void onIncomingCall(Function(dynamic) callback) {
    _socketClient.on('call:incoming', callback);
  }

  void onCallInitiated(Function(dynamic) callback) {
    _socketClient.on('call:initiated', callback);
  }

  void onCallAnswered(Function(dynamic) callback) {
    _socketClient.on('call:answered', callback);
  }

  void onCallConnected(Function(dynamic) callback) {
    _socketClient.on('call:connected', callback);
  }

  void onCallRejected(Function(dynamic) callback) {
    _socketClient.on('call:rejected', callback);
  }

  void onCallEnded(Function(dynamic) callback) {
    _socketClient.on('call:ended', callback);
  }

  void onCallError(Function(dynamic) callback) {
    _socketClient.on('call:error', callback);
  }

  // WebRTC Signaling Listeners
  void onWebRTCOffer(Function(dynamic) callback) {
    _socketClient.on('call:webrtc-offer', callback);
  }

  void onWebRTCAnswer(Function(dynamic) callback) {
    _socketClient.on('call:webrtc-answer', callback);
  }

  void onWebRTCIceCandidate(Function(dynamic) callback) {
    _socketClient.on('call:webrtc-ice-candidate', callback);
  }

  // --- Emitters ---

  void initiateCall(String receiverId) {
    _socketClient.emit('call:initiate', {
      'receiverId': receiverId,
    });
  }

  void answerCall(String callId) {
    _socketClient.emit('call:answer', {
      'callId': callId,
    });
  }

  void rejectCall(String callId) {
    _socketClient.emit('call:reject', {
      'callId': callId,
    });
  }

  void endCall(String callId) {
    _socketClient.emit('call:end', {
      'callId': callId,
    });
  }

  void sendWebRTCOffer(String callId, Map<String, dynamic> offer, String receiverId) {
    _socketClient.emit('call:webrtc-offer', {
      'callId': callId,
      'offer': offer,
      'receiverId': receiverId,
    });
  }

  void sendWebRTCAnswer(String callId, Map<String, dynamic> answer, String callerId) {
    _socketClient.emit('call:webrtc-answer', {
      'callId': callId,
      'answer': answer,
      'callerId': callerId,
    });
  }

  void sendWebRTCIceCandidate(String callId, Map<String, dynamic> candidate, String receiverId) {
    _socketClient.emit('call:webrtc-ice-candidate', {
      'callId': callId,
      'candidate': candidate,
      'receiverId': receiverId,
    });
  }

  // Clean up listeners
  void dispose() {
    _socketClient.off('call:incoming');
    _socketClient.off('call:initiated');
    _socketClient.off('call:answered');
    _socketClient.off('call:connected');
    _socketClient.off('call:rejected');
    _socketClient.off('call:ended');
    _socketClient.off('call:error');
    _socketClient.off('call:webrtc-offer');
    _socketClient.off('call:webrtc-answer');
    _socketClient.off('call:webrtc-ice-candidate');
  }
}
