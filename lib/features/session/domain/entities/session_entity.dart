class SessionEntity {
  const SessionEntity({
    required this.sessionId,
    required this.deviceId,
    required this.loginMethod,
    required this.isActive,
    this.expiresAt,
  });

  final String sessionId;
  final String deviceId;
  final String loginMethod;
  final bool isActive;
  final DateTime? expiresAt;
}
