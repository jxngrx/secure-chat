class ContactModel {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? phoneNumber;
  final String? username;
  final bool isOnline;

  ContactModel({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.phoneNumber,
    this.username,
    this.isOnline = false,
  });
}
