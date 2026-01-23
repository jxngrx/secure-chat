class MessageEntity {
  final String id;
  final String chatId;
  final String senderId;
  final String? senderName;
  final String? senderAvatar;
  final String? content;
  final String type; // 'text', 'image', 'video', 'voice', 'file', 'missedCall'
  final DateTime timestamp;
  final String status; // 'sent', 'delivered', 'read'
  final DateTime? editedAt;
  final String? mediaUrl;
  final String? mediaSize;
  final int? voiceDuration;

  MessageEntity({
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
}
