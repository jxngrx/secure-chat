import '../../domain/entities/message_entity.dart';

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String? senderName;
  final String? senderAvatar;
  final String? content;
  final String type;
  final DateTime timestamp;
  final String status;
  final DateTime? editedAt;
  final String? mediaUrl;
  final String? mediaSize;
  final int? voiceDuration;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.senderName,
    this.senderAvatar,
    this.content,
    required this.type,
    required this.timestamp,
    this.status = 'sent',
    this.editedAt,
    this.mediaUrl,
    this.mediaSize,
    this.voiceDuration,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      chatId: json['chatId'] as String? ?? '',
      senderId: json['senderId'] as String? ??
          (json['sender'] != null
              ? (json['sender'] as Map<String, dynamic>)['id'] as String?
              : null) ??
          '',
      senderName: json['senderName'] as String? ??
          (json['sender'] != null
              ? (json['sender'] as Map<String, dynamic>)['username'] as String?
              : null),
      senderAvatar: json['senderAvatar'] as String? ??
          (json['sender'] != null
              ? (json['sender'] as Map<String, dynamic>)['avatar'] as String?
              : null),
      content: json['content'] as String?,
      type: json['type'] as String? ?? 'text',
      timestamp: json['timestamp'] != null || json['createdAt'] != null
          ? DateTime.tryParse(
                  json['timestamp'] as String? ?? json['createdAt'] as String? ?? '') ??
              DateTime.now()
          : DateTime.now(),
      status: json['status'] as String? ?? 'sent',
      editedAt: json['editedAt'] != null
          ? DateTime.tryParse(json['editedAt'] as String)
          : null,
      mediaUrl: json['mediaUrl'] as String?,
      mediaSize: json['mediaSize'] as String?,
      voiceDuration: json['voiceDuration'] as int?,
    );
  }

  MessageEntity toEntity({bool isDeleted = false}) {
    return MessageEntity(
      id: id,
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      content: content,
      type: type,
      timestamp: timestamp,
      status: status,
      editedAt: editedAt,
      mediaUrl: mediaUrl,
      mediaSize: mediaSize,
      voiceDuration: voiceDuration,
      isDeleted: isDeleted,
    );
  }
}
