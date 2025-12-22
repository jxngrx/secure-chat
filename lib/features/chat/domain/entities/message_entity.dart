class MessageEntity {
  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final DateTime timestamp;
  final String? type;
  final bool isEdited;
  final bool isDeleted;

  MessageEntity({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.timestamp,
    this.type,
    this.isEdited = false,
    this.isDeleted = false,
  });
}
