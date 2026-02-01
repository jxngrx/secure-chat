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
  ChatEntity copyWith({
    String? id,
    String? name,
    List<String>? participantIds,
    String? lastMessageId,
    DateTime? lastMessageTime,
    bool? isGroup,
    Map<String, dynamic>? lastMessage,
    int? unreadCount,
  }) {
    return ChatEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      participantIds: participantIds ?? this.participantIds,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      isGroup: isGroup ?? this.isGroup,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
