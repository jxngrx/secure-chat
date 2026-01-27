class ChatEntity {
  final String id;
  final String? name;
  final List<String> participantIds;
  final String? lastMessageId;
  final DateTime? lastMessageTime;
  final bool isGroup;
  final Map<String, dynamic>? lastMessage; // Full last message object
  final int? unreadCount; // Unread message count

  ChatEntity({
    required this.id,
    this.name,
    required this.participantIds,
    this.lastMessageId,
    this.lastMessageTime,
    this.isGroup = false,
    this.lastMessage,
    this.unreadCount,
  });
}
