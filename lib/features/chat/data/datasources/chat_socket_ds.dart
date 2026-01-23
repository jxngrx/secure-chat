import '../../../../core/network/socket_client.dart';

class ChatSocketDataSource {
  ChatSocketDataSource._();

  static final ChatSocketDataSource instance = ChatSocketDataSource._();

  final SocketClient _socketClient = SocketClient.instance;

  /// Connect socket
  Future<void> connect() async {
    await _socketClient.connect();
  }

  /// Disconnect socket
  void disconnect() {
    _socketClient.disconnect();
  }

  /// Send message via Socket.IO
  void sendMessage({
    required String chatId,
    required String type,
    required String content,
  }) {
    _socketClient.emit('message:send', {
      'chatId': chatId,
      'type': type,
      'content': content,
    });
  }

  /// Mark messages as read via Socket.IO
  void markAsRead(String chatId) {
    _socketClient.emit('message:read', {
      'chatId': chatId,
    });
  }

  /// Mark messages as delivered via Socket.IO
  void markAsDelivered(String chatId) {
    _socketClient.emit('message:delivered', {
      'chatId': chatId,
    });
  }

  /// Join chat room
  void joinChat(String chatId) {
    _socketClient.emit('chat:join', {
      'chatId': chatId,
    });
  }

  /// Leave chat room
  void leaveChat(String chatId) {
    _socketClient.emit('chat:leave', {
      'chatId': chatId,
    });
  }

  /// Listen to new message event
  void onNewMessage(Function(dynamic) callback) {
    _socketClient.on('message:new', callback);
  }

  /// Listen to message sent confirmation
  void onMessageSent(Function(dynamic) callback) {
    _socketClient.on('message:sent', callback);
  }

  /// Listen to message read receipt
  void onMessageRead(Function(dynamic) callback) {
    _socketClient.on('message:read', callback);
  }

  /// Listen to message delivered receipt
  void onMessageDelivered(Function(dynamic) callback) {
    _socketClient.on('message:delivered', callback);
  }

  /// Listen to chat updated event
  void onChatUpdated(Function(dynamic) callback) {
    _socketClient.on('chat:updated', callback);
  }

  /// Remove all listeners
  void removeAllListeners() {
    _socketClient.off('message:new');
    _socketClient.off('message:sent');
    _socketClient.off('message:read');
    _socketClient.off('message:delivered');
    _socketClient.off('chat:updated');
  }
}
