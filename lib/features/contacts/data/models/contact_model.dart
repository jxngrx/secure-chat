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

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['userId'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['username'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar'] as String?,
      phoneNumber: json['phone'] as String? ?? json['phoneNumber'] as String?,
      username: json['username'] as String?,
      isOnline: json['isOnline'] as bool? ?? false,
    );
  }
}
