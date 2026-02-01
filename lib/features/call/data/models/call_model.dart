import '../../domain/entities/call_entity.dart';

class CallModel {
  final String id;
  final String callerId;
  final String receiverId;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? duration;
  final DateTime createdAt;

  CallModel({
    required this.id,
    required this.callerId,
    required this.receiverId,
    required this.status,
    this.startedAt,
    this.endedAt,
    this.duration,
    required this.createdAt,
  });

  factory CallModel.fromJson(Map<String, dynamic> json) {
    return CallModel(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      callerId: json['callerId'] as String? ??
          (json['caller'] != null
              ? (json['caller'] as Map<String, dynamic>)['id'] as String?
              : null) ??
          '',
      receiverId: json['receiverId'] as String? ??
          (json['receiver'] != null
              ? (json['receiver'] as Map<String, dynamic>)['id'] as String?
              : null) ??
          '',
      status: json['status'] as String? ?? 'ringing',
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'] as String)
          : null,
      endedAt: json['endedAt'] != null
          ? DateTime.tryParse(json['endedAt'] as String)
          : null,
      duration: json['duration'] as int?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  CallEntity toEntity() {
    return CallEntity(
      id: id,
      callerId: callerId,
      receiverId: receiverId,
      status: status,
      startTime: startedAt ?? createdAt,
      endTime: endedAt,
      isVideo: false, // Defaulting to false as CallModel doesn't track it yet
    );
  }
}
