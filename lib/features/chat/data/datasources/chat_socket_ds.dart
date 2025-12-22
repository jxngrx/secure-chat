import '../../../../core/network/socket_client.dart';

class ChatSocketDataSource {
  ChatSocketDataSource._();

  static final ChatSocketDataSource instance = ChatSocketDataSource._();

  final SocketClient _socketClient = SocketClient.instance;

  // TODO: Implement chat socket data source methods
  void connect() {
    _socketClient.connect();
  }

  void disconnect() {
    _socketClient.disconnect();
  }

  void onMessageReceived(Function(dynamic) callback) {
    _socketClient.on('message', callback);
  }

  void sendMessage(String chatId, String content) {
    _socketClient.emit('send_message', {
      'chatId': chatId,
      'content': content,
    });
  }
}
