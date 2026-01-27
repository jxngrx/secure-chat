class ChatModel {
  final String id;
  final String? name;
  final List<String> participantIds;
  final String? lastMessageId;
  final DateTime? lastMessageTime;
  final bool isGroup;
  final Map<String, dynamic>? lastMessage; // Full last message object
  final int? unreadCount; // Unread message count from backend

  ChatModel({
    required this.id,
    this.name,
    required this.participantIds,
    this.lastMessageId,
    this.lastMessageTime,
    this.isGroup = false,
    this.lastMessage,
    this.unreadCount,
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

    // Extract lastMessage object (can be a string ID or an object)
    Map<String, dynamic>? lastMessageObj;
    String? lastMessageIdFromField;
    
    if (json['lastMessage'] != null) {
      if (json['lastMessage'] is String) {
        // If lastMessage is a string, it's just the ID
        lastMessageIdFromField = json['lastMessage'] as String;
      } else if (json['lastMessage'] is Map<String, dynamic>) {
        // If lastMessage is an object, extract it
        lastMessageObj = json['lastMessage'] as Map<String, dynamic>;
        lastMessageIdFromField = lastMessageObj['id'] as String?;
      }
    }

    // Extract unreadCount if available
    int? unreadCount;
    if (json['unreadCount'] != null) {
      unreadCount = json['unreadCount'] as int?;
    }

    return ChatModel(
      id: chatId,
      name: name,
      participantIds: participantIds,
      lastMessageId: json['lastMessageId'] as String? ?? lastMessageIdFromField,
      lastMessageTime: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'] as String)
          : json['lastMessageTime'] != null
              ? DateTime.tryParse(json['lastMessageTime'] as String)
              : null,
      isGroup: json['isGroup'] as bool? ?? false,
      lastMessage: lastMessageObj,
      unreadCount: unreadCount,
    );
  }
}
