import '../../domain/entities/session_entity.dart';

class SessionModel {
  final String sessionId;
  final String deviceId;
  final String loginMethod;
  final bool isActive;
  final DateTime? expiresAt;

  SessionModel({
    required this.sessionId,
    required this.deviceId,
    required this.loginMethod,
    required this.isActive,
    this.expiresAt,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      sessionId: json['sessionId'] as String? ?? json['id'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? '',
      loginMethod: json['loginMethod'] as String? ?? 'phone',
      isActive: json['isActive'] as bool? ?? true,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
    );
  }

  SessionEntity toEntity() {
    return SessionEntity(
      sessionId: sessionId,
      deviceId: deviceId,
      loginMethod: loginMethod,
      isActive: isActive,
      expiresAt: expiresAt,
    );
  }
}
