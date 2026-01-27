import '../../../../core/network/api_client.dart';

class UserRemoteDataSource {
  UserRemoteDataSource._();

  static final UserRemoteDataSource instance = UserRemoteDataSource._();

  final ApiClient _apiClient = ApiClient.instance;

  /// Get user profile
  Future<Map<String, dynamic>> getProfile() async {
    final response = await _apiClient.get('/users/profile');
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  /// Search users
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final response = await _apiClient.get(
      '/users/search',
      queryParameters: {'q': query},
    );
    // API returns { success: true, data: { users: [...] } }
    final data = response['data'] as Map<String, dynamic>? ?? {};
    final users = data['users'] as List<dynamic>? ?? [];
    return users.cast<Map<String, dynamic>>();
  }

  /// Get user by ID
  Future<Map<String, dynamic>> getUserById(String userId) async {
    final response = await _apiClient.get('/users/$userId');
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  /// Check if username is available
  Future<bool> checkUsernameAvailability(String username) async {
    final response = await _apiClient.get(
      '/users/username/check',
      queryParameters: {'username': username},
    );
    final data = response['data'] as Map<String, dynamic>? ?? {};
    return data['available'] as bool? ?? false;
  }
}
