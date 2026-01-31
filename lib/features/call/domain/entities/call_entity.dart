class CallEntity {
  final String id;
  final String callerId;
  final String receiverId;
  final String status; // 'initiating', 'ringing', 'connected', 'ended', 'rejected'
  final DateTime startTime;
  final DateTime? endTime;
  final bool isVideo;

  const CallEntity({
    required this.id,
    required this.callerId,
    required this.receiverId,
    required this.status,
    required this.startTime,
    this.endTime,
    this.isVideo = false, // Default to voice for now
  });

  DateTime get createdAt => startTime;

  factory CallEntity.fromJson(Map<String, dynamic> json) {
    return CallEntity(
      id: json['id'] as String? ?? '',
      callerId: json['callerId'] as String? ?? '',
      receiverId: json['receiverId'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'] as String)
          : DateTime.now(),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      isVideo: json['isVideo'] as bool? ?? false,
    );
  }
}
