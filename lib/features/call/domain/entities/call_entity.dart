class CallEntity {
  final String id;
  final String callerId;
  final String? callerName;
  final String receiverId;
  final String? receiverName;
  final String status; // 'initiating', 'ringing', 'connected', 'ended', 'rejected'
  final DateTime startTime;
  final DateTime? endTime;
  final bool isVideo;

  const CallEntity({
    required this.id,
    required this.callerId,
    this.callerName,
    required this.receiverId,
    this.receiverName,
    required this.status,
    required this.startTime,
    this.endTime,
    this.isVideo = false, // Default to voice for now
  });

  DateTime get createdAt => startTime;

  factory CallEntity.fromJson(Map<String, dynamic> json) {
    // Handle nested caller object
    String cId = '';
    String? cName;
    if (json['caller'] is Map) {
      cId = json['caller']['id'] as String? ?? '';
      cName = json['caller']['username'] as String?;
    } else {
      cId = (json['callerId'] ?? json['caller']) as String? ?? '';
    }

    // Handle nested receiver object
    String rId = '';
    String? rName;
    if (json['receiver'] is Map) {
      rId = json['receiver']['id'] as String? ?? '';
      rName = json['receiver']['username'] as String?;
    } else {
      rId = (json['receiverId'] ?? json['receiver']) as String? ?? '';
    }

    return CallEntity(
      id: json['id'] as String? ?? '',
      callerId: cId,
      callerName: cName,
      receiverId: rId,
      receiverName: rName,
      status: json['status'] as String? ?? 'unknown',
      startTime: (json['startTime'] ?? json['startedAt'] ?? json['createdAt']) != null
          ? DateTime.parse((json['startTime'] ?? json['startedAt'] ?? json['createdAt']) as String)
          : DateTime.now(),
      endTime: json['endTime'] ?? json['endedAt'] != null
          ? DateTime.parse((json['endTime'] ?? json['endedAt']) as String)
          : null,
      isVideo: json['isVideo'] as bool? ?? false,
    );
  }
}
