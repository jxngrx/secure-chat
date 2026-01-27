import '../../domain/entities/user_entity.dart';

class UserModel {
  final String id;
  final String phone;
  final String? username;
  final String? email;
  final String? authMethod;
  final bool? isOnline;
  final DateTime? lastSeen;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
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

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      username: json['username'] as String?,
      email: json['email'] as String?,
      authMethod: json['authMethod'] as String?,
      isOnline: json['isOnline'] as bool?,
      lastSeen: json['lastSeen'] != null
          ? DateTime.tryParse(json['lastSeen'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'username': username,
      'email': email,
      'authMethod': authMethod,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  UserEntity toEntity() {
    return UserEntity(
      id: id,
      phone: phone,
      username: username,
      email: email,
      authMethod: authMethod,
      isOnline: isOnline,
      lastSeen: lastSeen,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
