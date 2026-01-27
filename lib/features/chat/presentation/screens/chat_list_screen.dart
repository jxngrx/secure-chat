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
  int _selectedTab = 2; // 0: Contacts, 1: Calls, 2: Chats, 3: Settings
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    // Load chats from backend
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatControllerProvider.notifier).loadChats();
    });
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
      case 0: // Contacts
        Navigator.pushReplacementNamed(context, RouteNames.contacts);
        break;
      case 1: // Calls
        Navigator.pushReplacementNamed(context, RouteNames.calls);
        break;
      case 2: // Chats
        // Already on chats, do nothing
        break;
      case 3: // Settings
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

            // Main Content
            Expanded(
              child: isLoading && chats.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : hasChats
                      ? _buildChatList(isDark, chats)
                      : _buildEmptyState(isDark),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: fabBottomPadding),
        child: FloatingActionButton(
          onPressed: _handleNewChat,
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.edit, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
              TextButton(
                onPressed: () {},
                child: Text(
                  'Edit',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
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

  Widget _buildChatList(bool isDark, List<ChatEntity> chats) {
    // Get messages from message controller to calculate unread count
    final messageState = ref.watch(messageControllerProvider);
    
    // Convert ChatEntity to ChatItemModel for display
    final chatItems = chats.map<ChatItemModel>((chat) {
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

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: chatItems.length,
      itemBuilder: (context, index) {
        return _buildChatItem(chatItems[index], isDark);
      },
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
            chat.lastMessage!,
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
            chat.lastMessage!,
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
          _buildNavItem(Icons.contacts, 'Contacts', 0, isDark),
          _buildNavItem(Icons.call, 'Calls', 1, isDark),
          _buildNavItem(Icons.chat_bubble, 'Chats', 2, isDark),
          _buildNavItem(Icons.settings, 'Settings', 3, isDark),
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
      return DateFormat('EEE').format(time);
    } else {
      return DateFormat('MMM d').format(time);
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
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length > 2 ? 2 : name.length).toUpperCase();
  }

}
