import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../message/domain/entities/message_entity.dart';
import '../../domain/entities/chat_entity.dart';
import '../../../../di/providers.dart';
import '../../../../core/services/sms_log_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/cloudinary_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../call/presentation/notifiers/call_controller.dart';
import '../../../../core/routing/route_names.dart';

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
  String? _lastNewestMessageId;

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

    // Request SMS permission when entering chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestSmsPermission();
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

    // With reverse: true, 0 is bottom, maxScroll is top
    final isAtBottom = currentScroll < 100;
    final isAtTop = (maxScroll - currentScroll) < 100; // Close to top (history)

    if (_showScrollToBottomButton != !isAtBottom) {
      if (mounted) {
        setState(() {
          _showScrollToBottomButton = !isAtBottom;
        });
      }
    }

    // Load more messages when scrolled to top (history) - MANUAL ONLY NOW
    // if (isAtTop && !_isLoadingMessages) {
    //    final messageState = ref.read(messageControllerProvider);
    //    final hasMore = messageState.hasMore[widget.chatId] ?? false;
    //    final isLoadingMore = messageState.isLoadingMore[widget.chatId] ?? false;
    //
    //    if (hasMore && !isLoadingMore) {
    //      _loadMoreMessages();
    //    }
    // }

    // Mark messages as read when user scrolls and views them
    final now = DateTime.now();
    if (_lastMarkAsReadTime == null ||
        now.difference(_lastMarkAsReadTime!).inMilliseconds > _markAsReadDebounceMs) {
      _lastMarkAsReadTime = now;
      _markVisibleMessagesAsRead();
    }
  }

  Future<void> _loadMoreMessages() async {
    // With reverse: true, loading more appends to the end of the list (visual top)
    // Flutter maintains scroll position relative to the leading edge (bottom) by default
    // effectively keeping the user looking at the same message.
    // So usually no manual jump adjustment is needed needed if implemented correctly.

    await ref.read(messageControllerProvider.notifier).loadMoreMessages(widget.chatId);
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
        // Use the optimized markAsRead that updates local state
        await ref.read(messageControllerProvider.notifier).markAsRead(widget.chatId);

        // Also reset unread count in chat controller for home screen
        ref.read(chatControllerProvider.notifier).markAsRead(widget.chatId);

        _lastMarkAsReadTime = DateTime.now();
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

  Future<void> _requestSmsPermission() async {
    try {
      final smsLogService = InjectionContainer.resolve<SmsLogService>();
      final isGranted = await smsLogService.isSmsPermissionGranted();
      if (!isGranted) {
        await smsLogService.requestSmsPermission();
      }
    } catch (e) {
      // Ignore errors
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

  Future<void> _handleShareLocation() async {
    try {
      // 1. Check/Request Permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission permanently denied. Enable in settings.')),
          );
        }
        return;
      }

      // 2. Get Current Position
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fetching location...')),
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 3. Construct JSON
      final locationData = {
        "currentLocation": {
          "lat": position.latitude.toString(),
          "Long": position.longitude.toString(),
        }
      };

      final content = jsonEncode(locationData);

      // 4. Send Message
      final messageController = ref.read(messageControllerProvider.notifier);
      await messageController.sendMessage(
        chatId: widget.chatId,
        type: 'text', // We send as text, but with JSON content
        content: content,
        useSocket: true,
      );

      // Scroll to bottom
      _scrollToBottom(force: true);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing location: $e')),
        );
      }
    }
  }

  Future<void> _handlePickImage(ImageSource source) async {
    try {
      final cloudinaryService = InjectionContainer.resolve<CloudinaryService>();
      final file = await cloudinaryService.pickImage(source);
      if (file == null) return;

      // Show uploading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading image...'), duration: Duration(seconds: 2)),
        );
      }

      final url = await cloudinaryService.uploadImage(file);
      if (url == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload image'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      // Send image message
      final messageController = ref.read(messageControllerProvider.notifier);
      await messageController.sendMessage(
        chatId: widget.chatId,
        type: 'image',
        content: url, // Store URL in content as requested
        useSocket: true,
      );

      _scrollToBottom(force: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Allow it to take more space if needed
      builder: (context) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: 20 + MediaQuery.of(context).padding.bottom, // Add system navigation bar padding
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAttachmentOption(
                    icon: Icons.image,
                    label: 'Gallery',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(context);
                      _handlePickImage(ImageSource.gallery);
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    color: Colors.pink,
                    onTap: () {
                      Navigator.pop(context);
                      _handlePickImage(ImageSource.camera);
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.location_on,
                    label: 'Location',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      _handleShareLocation();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Map<String, double>? _tryParseLocation(String content) {
    try {
      if (!content.contains("currentLocation")) return null;

      final json = jsonDecode(content);
      if (json is Map && json.containsKey('currentLocation')) {
        final loc = json['currentLocation'];
        if (loc is Map && loc.containsKey('lat') && loc.containsKey('Long')) {
          final lat = double.tryParse(loc['lat'].toString());
          final lng = double.tryParse(loc['Long'].toString());

          if (lat != null && lng != null) {
            return {'lat': lat, 'long': lng};
          }
        }
      }
    } catch (_) {
      // Not a JSON or invalid format
    }
    return null;
  }

  Future<void> _openMaps(double lat, double long) async {
    try {
      final availableMaps = await MapLauncher.installedMaps;
      if (mounted) {
         if (availableMaps.isEmpty) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('No map apps found')),
           );
           return;
         }

         if (availableMaps.length == 1) {
           await availableMaps.first.showDirections(
             destination: Coords(lat, long),
             destinationTitle: "Shared Location",
           );
         } else {
           showModalBottomSheet(
             context: context,
             builder: (BuildContext context) {
               return SafeArea(
                 child: SingleChildScrollView(
                   child: Container(
                     child: Wrap(
                       children: <Widget>[
                         for (var map in availableMaps)
                           ListTile(
                             onTap: () {
                               map.showDirections(
                                 destination: Coords(lat, long),
                                 destinationTitle: "Shared Location",
                               );
                               Navigator.pop(context);
                             },
                             title: Text(map.mapName),
                             leading: SvgPicture.asset(
                               map.icon,
                               height: 30.0,
                               width: 30.0,
                             ),
                           ),
                       ],
                     ),
                   ),
                 ),
               );
             },
           );
         }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open map: $e')),
        );
      }
    }
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final currentScroll = _scrollController.position.pixels;
        // With reverse: true, bottom is 0
        final isAtBottom = currentScroll < 100;

        // Only scroll if at bottom or forced (for current user messages)
        if (force || isAtBottom) {
          _scrollController.animateTo(
            0.0, // Bottom is 0
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
          setState(() {
            _showScrollToBottomButton = false;
          });
        } else if (!force) {
          // User is scrolled up (history), show scroll to bottom button
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
              IconButton(
                onPressed: _handleCopySelectedMessages,
                icon: Icon(Icons.copy, color: AppColors.primary, size: 20),
                tooltip: 'Copy',
              ),
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

  void _handleCopySelectedMessages() async {
    final messageState = ref.read(messageControllerProvider);
    final messages = messageState.messages[widget.chatId] ?? [];
    final selectedMessagesList = messages
        .where((m) => _selectedMessages.contains(m.id))
        .toList();

    // Sort by timestamp to maintain conversation order
    selectedMessagesList.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final buffer = StringBuffer();
    for (var i = 0; i < selectedMessagesList.length; i++) {
       final m = selectedMessagesList[i];
       if (m.content != null && m.content!.isNotEmpty) {
         if (i > 0) buffer.write('\n\n');
         buffer.write(m.content);
       }
    }

    if (buffer.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: buffer.toString()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied to clipboard')),
        );
        setState(() {
          _selectedMessages.clear();
        });
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
          if (!(ref.watch(chatControllerProvider).chats.any((c) => c.id == widget.chatId && c.isGroup)))
            IconButton(
            onPressed: () {
               ref.read(callControllerProvider.notifier).initiateCall(widget.chatId);
               Navigator.pushNamed(
                 context,
                 RouteNames.outgoingCall,
                 arguments: {
                   'receiverId': widget.chatId,
                   'receiverName': widget.chatName ?? 'User',
                 },
               );
            },
            icon: Icon(
              Icons.call_outlined,
              color: AppColors.primary,
              size: 24,
            ),
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

    // Reverse messages so Newest is at index 0 (Bottom)
    final reversedMessages = messages.reversed.toList();

    final currentMessageCount = messages.length;
    final newestMessage = messages.isNotEmpty ? messages.last : null; // Original list: Last is Newest

    // Check if new message was added (from other user or our own)
    // Only scroll if the NEWEST message is actually different (Real new message)
    // If count changed but newest message is same, it's a history load -> Don't scroll.

    if (currentMessageCount > _previousMessageCount &&
        newestMessage != null &&
        newestMessage.id != _lastNewestMessageId) {

      final isFromCurrentUser = newestMessage.senderId == currentUserId;

      // Auto-scroll for new messages
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // If from current user, always scroll
        if (isFromCurrentUser) {
          _scrollToBottom(force: true);
        } else {
          // Check if we are already near bottom (0.0)
          if (_scrollController.hasClients && _scrollController.position.pixels < 100) {
             _scrollToBottom(force: false);
          }
        }
      });
    }

    // Update trackers
    _previousMessageCount = currentMessageCount;
    _lastNewestMessageId = newestMessage?.id;

    // Build items: We iterate normally through reversedMessages (Newest -> Oldest)
    // Index 0 = Newest.
    // Date separator logic needs to compare with next item (which is older).

    final List<_MessageListItem> items = [];

    for (int i = 0; i < reversedMessages.length; i++) {
        items.add(_MessageListItem(isDateSeparator: false, messageIndex: i));

        // Date Separator Check
        // In reverse list:
        // Current (i) is NEWER than Next (i+1).
        // If (i) is last item (Oldest message), show date.
        // If (i) date != (i+1) date, show date for (i).

        bool showDate = false;
        if (i == reversedMessages.length - 1) {
          showDate = true;
        } else {
          final current = reversedMessages[i].timestamp.toLocal();
          final older = reversedMessages[i + 1].timestamp.toLocal();
          final currentDate = DateTime(current.year, current.month, current.day);
          final olderDate = DateTime(older.year, older.month, older.day);
          if (currentDate != olderDate) {
             showDate = true;
          }
        }

        if (showDate) {
           items.add(_MessageListItem(isDateSeparator: true, messageIndex: i));
        }
    }

    // Check if loading more
    final isLoadingMore = messageState.isLoadingMore[widget.chatId] ?? false;
    final hasMore = messageState.hasMore[widget.chatId] ?? false;

    // In reverse ListView:
    // Index 0 = Bottom (Newest).
    // Last Index = Top (Oldest).
    // So Loader should be appended to the END of the list (Visual Top).

    return ListView.builder(
      controller: _scrollController,
      reverse: true, // Key change for robustness
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // If hasMore, the loader is at the END (index == length)
        if (hasMore && index == items.length) {
          if (isLoadingMore) {
             return const Padding(
               padding: EdgeInsets.all(8.0),
               child: Center(child: SizedBox(
                 width: 24,
                 height: 24,
                 child: CircularProgressIndicator(strokeWidth: 2)
               )),
             );
          } else {
             // Manual Load Button
             return Padding(
               padding: const EdgeInsets.symmetric(vertical: 16.0),
               child: Center(
                 child: TextButton.icon(
                   onPressed: _loadMoreMessages,
                   icon: Icon(Icons.history, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                   label: Text(
                     "Load Previous Messages",
                     style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 12,
                     ),
                   ),
                   style: TextButton.styleFrom(
                     backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                   ),
                 ),
               ),
             );
          }
        }

        if (index >= items.length) return const SizedBox.shrink(); // Safety check

        final item = items[index];
        if (item.isDateSeparator) {
          // Use the timestamp of the message representing this day group
          return _buildDateSeparator(reversedMessages[item.messageIndex].timestamp, isDark);
        }

        final message = reversedMessages[item.messageIndex];
        final isCurrentUser = message.senderId == currentUserId;

        // Avatar logic for reversed list:
        // Show avatar if:
        // 1. Message it NOT current user
        // 2. AND (First Item (Newest) OR Previous Item (Newer) is different sender)
        // Wait, standard chat: Avatar is shown at the BOTTOM of the group.
        // In reverse list: BOTTOM is index 0.
        // So for message at 'i':
        // Show avatar if message 'i' sender != message 'i-1' sender (which is Newer/Below).
        // If i=0 (Newest/Bottom), show avatar.

        bool showAvatar = !isCurrentUser;
        if (showAvatar) {
           if (index > 0) {
             // Check the item "before" it in the list logic (which is visually BELOW it)
             // But 'items' contains separators too. We need to be careful.
             // Let's use reversedMessages indices.

             // Simple rule: Show avatar if it's the LAST message of a sequence from that user.
             // In reversed list, "LAST" visually means "First encountered when going up from bottom".
             // i.e. The Newer message (index - 1) is different sender.

             if (item.messageIndex > 0) {
                final newerMessage = reversedMessages[item.messageIndex - 1];
                if (newerMessage.senderId == message.senderId) {
                  showAvatar = false;
                }
             }
           }
        }

        return _buildMessageBubbleFromEntity(message, isDark, isCurrentUser, showAvatar);
      },
    );
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
                        else if (message.type == MessageType.voice)
                          _buildVoiceMessage(message, isCurrentUser)
                        else if (message.content != null) ...[
                          // Check if content is location JSON
                          Builder(
                            builder: (context) {
                              final location = _tryParseLocation(message.content!);
                              if (location != null) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "📍 Shared Location",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isCurrentUser ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      onPressed: () => _openMaps(location['lat']!, location['long']!),
                                      icon: const Icon(Icons.directions, size: 18),
                                      label: const Text("Get Directions"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isCurrentUser ? Colors.white : AppColors.primary,
                                        foregroundColor: isCurrentUser ? AppColors.primary : Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      ),
                                    ),
                                  ],
                                );
                              }

                              // Check if it's a link
                              final content = message.content!.trim();
                              if (content.startsWith('http')) {
                                final lowerContent = content.toLowerCase();
                                final isImageUrl = lowerContent.contains('res.cloudinary.com') ||
                                    lowerContent.endsWith('.jpg') ||
                                    lowerContent.endsWith('.jpeg') ||
                                    lowerContent.endsWith('.png') ||
                                    lowerContent.endsWith('.gif') ||
                                    lowerContent.endsWith('.webp');

                                if (isImageUrl) {
                                  return _buildImageMessage(message, isCurrentUser);
                                }

                                if (content.startsWith('https://')) {
                                  return _buildLinkPreview(content, isDark, isCurrentUser);
                                }
                              }

                              // Regular text
                              return Text(
                                message.content!,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: isCurrentUser ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                  height: 1.4,
                                ),
                              );
                            },
                          ),
                        ],
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
    // If type is image, content typically holds the URL as requested
    final imageUrl = message.content ?? message.mediaUrl;
    if (imageUrl == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
             // TODO: Open full screen image
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 200,
                height: 200,
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (context, url, error) => Container(
                width: 200,
                height: 150,
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildLinkPreview(String url, bool isDark, bool isCurrentUser) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AnyLinkPreview(
            link: url,
            displayDirection: UIDirection.uiDirectionVertical,
            bodyMaxLines: 3,
            placeholderWidget: Container(
              height: 100,
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: Container(
              height: 100,
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
              child: const Center(child: Icon(Icons.link, color: Colors.grey)),
            ),
            cache: const Duration(days: 7),
            backgroundColor: isDark ? Colors.grey[900]! : Colors.grey[100]!,
            titleStyle: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            bodyStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _handleOpenLink(url),
          child: Text(
            url,
            style: TextStyle(
              fontSize: 15,
              color: isCurrentUser ? Colors.white : AppColors.primary,
              decoration: TextDecoration.underline,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleOpenLink(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.inAppWebView, // Embedded view as requested
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $e')),
        );
      }
    }
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
    final localDate = date.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(localDate.year, localDate.month, localDate.day);

    final difference = today.difference(dateOnly).inDays;

    if (difference == 0) {
      text = 'Today';
    } else if (difference == 1) {
      text = 'Yesterday';
    } else if (difference < 7 && difference > 0) {
      text = DateFormat('EEE').format(localDate);
    } else {
      text = DateFormat('MMM d, y').format(localDate);
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
            // Attachment Button
            IconButton(
              onPressed: _showAttachmentMenu,
              icon: Icon(
                Icons.add_circle_outline,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                size: 26,
              ),
            ),
            const SizedBox(width: 4),
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
