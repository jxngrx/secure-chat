import '../../../../core/network/api_client.dart';

class ChatRemoteDataSource {
  ChatRemoteDataSource._();

  static final ChatRemoteDataSource instance = ChatRemoteDataSource._();

  final ApiClient _apiClient = ApiClient.instance;

  // TODO: Implement chat remote data source methods
  Future<List<Map<String, dynamic>>> getChats() async {
    throw UnimplementedError('ChatRemoteDataSource.getChats not implemented');
  }

  Future<List<Map<String, dynamic>>> getMessages(String chatId) async {
    throw UnimplementedError('ChatRemoteDataSource.getMessages not implemented');
  }

  Future<Map<String, dynamic>> sendMessage(
    String chatId,
    String content,
  ) async {
    throw UnimplementedError('ChatRemoteDataSource.sendMessage not implemented');
  }
}
