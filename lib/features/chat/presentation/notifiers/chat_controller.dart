import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/entities/chat_entity.dart';
import '../../data/datasources/chat_socket_ds.dart';
import '../../../message/domain/entities/message_entity.dart';
import '../../../../core/utils/logger.dart';
import '../providers/chat_providers.dart';

class ChatState {
  final List<ChatEntity> chats;
  final bool isLoading;
  final String? error;
  final Map<String, List<MessageEntity>> messages; // chatId -> messages
  final Map<String, bool> loadingMessages; // chatId -> loading state
  final bool hasMore;
  final String? nextCursor;
  final bool isLoadingMore;

  ChatState({
    this.chats = const [],
    this.isLoading = false,
    this.error,
    Map<String, List<MessageEntity>>? messages,
    Map<String, bool>? loadingMessages,
    this.hasMore = false,
    this.nextCursor,
    this.isLoadingMore = false,
  })  : messages = messages ?? {},
        loadingMessages = loadingMessages ?? {};

  ChatState copyWith({
    List<ChatEntity>? chats,
    bool? isLoading,
    String? error,
    bool clearError = false,
    Map<String, List<MessageEntity>>? messages,
    Map<String, bool>? loadingMessages,
    bool? hasMore,
    String? nextCursor,
    bool? isLoadingMore,
  }) {
    return ChatState(
      chats: chats ?? this.chats,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      messages: messages ?? this.messages,
      loadingMessages: loadingMessages ?? this.loadingMessages,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  ChatState addMessage(String chatId, MessageEntity message) {
    final currentMessages = Map<String, List<MessageEntity>>.from(messages);
    final chatMessages = List<MessageEntity>.from(currentMessages[chatId] ?? []);

    // Check if message already exists
    if (!chatMessages.any((m) => m.id == message.id)) {
      chatMessages.add(message);
      chatMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      currentMessages[chatId] = chatMessages;
    }

    return copyWith(messages: currentMessages);
  }

  ChatState updateMessage(String chatId, MessageEntity updatedMessage) {
    final currentMessages = Map<String, List<MessageEntity>>.from(messages);
    final chatMessages = List<MessageEntity>.from(currentMessages[chatId] ?? []);

    final index = chatMessages.indexWhere((m) => m.id == updatedMessage.id);
    if (index != -1) {
      chatMessages[index] = updatedMessage;
      currentMessages[chatId] = chatMessages;
    }

    return copyWith(messages: currentMessages);
  }
}

class ChatController extends StateNotifier<ChatState> {
  ChatController(
    this._repository,
    this._socketDataSource,
  ) : super(ChatState()) {
    _setupSocketListeners();
    loadChats();
  }

  final ChatRepository _repository;
  final ChatSocketDataSource _socketDataSource;

  void _setupSocketListeners() {
    // Listen for new messages
    _socketDataSource.onNewMessage((data) {
      try {
        final message = MessageEntity(
          id: data['id'] as String? ?? '',
          chatId: data['chatId'] as String? ?? '',
          senderId: data['sender'] != null
              ? (data['sender'] as Map<String, dynamic>)['id'] as String? ?? ''
              : '',
          senderName: data['sender'] != null
              ? (data['sender'] as Map<String, dynamic>)['username'] as String?
              : null,
          content: data['content'] as String?,
          type: data['type'] as String? ?? 'text',
          timestamp: data['createdAt'] != null
              ? DateTime.tryParse(data['createdAt'] as String) ?? DateTime.now()
              : DateTime.now(),
          status: data['status'] as String? ?? 'sent',
        );

        // Update messages map (for snippet/internal use)
        // Note: ChatScreen largely uses MessageController, but this helps cache
        state = state.addMessage(message.chatId, message);

        // Update CHATS list (Home Screen)
        final currentChats = List<ChatEntity>.from(state.chats);
        final chatIndex = currentChats.indexWhere((c) => c.id == message.chatId);

        if (chatIndex != -1) {
          final chat = currentChats[chatIndex];
          // Remove from current position
          currentChats.removeAt(chatIndex);

          // Determine unread count logic (custom logic needed depending on if user is sender)
          // Ideally we check currentUserId, but for now we rely on backend 'unreadCount' or increment
          // if not us.
          // Since we don't have easy access to currentUserId here without async storage call...
          // We'll increment if it's incoming (basic heuristic) or rely on socket 'chat:updated'.

          final updatedChat = chat.copyWith(
            lastMessage: {
              'content': message.content,
              'type': message.type,
              'createdAt': message.timestamp.toIso8601String(),
              'sender': {
                 'id': message.senderId,
                 'username': message.senderName,
              },
            },
            lastMessageTime: message.timestamp,
            // If we are sender, unread count typically doesn't increase for us.
            // If receiver, it does.
            // Simplified: Just update content/time, let 'chat:updated' handle accurate counts if possible.
          );

          // Add to top
          currentChats.insert(0, updatedChat);

          state = state.copyWith(chats: currentChats);
        } else {
             // New chat? Fetch it or wait for 'chat:updated'
             loadChats();
        }

        // Auto-mark as delivered
        _socketDataSource.markAsDelivered(message.chatId);
      } catch (e) {
        Logger.e('Error handling new message from socket', e);
      }
    });

    // Listen for message read receipts
    _socketDataSource.onMessageRead((data) {
      try {
        final chatId = data['chatId'] as String?;
        if (chatId != null) {
          final currentMessages = state.messages[chatId] ?? [];
          final updatedMessages = currentMessages.map((msg) {
            if (msg.status != 'read') {
              return MessageEntity(
                id: msg.id,
                chatId: msg.chatId,
                senderId: msg.senderId,
                senderName: msg.senderName,
                senderAvatar: msg.senderAvatar,
                content: msg.content,
                type: msg.type,
                timestamp: msg.timestamp,
                status: 'read',
                editedAt: msg.editedAt,
                mediaUrl: msg.mediaUrl,
                mediaSize: msg.mediaSize,
                voiceDuration: msg.voiceDuration,
              );
            }
            return msg;
          }).toList();

          final updatedMessagesMap = Map<String, List<MessageEntity>>.from(state.messages);
          updatedMessagesMap[chatId] = updatedMessages;
          state = state.copyWith(messages: updatedMessagesMap);
        }
      } catch (e) {
        Logger.e('Error handling message read receipt', e);
      }
    });

    // Listen for chat updates
    _socketDataSource.onChatUpdated((data) {
      loadChats(); // Reload chats when updated
    });
  }

  Future<void> loadChats() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _repository.getChats();
      state = state.copyWith(
        chats: result.items,
        isLoading: false,
        hasMore: result.hasMore,
        nextCursor: result.nextCursor,
      );
    } catch (e) {
      Logger.e('Error loading chats', e);
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadMoreChats() async {
    if (state.isLoadingMore || !state.hasMore || state.nextCursor == null) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repository.getChats(
        before: state.nextCursor,
      );

      final currentChats = List<ChatEntity>.from(state.chats);
      currentChats.addAll(result.items);

      state = state.copyWith(
        chats: currentChats,
        isLoadingMore: false,
        hasMore: result.hasMore,
        nextCursor: result.nextCursor,
      );
    } catch (e) {
      Logger.e('Error loading more chats', e);
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  Future<ChatEntity?> createOrGetChat(String otherUserId) async {
    try {
      final chat = await _repository.createOrGetChat(otherUserId);
      await loadChats(); // Reload to include new chat
      return chat;
    } catch (e) {
      Logger.e('Error creating/getting chat', e);
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<void> loadMessages(String chatId, {int limit = 50, String? before}) async {
    state = state.copyWith(
      loadingMessages: {...state.loadingMessages, chatId: true},
    );

    try {
      final messages = await _repository.getMessages(chatId);
      final updatedMessages = Map<String, List<MessageEntity>>.from(state.messages);
      updatedMessages[chatId] = messages;

      state = state.copyWith(
        messages: updatedMessages,
        loadingMessages: {...state.loadingMessages, chatId: false},
      );
    } catch (e) {
      Logger.e('Error loading messages', e);
      state = state.copyWith(
        loadingMessages: {...state.loadingMessages, chatId: false},
        error: e.toString(),
      );
    }
  }

  void joinChat(String chatId) {
    _socketDataSource.joinChat(chatId);
  }

  void leaveChat(String chatId) {
    _socketDataSource.leaveChat(chatId);
  }

  Future<void> deleteChat(String chatId) async {
    try {
      await _repository.deleteChat(chatId);
      // Reload chats to remove the deleted one
      await loadChats();
    } catch (e) {
      Logger.e('Error deleting chat', e);
      rethrow;
    }
  }
}

/// Chat controller provider
final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  final socket = ref.watch(chatSocketProvider);
  return ChatController(repository, socket);
});
