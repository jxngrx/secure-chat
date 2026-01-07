class UserEntity {
  const UserEntity({
    required this.id,
    required this.phone,
    this.username,
    this.email,
    this.authMethod,
    this.isOnline,
    this.lastSeen,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String phone;
  final String? username;
  final String? email;
  final String? authMethod;
  final bool? isOnline;
  final DateTime? lastSeen;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
