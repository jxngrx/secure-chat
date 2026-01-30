import 'chat_item_model.dart';

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String? senderName;
  final String? senderAvatar;
  final String? content;
  final MessageType type;
  final DateTime timestamp;
  final bool isSent;
  final bool isRead;
  final String? mediaUrl;
  final String? mediaSize; // For images/files
  final int? voiceDuration; // For voice messages in seconds
  final bool deleteForEveryone;
  final bool sentUserMessageIsDeleted;
  final bool receiveUserMessageIsDeleted;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.senderName,
    this.senderAvatar,
    this.content,
    required this.type,
    required this.timestamp,
    this.isSent = true,
    this.isRead = false,
    this.mediaUrl,
    this.mediaSize,
    this.voiceDuration,
    this.deleteForEveryone = false,
    this.sentUserMessageIsDeleted = false,
    this.receiveUserMessageIsDeleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'content': content,
      'type': type.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
      'isSent': isSent,
      'isRead': isRead,
      'mediaUrl': mediaUrl,
      'mediaSize': mediaSize,
      'voiceDuration': voiceDuration,
      'deleteForEveryone': deleteForEveryone,
      'sentUserMessageIsDeleted': sentUserMessageIsDeleted,
      'receiveUserMessageIsDeleted': receiveUserMessageIsDeleted,
    };
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    MessageType messageType = MessageType.text;
    if (json['type'] != null) {
      final typeStr = json['type'].toString().toLowerCase();
      switch (typeStr) {
        case 'text':
          messageType = MessageType.text;
          break;
        case 'image':
          messageType = MessageType.image;
          break;
        case 'video':
          messageType = MessageType.video;
          break;
        case 'voice':
          messageType = MessageType.voice;
          break;
        case 'file':
          messageType = MessageType.file;
          break;
        case 'missedcall':
        case 'missed_call':
          messageType = MessageType.missedCall;
          break;
      }
    }

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
      type: messageType,
      timestamp: json['timestamp'] != null || json['createdAt'] != null
          ? DateTime.tryParse(
                  json['timestamp'] as String? ?? json['createdAt'] as String? ?? '') ??
              DateTime.now()
          : DateTime.now(),
      isSent: json['isSent'] as bool? ?? true,
      isRead: json['isRead'] as bool? ??
          (json['status'] != null && json['status'] == 'read'),
      mediaUrl: json['mediaUrl'] as String?,
      mediaSize: json['mediaSize'] as String?,
      voiceDuration: json['voiceDuration'] as int?,
      deleteForEveryone: json['deleteForEveryone'] as bool? ?? false,
      sentUserMessageIsDeleted: json['sentUserMessageIsDeleted'] as bool? ?? false,
      receiveUserMessageIsDeleted:
          json['receiveUserMessageIsDeleted'] as bool? ?? false,
    );
  }
}
