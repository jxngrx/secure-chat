import '../../../../core/network/api_client.dart';

class ChatRemoteDataSource {
  ChatRemoteDataSource._();

  static final ChatRemoteDataSource instance = ChatRemoteDataSource._();

  final ApiClient _apiClient = ApiClient.instance;

  /// Get all user chats
  Future<List<Map<String, dynamic>>> getChats() async {
    final response = await _apiClient.get('/chats');
    final chats = response['data']?['chats'] as List<dynamic>? ?? [];
    return chats.cast<Map<String, dynamic>>();
  }

  /// Get chat by ID
  Future<Map<String, dynamic>> getChatById(String chatId) async {
    final response = await _apiClient.get('/chats/$chatId');
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  /// Create or get chat with another user
  Future<Map<String, dynamic>> createOrGetChat(String otherUserId) async {
    final response = await _apiClient.post('/chats', {
      'otherUserId': otherUserId,
    });
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  /// Get messages (for backward compatibility)
  Future<List<Map<String, dynamic>>> getMessages(String chatId) async {
    final response = await _apiClient.get('/messages/chat/$chatId', queryParameters: {'limit': 50});
    final messages = response['data']?['messages'] as List<dynamic>? ?? [];
    return messages.cast<Map<String, dynamic>>();
  }

  /// Send message (for backward compatibility)
  Future<Map<String, dynamic>> sendMessage(String chatId, String content) async {
    final response = await _apiClient.post('/messages', {
      'chatId': chatId,
      'type': 'text',
      'content': content,
    });
    return response['data'] as Map<String, dynamic>? ?? {};
  }
}
