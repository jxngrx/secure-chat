import '../../../../core/network/socket_client.dart';

class CallSocketDataSource {
  CallSocketDataSource._();

  static final CallSocketDataSource instance = CallSocketDataSource._();

  final SocketClient _socketClient = SocketClient.instance;

  // TODO: Implement call socket data source methods
  void connect() {
    _socketClient.connect();
  }

  void disconnect() {
    _socketClient.disconnect();
  }

  void startCall(String recipientId) {
    _socketClient.emit('start_call', {'recipientId': recipientId});
  }

  void endCall(String callId) {
    _socketClient.emit('end_call', {'callId': callId});
  }

  void onIncomingCall(Function(dynamic) callback) {
    _socketClient.on('incoming_call', callback);
  }
}
