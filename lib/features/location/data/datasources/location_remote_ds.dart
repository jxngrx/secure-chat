import '../../../../core/network/api_client.dart';

class LocationRemoteDataSource {
  LocationRemoteDataSource._();

  static final LocationRemoteDataSource instance = LocationRemoteDataSource._();

  final ApiClient _apiClient = ApiClient.instance;

  /// Get last known location
  Future<Map<String, dynamic>> getLastKnownLocation() async {
    final response = await _apiClient.get('/location/last-known');
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  /// Start live location sharing
  Future<Map<String, dynamic>> startLiveLocation({
    String? chatId,
    required double latitude,
    required double longitude,
    required double accuracy,
  }) async {
    final payload = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
    };
    if (chatId != null) {
      payload['chatId'] = chatId;
    }

    final response = await _apiClient.post('/location/live/start', payload);
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  /// Update live location
  Future<void> updateLiveLocation({
    required String liveSessionId,
    required double latitude,
    required double longitude,
    required double accuracy,
  }) async {
    await _apiClient.post('/location/live/$liveSessionId/update', {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
    });
  }

  /// Stop live location
  Future<void> stopLiveLocation(String liveSessionId) async {
    await _apiClient.post('/location/live/$liveSessionId/stop', {});
  }
}
