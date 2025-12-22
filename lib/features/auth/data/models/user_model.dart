class UserModel {
  final String id;
  final String phoneNumber;
  final String? username;
  final String? displayName;
  final String? avatarUrl;

  UserModel({
    required this.id,
    required this.phoneNumber,
    this.username,
    this.displayName,
    this.avatarUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'username': username,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      phoneNumber: json['phoneNumber'] as String,
      username: json['username'] as String?,
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}
