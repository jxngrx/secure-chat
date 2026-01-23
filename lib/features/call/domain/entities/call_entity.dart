class CallEntity {
  final String id;
  final String callerId;
  final String receiverId;
  final String status; // 'ringing', 'answered', 'rejected', 'ended'
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? duration; // in seconds
  final DateTime createdAt;

  CallEntity({
    required this.id,
    required this.callerId,
    required this.receiverId,
    required this.status,
    this.startedAt,
    this.endedAt,
    this.duration,
    required this.createdAt,
  });
}
