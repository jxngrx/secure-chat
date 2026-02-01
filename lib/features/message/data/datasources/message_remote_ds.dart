import '../../../../core/network/api_client.dart';
import '../../../../core/models/paginated_result.dart';

class MessageRemoteDataSource {
  MessageRemoteDataSource._();

  static final MessageRemoteDataSource instance = MessageRemoteDataSource._();

  final ApiClient _apiClient = ApiClient.instance;

  /// Send message via REST API
  Future<Map<String, dynamic>> sendMessage({
    required String chatId,
    required String type,
    required String content,
  }) async {
    final response = await _apiClient.post('/messages', {
      'chatId': chatId,
      'type': type,
      'content': content,
    });
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  /// Get chat messages with pagination
  Future<PaginatedResult<Map<String, dynamic>>> getChatMessages({
    required String chatId,
    int limit = 50,
    String? before,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
    };
    if (before != null) {
      queryParams['before'] = before;
    }

    final response = await _apiClient.get(
      '/messages/chat/$chatId',
      queryParameters: queryParams,
    );

    final data = response['data'] as Map<String, dynamic>? ?? {};
    final messages = (data['messages'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    final pagination = data['pagination'] as Map<String, dynamic>? ?? {};
    final hasMore = pagination['hasMore'] as bool? ?? false;
    final nextCursor = pagination['nextCursor'] as String?;

    return PaginatedResult(
      items: messages,
      hasMore: hasMore,
      nextCursor: nextCursor,
    );
  }

  /// Mark messages as read
  Future<void> markAsRead(String chatId) async {
    await _apiClient.put('/messages/$chatId/read', {});
  }

  /// Mark messages as delivered
  Future<void> markAsDelivered(String chatId) async {
    await _apiClient.put('/messages/$chatId/delivered', {});
  }

  /// Edit message
  Future<Map<String, dynamic>> editMessage({
    required String messageId,
    required String content,
  }) async {
    final response = await _apiClient.put('/messages/$messageId/edit', {
      'content': content,
    });
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  /// Delete message
  Future<void> deleteMessage({
    required String messageId,
    bool deleteForEveryone = false,
  }) async {
    await _apiClient.delete(
      '/messages/$messageId',
      queryParameters: {
        'deleteForEveryone': deleteForEveryone.toString(),
      },
    );
  }
}
