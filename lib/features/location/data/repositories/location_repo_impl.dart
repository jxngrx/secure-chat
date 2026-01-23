import '../../domain/repositories/location_repository.dart';
import '../../domain/entities/location_entity.dart';
import '../datasources/location_remote_ds.dart';

class LocationRepositoryImpl implements LocationRepository {
  LocationRepositoryImpl._();

  static final LocationRepositoryImpl instance = LocationRepositoryImpl._();

  final LocationRemoteDataSource _remoteDataSource = LocationRemoteDataSource.instance;

  @override
  Future<LocationEntity> getLastKnownLocation() async {
    final response = await _remoteDataSource.getLastKnownLocation();
    return LocationEntity(
      latitude: (response['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (response['longitude'] as num?)?.toDouble() ?? 0.0,
      accuracy: (response['accuracy'] as num?)?.toDouble() ?? 0.0,
      timestamp: response['timestamp'] != null
          ? DateTime.tryParse(response['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      isLive: response['isLive'] as bool? ?? false,
    );
  }

  @override
  Future<LocationEntity> startLiveLocation({
    String? chatId,
    required double latitude,
    required double longitude,
    required double accuracy,
  }) async {
    final response = await _remoteDataSource.startLiveLocation(
      chatId: chatId,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
    );
    return LocationEntity(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      timestamp: response['timestamp'] != null
          ? DateTime.tryParse(response['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      isLive: true,
      liveSessionId: response['liveSessionId'] as String?,
    );
  }

  @override
  Future<void> updateLiveLocation({
    required String liveSessionId,
    required double latitude,
    required double longitude,
    required double accuracy,
  }) async {
    await _remoteDataSource.updateLiveLocation(
      liveSessionId: liveSessionId,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
    );
  }

  @override
  Future<void> stopLiveLocation(String liveSessionId) async {
    await _remoteDataSource.stopLiveLocation(liveSessionId);
  }
}
