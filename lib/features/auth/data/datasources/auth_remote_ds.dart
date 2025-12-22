import '../../../../core/network/api_client.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource._();

  static final AuthRemoteDataSource instance = AuthRemoteDataSource._();

  final ApiClient _apiClient = ApiClient.instance;

  // TODO: Implement authentication remote data source methods
  Future<Map<String, dynamic>> sendOtp(String phoneNumber) async {
    // Placeholder implementation
    throw UnimplementedError('AuthRemoteDataSource.sendOtp not implemented');
  }

  Future<Map<String, dynamic>> verifyOtp(String phoneNumber, String otp) async {
    // Placeholder implementation
    throw UnimplementedError('AuthRemoteDataSource.verifyOtp not implemented');
  }

  Future<Map<String, dynamic>> setUsername(String username) async {
    // Placeholder implementation
    throw UnimplementedError('AuthRemoteDataSource.setUsername not implemented');
  }
}
