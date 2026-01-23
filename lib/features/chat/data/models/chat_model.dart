class ChatModel {
  final String id;
  final String? name;
  final List<String> participantIds;
  final String? lastMessageId;
  final DateTime? lastMessageTime;
  final bool isGroup;

  ChatModel({
    required this.id,
    this.name,
    required this.participantIds,
    this.lastMessageId,
    this.lastMessageTime,
    this.isGroup = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'participantIds': participantIds,
      'lastMessageId': lastMessageId,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'isGroup': isGroup,
    };
  }

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    // Handle backend response format
    final chatId = json['chatId'] as String? ?? json['id'] as String? ?? '';
    List<String> participantIds = [];

    if (json['participants'] != null) {
      final participants = json['participants'] as List<dynamic>;
      participantIds = participants
          .map((p) => (p as Map<String, dynamic>)['id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } else if (json['participantIds'] != null) {
      participantIds = List<String>.from(json['participantIds'] as List);
    }

    // Get name from otherParticipant if available
    String? name = json['name'] as String?;
    if (name == null && json['otherParticipant'] != null) {
      final other = json['otherParticipant'] as Map<String, dynamic>;
      name = other['username'] as String? ?? other['name'] as String?;
    }

    return ChatModel(
      id: chatId,
      name: name,
      participantIds: participantIds,
      lastMessageId: json['lastMessageId'] as String? ??
          (json['lastMessage'] != null
              ? (json['lastMessage'] as Map<String, dynamic>)['id'] as String?
              : null),
      lastMessageTime: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'] as String)
          : json['lastMessageTime'] != null
              ? DateTime.tryParse(json['lastMessageTime'] as String)
              : null,
      isGroup: json['isGroup'] as bool? ?? false,
    );
  }
}
