import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/utils/date_utils.dart' as AppDateUtils;
import '../../../../core/storage/local_storage.dart';
import '../../../../di/injection_container.dart';
import '../../data/models/chat_item_model.dart';
import '../widgets/empty_state.dart';
import '../notifiers/chat_controller.dart';
import '../../domain/entities/chat_entity.dart';
import '../../../message/presentation/notifiers/message_controller.dart';
import '../../../../di/providers.dart';
import '../../../../core/services/call_log_service.dart';
import '../../../../core/services/contact_service.dart';
import '../../../../core/services/contact_sync_service.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({
    super.key,
    bool? showBottomNav,
    this.onTabSelected,
  }) : showBottomNav = showBottomNav ?? true;

  final bool showBottomNav;
  final ValueChanged<int>? onTabSelected;

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedTab = 1; // 0: Calls, 1: Chats, 2: Settings
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    // Load chats from backend
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatControllerProvider.notifier).loadChats();
      _requestPermissions();
    });
  }

  Future<void> _requestPermissions() async {
    try {
      // 1. Request Call Log permission (only if not already granted)
      final callLogService = InjectionContainer.resolve<CallLogService>();
      final hasCallLogPermission = await callLogService.isCallLogPermissionGranted();
      if (!hasCallLogPermission) {
        await callLogService.requestCallLogPermission();
      }

      // 2. Request Contact permission (only if not already granted)
      final contactService = InjectionContainer.resolve<ContactService>();
      bool hasContactPermission = await contactService.hasPermission();

      if (!hasContactPermission) {
        hasContactPermission = await contactService.requestPermission();
      }

      if (hasContactPermission) {
        // Trigger initial contact sync
        final contactSyncService = InjectionContainer.resolve<ContactSyncService>();
        contactSyncService.syncContactsSilently();
      }
    } catch (e) {
      // Ignore errors during permission request
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
      // Silently fail
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleStartMessaging() {
    Navigator.pushNamed(context, RouteNames.userSearch);
  }

  void _handleChatTap(ChatItemModel chat) {
    Navigator.pushNamed(
      context,
      RouteNames.chat,
      arguments: {
        'chatId': chat.id,
        'chatName': chat.name,
        'chatAvatar': chat.avatarUrl,
        'isOnline': chat.isOnline,
      },
    );
  }

  void _handleNewChat() {
    Navigator.pushNamed(context, RouteNames.userSearch);
  }

  void _handleTabChange(int index) {
    if (index == _selectedTab) return; // Already on this tab

    if (widget.onTabSelected != null) {
      widget.onTabSelected!(index);
      return;
    }

    switch (index) {
      case 0: // Calls
        Navigator.pushReplacementNamed(context, RouteNames.calls);
        break;
      case 1: // Chats
        // Already on chats, do nothing
        break;
      case 2: // Settings
        Navigator.pushReplacementNamed(context, RouteNames.settings);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

    // Watch chat state
    final chatState = ref.watch(chatControllerProvider);
    final chats = chatState.chats;
    final hasChats = chats.isNotEmpty;
    final isLoading = chatState.isLoading;

    final safeBottom = MediaQuery.of(context).padding.bottom;
    // Position FAB lower in the corner
    final fabBottomPadding = widget.showBottomNav ? safeBottom + 120 : safeBottom + 20;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        top: true,
        child: Column(
          children: [
            // Header
            _buildHeader(isDark),

            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await ref.read(chatControllerProvider.notifier).loadChats();
                },
                child: isLoading && chats.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : hasChats
                        ? _buildChatList(isDark, chatState)
                        : _buildEmptyState(isDark),
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: widget.showBottomNav ? _buildBottomNavigation(isDark) : null,
    );
  }

  Widget _buildHeader(bool isDark) {
    final backgroundColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(0.95),
        border: Border(
           bottom: BorderSide(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Top row with Edit and New Chat button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Placeholder to keep the title centered if needed, or just remove.
              // For now, I'll just remove it as requested.
              // If the user wants the title centered, they might need a Spacer or just standard alignment.
              // But strictly following instruction "remove".
              // To balance the row if needed, I could use a SizedBox, but purely removing is the direct interpretation.
              // However, to avoid "Chats" jumping to the extreme left, I might want to check the layout.
              // Row(mainAxisAlignment: MainAxisAlignment.spaceBetween) with 2 items = Left + Right.
              // That sounds fine for a standard header.
              const SizedBox(width: 48), // Balancing the right icon button to keep title somewhat centered
              Text(
                'Chats',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              IconButton(
                onPressed: _handleNewChat,
                icon: Icon(
                  Icons.edit_square,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search bar
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'Search chats, people, groups, and usernames',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.search,
                    size: 20,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(bool isDark, ChatState chatState) {
    // Get messages from message controller to calculate unread count
    final messageState = ref.watch(messageControllerProvider);

    // Convert ChatEntity to ChatItemModel for display
    final chatItems = chatState.chats.map<ChatItemModel>((chat) {
      // Extract last message content and type
      String? lastMessageContent;
      MessageType? lastMessageType;
      String? lastMessageSender;

      if (chat.lastMessage != null) {
        final lastMsg = chat.lastMessage!;
        lastMessageContent = lastMsg['content'] as String?;
        final msgType = lastMsg['type'] as String? ?? 'text';
        lastMessageType = _messageTypeFromString(msgType);

        // For group chats, get sender name
        if (chat.isGroup && lastMsg['sender'] != null) {
          final sender = lastMsg['sender'] as Map<String, dynamic>?;
          lastMessageSender = sender?['username'] as String? ?? sender?['phone'] as String?;
        }
      }

      // Calculate unread count from messages if available
      int unreadCount = chat.unreadCount ?? 0;
      if (unreadCount == 0 && _currentUserId != null) {
        final chatMessages = messageState.messages[chat.id] ?? [];
        unreadCount = chatMessages.where((msg) {
          return msg.senderId != _currentUserId && msg.status != 'read';
        }).length;
      }

      return ChatItemModel(
        id: chat.id,
        name: chat.name ?? 'Unknown',
        avatarUrl: null, // Will be set from participant data if available
        lastMessage: lastMessageContent,
        lastMessageTime: chat.lastMessageTime,
        unreadCount: unreadCount,
        isOnline: false, // Can be set from participant data
        isGroup: chat.isGroup,
        lastMessageSender: lastMessageSender,
        lastMessageType: lastMessageType,
      );
    }).toList();

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (!chatState.isLoadingMore &&
            chatState.hasMore &&
            scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 200) {
          ref.read(chatControllerProvider.notifier).loadMoreChats();
        }
        return false;
      },
      child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(), // Ensure scroll even when empty for Refresh
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: chatItems.length + (chatState.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == chatItems.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            return _buildChatItem(chatItems[index], isDark);
          },
        ),
    );
  }

  Widget _buildChatItem(ChatItemModel chat, bool isDark) {
    final lastMessageTime = chat.lastMessageTime != null
        ? _formatLastMessageTime(chat.lastMessageTime!)
        : null;

    return InkWell(
      onTap: () => _handleChatTap(chat),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? AppColors.dividerDark.withOpacity(0.5)
                  : AppColors.dividerLight,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            _buildAvatar(chat, isDark),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                chat.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (chat.isMuted) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.volume_off,
                                size: 14,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (lastMessageTime != null)
                            Text(
                              lastMessageTime,
                              style: TextStyle(
                                fontSize: 12,
                                color: chat.unreadCount > 0
                                    ? AppColors.primary
                                    : (isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight),
                                fontWeight: chat.unreadCount > 0
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                          if (chat.unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: chat.unreadCount > 99 ? 6 : 8,
                                vertical: 2,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildLastMessage(chat, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(ChatItemModel chat, bool isDark) {
    return Stack(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: chat.avatarUrl == null
                ? _getAvatarColor(chat.name)
                : null,
          ),
          child: chat.avatarUrl != null
              ? ClipOval(
                  child: Image.network(
                    chat.avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: _getAvatarColor(chat.name),
                        child: Center(
                          child: Text(
                            _getInitials(chat.name),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                )
              : Center(
                  child: Text(
                    _getInitials(chat.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
        if (chat.isOnline)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLastMessage(ChatItemModel chat, bool isDark) {
    if (chat.lastMessage == null) {
      return const SizedBox.shrink();
    }

    Widget messageWidget;

    if (chat.lastMessageType == MessageType.missedCall) {
      messageWidget = Row(
        children: [
          Icon(
            Icons.call_missed,
            size: 16,
            color: Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            'Missed call',
            style: TextStyle(
              fontSize: 15,
              color: Colors.red,
            ),
          ),
        ],
      );
    } else if (chat.lastMessageType == MessageType.image) {
      messageWidget = Row(
        children: [
          Icon(
            Icons.image,
            size: 16,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
          const SizedBox(width: 4),
          Text(
            'Image',
            style: TextStyle(
              fontSize: 15,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else if (chat.lastMessageType == MessageType.voice) {
      messageWidget = Row(
        children: [
          Icon(
            Icons.mic,
            size: 16,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
          const SizedBox(width: 4),
          Text(
            'Voice message',
            style: TextStyle(
              fontSize: 15,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else {
      // Text message or group message
      String displayText = chat.lastMessage!;
      bool isLocation = false;
      bool isImageLink = false;

      // Simple check for location JSON pattern
      if (displayText.trim().startsWith('{"currentLocation":')) {
        isLocation = true;
      }

      // Check for image link pattern
      final trimmedText = displayText.trim().toLowerCase();
      if (trimmedText.startsWith('http')) {
        if (trimmedText.contains('res.cloudinary.com') ||
            trimmedText.endsWith('.jpg') ||
            trimmedText.endsWith('.jpeg') ||
            trimmedText.endsWith('.png') ||
            trimmedText.endsWith('.gif') ||
            trimmedText.endsWith('.webp')) {
          isImageLink = true;
        }
      }

      if (isLocation) {
        messageWidget = Row(
          children: [
            Icon(
              Icons.location_on,
              size: 16,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            const SizedBox(width: 4),
            Text(
              "Location Shared",
              style: TextStyle(
                fontSize: 15,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      } else if (isImageLink) {
        messageWidget = Row(
          children: [
            Icon(
              Icons.image,
              size: 16,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            const SizedBox(width: 4),
            Text(
              "Image",
              style: TextStyle(
                fontSize: 15,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      } else {
        if (chat.isGroup && chat.lastMessageSender != null) {
          displayText = '${chat.lastMessageSender}: ${chat.lastMessage}';
        }

        messageWidget = Text(
          displayText,
          style: TextStyle(
            fontSize: 15,
            color: chat.unreadCount > 0
                ? (isDark ? Colors.white : Colors.black87)
                : (isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight),
            fontWeight: chat.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
          ),
          overflow: TextOverflow.ellipsis,
        );
      }
    }

    return messageWidget;
  }

  Widget _buildEmptyState(bool isDark) {
    return EmptyChatState(
      onStartMessaging: _handleStartMessaging,
      isDark: isDark,
    );
  }

  Widget _buildBottomNavigation(bool isDark) {
    final backgroundColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    return Container(
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.surfaceDark : Colors.white).withOpacity(0.95),
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // _buildNavItem(Icons.call, 'Calls', 0, isDark),
          _buildNavItem(Icons.chat_bubble, 'Chats', 1, isDark),
          _buildNavItem(Icons.settings, 'Settings', 2, isDark),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, bool isDark) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => _handleTabChange(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 26,
              color: isSelected
                  ? AppColors.primary
                  : (isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight),
              fill: isSelected ? 1.0 : 0.0,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
              ),
            ),
          ],
        ),
      ),
    );
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

  String _formatLastMessageTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      return AppDateUtils.DateUtils.formatTime(time);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEE').format(time.toLocal());
    } else {
      return DateFormat('MMM d').format(time.toLocal());
    }
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFEC4899), // Pink
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF10B981), // Green
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF06B6D4), // Cyan
    ];
    return colors[name.hashCode % colors.length];
  }

  String _getInitials(String name) {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return '?';
    final parts = cleanName.split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return cleanName.length >= 2
        ? cleanName.substring(0, 2).toUpperCase()
        : cleanName.toUpperCase();
  }

}
