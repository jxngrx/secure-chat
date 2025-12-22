class CallItemModel {
  final String id;
  final String name;
  final String? avatarUrl;
  final DateTime timestamp;
  final CallType type;
  final CallDirection direction;
  final bool isVideo;
  final int? missedCount;

  CallItemModel({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.timestamp,
    required this.type,
    required this.direction,
    this.isVideo = false,
    this.missedCount,
  });
}

enum CallType {
  missed,
  incoming,
  outgoing,
}

enum CallDirection {
  incoming,
  outgoing,
}
