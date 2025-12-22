import '../config/env.dart';

class SocketClient {
  SocketClient._();

  static final SocketClient instance = SocketClient._();

  String get wsUrl => Env.wsUrl;

  // TODO: Implement WebSocket/Socket.IO client
  void connect() {
    // Placeholder implementation
  }

  void disconnect() {
    // Placeholder implementation
  }

  void emit(String event, dynamic data) {
    // Placeholder implementation
  }

  void on(String event, Function(dynamic) callback) {
    // Placeholder implementation
  }
}
