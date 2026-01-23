class LocationEntity {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  final bool isLive;
  final String? liveSessionId;

  LocationEntity({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.isLive = false,
    this.liveSessionId,
  });
}
