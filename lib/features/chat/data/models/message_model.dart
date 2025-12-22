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
  });
}
