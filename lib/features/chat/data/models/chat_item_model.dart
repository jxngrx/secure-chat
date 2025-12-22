class ChatItemModel {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isOnline;
  final bool isGroup;
  final bool isMuted;
  final bool isVerified;
  final String? lastMessageSender; // For group chats
  final MessageType? lastMessageType;

  ChatItemModel({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
    this.isGroup = false,
    this.isMuted = false,
    this.isVerified = false,
    this.lastMessageSender,
    this.lastMessageType,
  });
}

enum MessageType {
  text,
  image,
  voice,
  video,
  file,
  missedCall,
}
