import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/utils/date_utils.dart' as AppDateUtils;
import '../../../../core/storage/local_storage.dart';
import '../../../../di/injection_container.dart';
import '../../data/models/chat_item_model.dart';
import '../../data/models/message_model.dart';
import '../notifiers/chat_controller.dart';
import '../../../message/presentation/notifiers/message_controller.dart';
import '../../../message/domain/entities/message_entity.dart';
import '../../../../di/providers.dart';
import '../../../call/presentation/screens/outgoing_call_screen.dart';
import '../../../call/presentation/notifiers/call_controller.dart';

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
  String? _currentUserId;
  bool _showScrollToBottomButton = false;
  int _previousMessageCount = 0;
  bool _isLoadingMessages = true;
  Set<String> _selectedMessages = {}; // Selected message IDs for deletion

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    // Load messages when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      setState(() {
        _isLoadingMessages = true;
      });
      try {
        await ref.read(messageControllerProvider.notifier).loadMessages(widget.chatId);
        ref.read(chatControllerProvider.notifier).joinChat(widget.chatId);
        _scrollToBottom(force: true); // Scroll to bottom on initial load
      } finally {
        if (mounted) {
          setState(() {
            _isLoadingMessages = false;
          });
        }
      }
    });
    // Listen to text changes to update send button
    _messageController.addListener(() {
      setState(() {});
    });
    // Listen to scroll position to show/hide scroll to bottom button
    _scrollController.addListener(_onScroll);
  }

  DateTime? _lastMarkAsReadTime;
  static const _markAsReadDebounceMs = 1000; // Mark as read every 1 second max

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final isAtBottom = (maxScroll - currentScroll) < 100; // 100px threshold

    if (_showScrollToBottomButton != !isAtBottom) {
      setState(() {
        _showScrollToBottomButton = !isAtBottom;
      });
    }

    // Mark messages as read when user scrolls and views them
    final now = DateTime.now();
    if (_lastMarkAsReadTime == null ||
        now.difference(_lastMarkAsReadTime!).inMilliseconds > _markAsReadDebounceMs) {
      _lastMarkAsReadTime = now;
      _markVisibleMessagesAsRead();
    }
  }

  Future<void> _markVisibleMessagesAsRead() async {
    if (_currentUserId == null) return;

    try {
      final messageState = ref.read(messageControllerProvider);
      final messages = messageState.messages[widget.chatId] ?? [];

      // Check if there are any unread messages from other users
      final hasUnreadMessages = messages.any((msg) =>
        msg.senderId != _currentUserId && msg.status != 'read'
      );

      if (hasUnreadMessages) {
        // Mark all unread messages in this chat as read
        await ref.read(messageControllerProvider.notifier).markAsRead(widget.chatId);
      }
    } catch (e) {
      // Silently fail - don't interrupt user experience
    }
  }

  Future<void> _handleDeleteChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text('Are you sure you want to delete this chat? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(chatControllerProvider.notifier).deleteChat(widget.chatId);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting chat: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final localStorage = InjectionContainer.resolve<LocalStorage>();
      final userProfileJson = await localStorage.read(StorageKeys.userProfile);
      if (userProfileJson != null && userProfileJson.isNotEmpty) {
        final userProfile = jsonDecode(userProfileJson) as Map<String, dynamic>;
        setState(() {
          _currentUserId = userProfile['id'] as String?;
        });
      }
    } catch (e) {
      // If error, try to get from auth state as fallback
      final authState = ref.read(authControllerProvider);
      setState(() {
        _currentUserId = authState.user?.id;
      });
    }
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
    // Always scroll to bottom when current user sends message
    _scrollToBottom(force: true);
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.position.pixels;
        final isAtBottom = (maxScroll - currentScroll) < 100;

        // Only scroll if at bottom or forced (for current user messages)
        if (force || isAtBottom) {
          _scrollController.animateTo(
            maxScroll,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
          setState(() {
            _showScrollToBottomButton = false;
          });
        } else if (!force) {
          // User is scrolled up, show scroll to bottom button
          setState(() {
            _showScrollToBottomButton = true;
          });
        }
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
              child: Stack(
                children: [
                  _isLoadingMessages
                      ? const Center(child: CircularProgressIndicator())
                      : (hasMessages
                          ? _buildMessagesList(isDark)
                          : _buildEmptyState(isDark, chatName, chatAvatar, isOnline)),
                  // Scroll to bottom button
                  if (_showScrollToBottomButton && !_isLoadingMessages)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: FloatingActionButton(
                        mini: true,
                        onPressed: () => _scrollToBottom(force: true),
                        backgroundColor: AppColors.primary,
                        child: const Icon(Icons.arrow_downward, color: Colors.white, size: 20),
                      ),
                    ),
                ],
              ),
            ),

            // Input Area
            if (_selectedMessages.isEmpty) _buildInputArea(isDark),

            // Selection mode bottom bar
            if (_selectedMessages.isNotEmpty)
              _buildSelectionBottomBar(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionBottomBar(bool isDark) {
    final backgroundColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final messageState = ref.watch(messageControllerProvider);
    final messages = messageState.messages[widget.chatId] ?? [];
    final selectedMessagesList = messages.where((m) => _selectedMessages.contains(m.id)).toList();
    final canDeleteForEveryone = selectedMessagesList.every((m) {
      if (m.senderId != _currentUserId) return false;
      if (m.status == 'read') return false;
      final age = DateTime.now().difference(m.timestamp);
      return age.inMinutes <= 5;
    });

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom,
        top: 8,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_selectedMessages.length} selected',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          Row(
            children: [
              if (canDeleteForEveryone)
                TextButton.icon(
                  onPressed: () => _handleDeleteSelectedMessages(deleteForEveryone: true),
                  icon: const Icon(Icons.delete_forever, color: Colors.red, size: 20),
                  label: const Text('Delete for everyone', style: TextStyle(color: Colors.red)),
                ),
              TextButton.icon(
                onPressed: () => _handleDeleteSelectedMessages(deleteForEveryone: false),
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                label: const Text('Delete for me', style: TextStyle(color: Colors.red)),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedMessages.clear();
                  });
                },
                icon: const Icon(Icons.close, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteSelectedMessages({required bool deleteForEveryone}) async {
    if (_selectedMessages.isEmpty) return;

    final messageController = ref.read(messageControllerProvider.notifier);
    final messageState = ref.read(messageControllerProvider);
    final messages = messageState.messages[widget.chatId] ?? [];
    final selectedMessagesList = messages.where((m) => _selectedMessages.contains(m.id)).toList();

    if (deleteForEveryone) {
      // Check time limit
      final now = DateTime.now();
      final messagesOverLimit = selectedMessagesList.where((m) {
        final age = now.difference(m.timestamp);
        return age.inMinutes > 5;
      }).toList();

      if (messagesOverLimit.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Some messages are older than 5 minutes and cannot be deleted for everyone'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    try {
      for (final message in selectedMessagesList) {
        await messageController.deleteMessage(
          messageId: message.id,
          chatId: widget.chatId,
          deleteForEveryone: deleteForEveryone,
        );
      }

      if (mounted) {
        setState(() {
          _selectedMessages.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${selectedMessagesList.length} message(s) deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting messages: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDeletedMessage(bool isDark, String text, {bool isSender = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(12),
          topRight: const Radius.circular(12),
          bottomLeft: isSender ? const Radius.circular(12) : const Radius.circular(0),
          bottomRight: isSender ? const Radius.circular(0) : const Radius.circular(12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.block,
            size: 16,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
        ],
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

          // Call button
          IconButton(
            icon: Icon(
              Icons.call,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
            onPressed: () {
               // Extract the other user's ID from chatId
               // chatId format is "userId1_userId2" (sorted alphabetically)
               if (widget.chatId.isNotEmpty && _currentUserId != null) {
                 final chatIdParts = widget.chatId.split('_');
                 String? receiverId;
                 
                 // Find the participant ID that is NOT the current user
                 for (final part in chatIdParts) {
                   if (part != _currentUserId && part.length == 24) {
                     // Valid MongoDB ObjectId format
                     receiverId = part;
                     break;
                   }
                 }
                 
                 if (receiverId == null) {
                   // Fallback: try to get from chat entity if available
                   final chatState = ref.read(chatControllerProvider);
                   final chat = chatState.chats.firstWhere(
                     (c) => c.id == widget.chatId,
                     orElse: () => chatState.chats.first,
                   );
                   
                   if (chat.participantIds.isNotEmpty) {
                     receiverId = chat.participantIds.firstWhere(
                       (id) => id != _currentUserId,
                       orElse: () => chat.participantIds.first,
                     );
                   }
                 }
                 
                 if (receiverId != null && receiverId.isNotEmpty) {
                   final controller = ref.read(callControllerProvider.notifier);
                   controller.initiateCall(receiverId);

                   Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OutgoingCallScreen(
                          receiverId: receiverId!,
                          receiverName: chatName,
                        ),
                      ),
                   );
                 } else {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Unable to determine recipient for call')),
                   );
                 }
               } else if (_currentUserId == null) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Please wait, loading user information...')),
                 );
               }
            },
          ),

          // Edit button (menu with delete option)
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              size: 24,
            ),
            onSelected: (value) {
              if (value == 'delete') {
                _handleDeleteChat();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Delete Chat', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }

  Widget _buildMessagesList(bool isDark) {
    final messageState = ref.watch(messageControllerProvider);
    var messages = messageState.messages[widget.chatId] ?? [];

    // Get current user ID from local storage or auth state
    final currentUserId = _currentUserId ?? '';

    // Filter out messages that are "Deleted for Me"
    messages = messages.where((m) {
      if (m.deleteForEveryone) return true; // Show "This message was deleted"

      final isSender = m.senderId == currentUserId;
      if (isSender && m.sentUserMessageIsDeleted) return false;
      if (!isSender && m.receiveUserMessageIsDeleted) return false;

      return true;
    }).toList();

    final currentMessageCount = messages.length;

    // Check if new message was added (from other user or our own)
    if (currentMessageCount > _previousMessageCount && messages.isNotEmpty) {
      final lastMessage = messages.last;
      final isFromCurrentUser = lastMessage.senderId == currentUserId;

      // Auto-scroll for new messages
      // If from current user, always scroll (handled in _handleSendMessage too, but ensure it here)
      // If from other user, only scroll if user is near bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isFromCurrentUser) {
          // Always scroll for our own messages
          _scrollToBottom(force: true);
        } else {
          // Scroll for other user's messages if we're near bottom
          _scrollToBottom(force: false);
        }
      });

      _previousMessageCount = currentMessageCount;
    } else if (currentMessageCount != _previousMessageCount) {
      // Message count changed (could be deletion or initial load)
      _previousMessageCount = currentMessageCount;
    }

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
      deleteForEveryone: message.deleteForEveryone,
      sentUserMessageIsDeleted: message.sentUserMessageIsDeleted,
      receiveUserMessageIsDeleted: message.receiveUserMessageIsDeleted,
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
    // Check deletion status
    if (message.deleteForEveryone) {
      if (isCurrentUser && message.sentUserMessageIsDeleted) {
         // Sender sees "You deleted this message" if they deleted for everyone
         return Padding(
           padding: const EdgeInsets.only(bottom: 4, right: 16, left: 16),
           child: Row(
             mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
             children: [
               _buildDeletedMessage(isDark, "You deleted this message", isSender: isCurrentUser),
             ],
           ),
         );
      }
      // Everyone else sees "This message was deleted"
      return Padding(
           padding: const EdgeInsets.only(bottom: 4, right: 16, left: 16),
           child: Row(
             mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
             children: [
               if (!isCurrentUser && showAvatar) ...[
                 Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getAvatarColor(message.senderName ?? 'User'),
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(message.senderName ?? 'U'),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
               ] else if (!isCurrentUser)
                 const SizedBox(width: 40),

               _buildDeletedMessage(isDark, "This message was deleted", isSender: isCurrentUser),
             ],
           ),
         );
    }

    // "Delete for me" is handled by filtering out the message in _buildMessagesList
    // So if we are here, it's a normal message

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
            child: GestureDetector(
              onLongPress: () {
                if (message.id.startsWith('temp_')) return; // Don't allow selection of optimistic messages
                setState(() {
                  if (_selectedMessages.contains(message.id)) {
                    _selectedMessages.remove(message.id);
                  } else {
                    _selectedMessages.add(message.id);
                  }
                });
              },
              child: Column(
                crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedMessages.contains(message.id)
                          ? (isDark ? Colors.blue.withOpacity(0.3) : Colors.blue.withOpacity(0.2))
                          : (isCurrentUser
                              ? AppColors.primary
                              : (isDark ? AppColors.bubbleIncomingDark : AppColors.bubbleIncomingLight)),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isCurrentUser ? 16 : 4),
                        bottomRight: Radius.circular(isCurrentUser ? 4 : 16),
                      ),
                      border: _selectedMessages.contains(message.id)
                          ? Border.all(color: AppColors.primary, width: 2)
                          : null,
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
          ),
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
                              ? Colors.white.withValues(alpha: 0.5)
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
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    AppDateUtils.DateUtils.formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: isCurrentUser
                          ? Colors.white.withValues(alpha: 0.7)
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
                        color: Colors.black.withValues(alpha: 0.1),
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
                      ? AppColors.dividerDark.withValues(alpha: 0.3)
                      : AppColors.dividerLight.withValues(alpha: 0.6),
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
                          ? AppColors.textSecondaryDark.withValues(alpha: 0.8)
                          : AppColors.textSecondaryLight.withValues(alpha: 0.8),
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
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.backgroundDark;
    final hasText = _messageController.text.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.85),
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
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSendMessage(),
                ),
              ),
            ),
            // Send button (only show when text is entered)
            if (hasText) ...[
              const SizedBox(width: 8),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _handleSendMessage,
                    borderRadius: BorderRadius.circular(22),
                    child: const Center(
                      child: Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
