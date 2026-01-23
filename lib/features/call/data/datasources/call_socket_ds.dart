import '../../../../core/network/socket_client.dart';

class CallSocketDataSource {
  CallSocketDataSource._();

  static final CallSocketDataSource instance = CallSocketDataSource._();

  final SocketClient _socketClient = SocketClient.instance;

  /// Connect socket
  Future<void> connect() async {
    await _socketClient.connect();
  }

  /// Disconnect socket
  void disconnect() {
    _socketClient.disconnect();
  }

  /// Initiate call via Socket.IO
  void initiateCall(String receiverId) {
    _socketClient.emit('call:initiate', {
      'receiverId': receiverId,
    });
  }

  /// Answer call via Socket.IO
  void answerCall(String callId) {
    _socketClient.emit('call:answer', {
      'callId': callId,
    });
  }

  /// Reject call via Socket.IO
  void rejectCall(String callId) {
    _socketClient.emit('call:reject', {
      'callId': callId,
    });
  }

  /// End call via Socket.IO
  void endCall(String callId) {
    _socketClient.emit('call:end', {
      'callId': callId,
    });
  }

  /// Send WebRTC offer
  void sendWebRTCOffer({
    required String callId,
    required Map<String, dynamic> offer,
    required String receiverId,
  }) {
    _socketClient.emit('call:webrtc-offer', {
      'callId': callId,
      'offer': offer,
      'receiverId': receiverId,
    });
  }

  /// Send WebRTC answer
  void sendWebRTCAnswer({
    required String callId,
    required Map<String, dynamic> answer,
    required String callerId,
  }) {
    _socketClient.emit('call:webrtc-answer', {
      'callId': callId,
      'answer': answer,
      'callerId': callerId,
    });
  }

  /// Send WebRTC ICE candidate
  void sendWebRTCIceCandidate({
    required String callId,
    required Map<String, dynamic> candidate,
    required String receiverId,
  }) {
    _socketClient.emit('call:webrtc-ice-candidate', {
      'callId': callId,
      'candidate': candidate,
      'receiverId': receiverId,
    });
  }

  /// Listen to incoming call
  void onIncomingCall(Function(dynamic) callback) {
    _socketClient.on('call:incoming', callback);
  }

  /// Listen to call initiated
  void onCallInitiated(Function(dynamic) callback) {
    _socketClient.on('call:initiated', callback);
  }

  /// Listen to call answered
  void onCallAnswered(Function(dynamic) callback) {
    _socketClient.on('call:answered', callback);
  }

  /// Listen to call connected
  void onCallConnected(Function(dynamic) callback) {
    _socketClient.on('call:connected', callback);
  }

  /// Listen to call rejected
  void onCallRejected(Function(dynamic) callback) {
    _socketClient.on('call:rejected', callback);
  }

  /// Listen to call ended
  void onCallEnded(Function(dynamic) callback) {
    _socketClient.on('call:ended', callback);
  }

  /// Listen to WebRTC offer
  void onWebRTCOffer(Function(dynamic) callback) {
    _socketClient.on('call:webrtc-offer', callback);
  }

  /// Listen to WebRTC answer
  void onWebRTCAnswer(Function(dynamic) callback) {
    _socketClient.on('call:webrtc-answer', callback);
  }

  /// Listen to WebRTC ICE candidate
  void onWebRTCIceCandidate(Function(dynamic) callback) {
    _socketClient.on('call:webrtc-ice-candidate', callback);
  }

  /// Listen to call error
  void onCallError(Function(dynamic) callback) {
    _socketClient.on('call:error', callback);
  }

  /// Listen to user online
  void onUserOnline(Function(dynamic) callback) {
    _socketClient.on('user:online', callback);
  }

  /// Listen to user offline
  void onUserOffline(Function(dynamic) callback) {
    _socketClient.on('user:offline', callback);
  }

  /// Listen to general error
  void onError(Function(dynamic) callback) {
    _socketClient.on('error', callback);
  }

  /// Remove all listeners
  void removeAllListeners() {
    _socketClient.off('call:incoming');
    _socketClient.off('call:initiated');
    _socketClient.off('call:answered');
    _socketClient.off('call:connected');
    _socketClient.off('call:rejected');
    _socketClient.off('call:ended');
    _socketClient.off('call:webrtc-offer');
    _socketClient.off('call:webrtc-answer');
    _socketClient.off('call:webrtc-ice-candidate');
    _socketClient.off('call:error');
    _socketClient.off('user:online');
    _socketClient.off('user:offline');
    _socketClient.off('error');
  }
}
