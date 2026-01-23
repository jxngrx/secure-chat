import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_utils.dart' as AppDateUtils;
import '../../data/models/chat_item_model.dart';
import '../../data/models/message_model.dart';
import '../notifiers/chat_controller.dart';
import '../../../message/presentation/notifiers/message_controller.dart';
import '../../../message/domain/entities/message_entity.dart';
import '../../../../di/providers.dart';

class _MessageListItem {
  final bool isDateSeparator;
  final int messageIndex;

  _MessageListItem({
    required this.isDateSeparator,
    required this.messageIndex,
  });
}

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String? chatName;
  final String? chatAvatar;
  final bool? isOnline;

  const ChatScreen({
    super.key,
    required this.chatId,
    this.chatName,
    this.chatAvatar,
    this.isOnline,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Load messages when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(messageControllerProvider.notifier).loadMessages(widget.chatId);
      ref.read(chatControllerProvider.notifier).joinChat(widget.chatId);
    });
    // Listen to text changes to update mic/send icon
    _messageController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    ref.read(chatControllerProvider.notifier).leaveChat(widget.chatId);
    super.dispose();
  }

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final messageController = ref.read(messageControllerProvider.notifier);
    await messageController.sendMessage(
      chatId: widget.chatId,
      type: 'text',
      content: text,
      useSocket: true, // Use Socket.IO for real-time
    );

    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

    // Watch message state
    final messageState = ref.watch(messageControllerProvider);
    final messages = messageState.messages[widget.chatId] ?? [];
    final hasMessages = messages.isNotEmpty;
    final isSending = messageState.sending[widget.chatId] ?? false;

    final chatName = widget.chatName ?? 'Chat';
    final chatAvatar = widget.chatAvatar;
    final isOnline = widget.isOnline ?? false;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(isDark, chatName, chatAvatar, isOnline),

            // Messages or Empty State
            Expanded(
              child: hasMessages
                  ? _buildMessagesList(isDark)
                  : _buildEmptyState(isDark, chatName, chatAvatar, isOnline),
            ),

            // Input Area
            _buildInputArea(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, String chatName, String? chatAvatar, bool isOnline) {
    final backgroundColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(0.95),
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: AppColors.primary,
              size: 20,
            ),
          ),

          // Avatar
          GestureDetector(
            onTap: () {}, // TODO: Show profile
            child: Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                      width: 1,
                    ),
                  ),
                  child: chatAvatar != null
                      ? ClipOval(
                          child: Image.network(
                            chatAvatar,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: _getAvatarColor(chatName),
                                child: Center(
                                  child: Text(
                                    _getInitials(chatName),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : Container(
                          color: _getAvatarColor(chatName),
                          child: Center(
                            child: Text(
                              _getInitials(chatName),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                ),
                if (isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: backgroundColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Name and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chatName,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                if (isOnline)
                  Text(
                    'online',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),

          // Call button (replaced video call)
          IconButton(
            onPressed: () {}, // TODO: Start voice call
            icon: Icon(
              Icons.call,
              color: AppColors.primary,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(bool isDark) {
    final messageState = ref.watch(messageControllerProvider);
    final messages = messageState.messages[widget.chatId] ?? [];

    // Get current user ID from auth state
    final authState = ref.watch(authControllerProvider);
    final currentUserId = authState.user?.id ?? '';

    // Build a list of items (messages and date separators)
    final List<_MessageListItem> items = [];

    for (int i = 0; i < messages.length; i++) {
      // Add date separator if needed
      if (i == 0 || _shouldShowDateSeparatorForEntity(messages, i)) {
        items.add(_MessageListItem(isDateSeparator: true, messageIndex: i));
      }
      // Add the message
      items.add(_MessageListItem(isDateSeparator: false, messageIndex: i));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.isDateSeparator) {
          return _buildDateSeparator(messages[item.messageIndex].timestamp, isDark);
        }

        final message = messages[item.messageIndex];
        final isCurrentUser = message.senderId == currentUserId;
        final showAvatar = !isCurrentUser && _shouldShowAvatarForEntity(messages, item.messageIndex);

        return _buildMessageBubbleFromEntity(message, isDark, isCurrentUser, showAvatar);
      },
    );
  }

  bool _shouldShowDateSeparatorForEntity(List<MessageEntity> messages, int index) {
    if (index == 0) return true;
    if (index >= messages.length) return false;
    final current = messages[index].timestamp;
    final previous = messages[index - 1].timestamp;
    final currentDate = DateTime(current.year, current.month, current.day);
    final previousDate = DateTime(previous.year, previous.month, previous.day);
    return currentDate != previousDate;
  }

  bool _shouldShowAvatarForEntity(List<MessageEntity> messages, int index) {
    if (index == messages.length - 1) return true;
    if (index >= messages.length) return false;
    final current = messages[index];
    final next = index < messages.length - 1 ? messages[index + 1] : null;
    if (next == null) return true;
    return current.senderId != next.senderId ||
        (index < messages.length - 1 && messages[index].timestamp.difference(messages[index + 1].timestamp).inMinutes > 5);
  }

  Widget _buildMessageBubbleFromEntity(MessageEntity message, bool isDark, bool isCurrentUser, bool showAvatar) {
    // Convert MessageEntity to MessageModel for display
    final messageModel = MessageModel(
      id: message.id,
      chatId: message.chatId,
      senderId: message.senderId,
      senderName: message.senderName,
      senderAvatar: message.senderAvatar,
      content: message.content,
      type: _messageTypeFromString(message.type),
      timestamp: message.timestamp,
      isSent: message.status != 'sending',
      isRead: message.status == 'read',
      mediaUrl: message.mediaUrl,
      mediaSize: message.mediaSize,
      voiceDuration: message.voiceDuration,
    );
    return _buildMessageBubble(messageModel, isDark, isCurrentUser, showAvatar);
  }

  MessageType _messageTypeFromString(String type) {
    switch (type.toLowerCase()) {
      case 'text':
        return MessageType.text;
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'voice':
        return MessageType.voice;
      case 'file':
        return MessageType.file;
      case 'missedcall':
      case 'missed_call':
        return MessageType.missedCall;
      default:
        return MessageType.text;
    }
  }

  Widget _buildMessageBubble(MessageModel message, bool isDark, bool isCurrentUser, bool showAvatar) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser && showAvatar)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getAvatarColor(message.senderName ?? 'User'),
              ),
              child: message.senderAvatar != null
                  ? ClipOval(
                      child: Image.network(
                        message.senderAvatar!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(
                              _getInitials(message.senderName ?? 'U'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  : Center(
                      child: Text(
                        _getInitials(message.senderName ?? 'U'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
            )
          else if (!isCurrentUser)
            const SizedBox(width: 40),

          Flexible(
            child: Column(
              crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isCurrentUser
                        ? AppColors.primary
                        : (isDark ? AppColors.bubbleIncomingDark : AppColors.bubbleIncomingLight),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isCurrentUser ? 16 : 4),
                      bottomRight: Radius.circular(isCurrentUser ? 4 : 16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.type == MessageType.missedCall)
                        _buildMissedCallMessage(message, isCurrentUser)
                      else if (message.type == MessageType.image && message.mediaUrl != null)
                        _buildImageMessage(message, isCurrentUser)
                      else if (message.type == MessageType.voice)
                        _buildVoiceMessage(message, isCurrentUser)
                      else if (message.content != null)
                        Text(
                          message.content!,
                          style: TextStyle(
                            fontSize: 15,
                            color: isCurrentUser ? Colors.white : (isDark ? Colors.white : Colors.black87),
                            height: 1.4,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppDateUtils.DateUtils.formatTime(message.timestamp),
                            style: TextStyle(
                              fontSize: 10,
                              color: isCurrentUser
                                  ? Colors.white.withOpacity(0.7)
                                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                          ),
                          if (isCurrentUser) ...[
                            const SizedBox(width: 4),
                            Icon(
                              message.isRead ? Icons.done_all : Icons.done,
                              size: 14,
                              color: message.isRead
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.7),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (isCurrentUser) const SizedBox(width: 0),
        ],
      ),
    );
  }

  Widget _buildImageMessage(MessageModel message, bool isCurrentUser) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            message.mediaUrl!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 200,
                height: 150,
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image),
              );
            },
          ),
        ),
        if (message.mediaSize != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message.mediaSize!,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        if (message.content != null) ...[
          const SizedBox(height: 8),
          Text(
            message.content!,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMissedCallMessage(MessageModel message, bool isCurrentUser) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.call_missed,
          size: 18,
          color: isCurrentUser ? Colors.white : Colors.red,
        ),
        const SizedBox(width: 8),
        Text(
          'Missed call',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isCurrentUser ? Colors.white : Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceMessage(MessageModel message, bool isCurrentUser) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.play_arrow,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(15, (index) {
                  return Container(
                    width: 2,
                    height: index == 8 ? 24 : (index % 3 == 0 ? 16 : 8),
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      color: index == 8
                          ? AppColors.primary
                          : (isCurrentUser
                              ? Colors.white.withOpacity(0.5)
                              : Colors.grey[400]),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    message.voiceDuration != null
                        ? '0:${message.voiceDuration.toString().padLeft(2, '0')}'
                        : '0:00',
                    style: TextStyle(
                      fontSize: 12,
                      color: isCurrentUser
                          ? Colors.white.withOpacity(0.7)
                          : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    AppDateUtils.DateUtils.formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: isCurrentUser
                          ? Colors.white.withOpacity(0.7)
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateSeparator(DateTime date, bool isDark) {
    String text;
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      text = 'Today';
    } else if (difference.inDays == 1) {
      text = 'Yesterday';
    } else if (difference.inDays < 7) {
      text = DateFormat('EEE').format(date);
    } else {
      text = DateFormat('MMM d').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? AppColors.bubbleIncomingDark : const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[300] : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, String chatName, String? chatAvatar, bool isOnline) {
    final backgroundColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(
            'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAiIGhlaWdodD0iMjAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PGNpcmNsZSBjeD0iMTAiIGN5PSIxMCIgcj0iMSIgZmlsbD0iIzZiNzI4MCIvPjwvc3ZnPg==',
          ),
          repeat: ImageRepeat.repeat,
          opacity: isDark ? 0.05 : 0.03,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: surfaceColor,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: chatAvatar != null
                      ? ClipOval(
                          child: Image.network(
                            chatAvatar,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: _getAvatarColor(chatName),
                                child: Center(
                                  child: Text(
                                    _getInitials(chatName),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 40,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : Container(
                          color: _getAvatarColor(chatName),
                          child: Center(
                            child: Text(
                              _getInitials(chatName),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                              ),
                            ),
                          ),
                        ),
                ),
                if (isOnline)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: backgroundColor,
                          width: 4,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            // Name
            Text(
              chatName,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 4),
            // Username placeholder
            Text(
              '@${chatName.toLowerCase().replaceAll(' ', '')}',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            // Info box
            Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: surfaceColor.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? AppColors.dividerDark.withOpacity(0.3)
                      : AppColors.dividerLight.withOpacity(0.6),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'No messages here yet.',
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Send a message or tap the video icon to start chatting with $chatName.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.textSecondaryDark.withOpacity(0.8)
                          : AppColors.textSecondaryLight.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            // Encryption info
            Column(
              children: [
                Icon(
                  Icons.lock,
                  size: 28,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 220,
                  child: Text(
                    'Messages are end-to-end encrypted. No one outside of this chat can read them.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    final backgroundColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.backgroundDark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: surfaceColor.withOpacity(0.85),
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Attach button
            IconButton(
              onPressed: () {}, // TODO: Show attachment options
              icon: Transform.rotate(
                angle: 0.785, // 45 degrees
                child: Icon(
                  Icons.attach_file,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  size: 28,
                ),
              ),
            ),
            // Input field
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.backgroundDark : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Message...',
                          hintStyle: TextStyle(
                            fontSize: 15,
                            color: isDark
                                ? Colors.grey[500]
                                : Colors.grey[500],
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _handleSendMessage(),
                      ),
                    ),
                    IconButton(
                      onPressed: () {}, // TODO: Show emoji picker
                      icon: Icon(
                        Icons.sentiment_satisfied,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send/Mic button
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _messageController.text.trim().isNotEmpty
                    ? AppColors.primary
                    : AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _messageController.text.trim().isNotEmpty
                      ? _handleSendMessage
                      : () {}, // TODO: Start voice recording
                  borderRadius: BorderRadius.circular(22),
                  child: Center(
                    child: Icon(
                      _messageController.text.trim().isNotEmpty
                          ? Icons.send
                          : Icons.mic,
                      color: _messageController.text.trim().isNotEmpty
                          ? Colors.white
                          : AppColors.primary,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF3B82F6),
      const Color(0xFF06B6D4),
    ];
    return colors[name.hashCode % colors.length];
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length > 2 ? 2 : name.length).toUpperCase();
  }

}
