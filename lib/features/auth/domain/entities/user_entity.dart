class UserEntity {
  final String id;
  final String phoneNumber;
  final String? username;
  final String? displayName;
  final String? avatarUrl;

  UserEntity({
    required this.id,
    required this.phoneNumber,
    this.username,
    this.displayName,
    this.avatarUrl,
  });
}
