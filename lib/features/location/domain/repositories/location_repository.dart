import '../entities/location_entity.dart';

abstract class LocationRepository {
  Future<LocationEntity> getLastKnownLocation();
  Future<LocationEntity> startLiveLocation({
    String? chatId,
    required double latitude,
    required double longitude,
    required double accuracy,
  });
  Future<void> updateLiveLocation({
    required String liveSessionId,
    required double latitude,
    required double longitude,
    required double accuracy,
  });
  Future<void> stopLiveLocation(String liveSessionId);
}
