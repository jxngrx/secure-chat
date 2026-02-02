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
  final bool deleteForEveryone;
  final bool sentUserMessageIsDeleted;
  final bool receiveUserMessageIsDeleted;

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
    this.deleteForEveryone = false,
    this.sentUserMessageIsDeleted = false,
    this.receiveUserMessageIsDeleted = false,
  });

  MessageEntity copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    String? content,
    String? type,
    DateTime? timestamp,
    String? status,
    DateTime? editedAt,
    String? mediaUrl,
    String? mediaSize,
    int? voiceDuration,
    bool? deleteForEveryone,
    bool? sentUserMessageIsDeleted,
    bool? receiveUserMessageIsDeleted,
  }) {
    return MessageEntity(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      editedAt: editedAt ?? this.editedAt,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaSize: mediaSize ?? this.mediaSize,
      voiceDuration: voiceDuration ?? this.voiceDuration,
      deleteForEveryone: deleteForEveryone ?? this.deleteForEveryone,
      sentUserMessageIsDeleted: sentUserMessageIsDeleted ?? this.sentUserMessageIsDeleted,
      receiveUserMessageIsDeleted: receiveUserMessageIsDeleted ?? this.receiveUserMessageIsDeleted,
    );
  }
}
