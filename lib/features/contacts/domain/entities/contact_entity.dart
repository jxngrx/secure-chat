class ContactEntity {
  final String userId;
  final String phone;
  final String? username;
  final bool isOnline;
  final DateTime? lastSeen;

  ContactEntity({
    required this.userId,
    required this.phone,
    this.username,
    this.isOnline = false,
    this.lastSeen,
  });
}
