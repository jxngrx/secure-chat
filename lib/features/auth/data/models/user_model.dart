import '../../domain/entities/user_entity.dart';

class UserModel {
  const UserModel({
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

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] ?? json['_id'] ?? '') as String,
      phone: (json['phone'] ?? json['phoneNumber'] ?? '') as String,
      username: json['username'] as String?,
      email: json['email'] as String?,
      authMethod: json['authMethod'] as String?,
      isOnline: json['isOnline'] as bool?,
      lastSeen: _tryParseDate(json['lastSeen']),
      createdAt: _tryParseDate(json['createdAt']),
      updatedAt: _tryParseDate(json['updatedAt']),
    );
  }

  static DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
