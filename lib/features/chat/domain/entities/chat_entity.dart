class ChatEntity {
  final String id;
  final String? name;
  final List<String> participantIds;
  final String? lastMessageId;
  final DateTime? lastMessageTime;
  final bool isGroup;

  ChatEntity({
    required this.id,
    this.name,
    required this.participantIds,
    this.lastMessageId,
    this.lastMessageTime,
    this.isGroup = false,
  });
}
