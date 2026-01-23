import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/message_repository.dart';
import '../../domain/entities/message_entity.dart';
import '../../../chat/data/datasources/chat_socket_ds.dart';
import '../../../../core/utils/logger.dart';
import '../providers/message_providers.dart';

class MessageState {
  final Map<String, List<MessageEntity>> messages; // chatId -> messages
  final Map<String, bool> sending; // chatId -> sending state
  final String? error;

  MessageState({
    Map<String, List<MessageEntity>>? messages,
    Map<String, bool>? sending,
    this.error,
  })  : messages = messages ?? {},
        sending = sending ?? {};

  MessageState copyWith({
    Map<String, List<MessageEntity>>? messages,
    Map<String, bool>? sending,
    String? error,
    bool clearError = false,
  }) {
    return MessageState(
      messages: messages ?? this.messages,
      sending: sending ?? this.sending,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class MessageController extends StateNotifier<MessageState> {
  MessageController(
    this._repository,
    this._socketDataSource,
  ) : super(MessageState()) {
    _setupSocketListeners();
  }

  final MessageRepository _repository;
  final ChatSocketDataSource _socketDataSource;

  void _setupSocketListeners() {
    // Listen for message sent confirmation
    _socketDataSource.onMessageSent((data) {
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
          status: 'sent',
        );

        final currentMessages = Map<String, List<MessageEntity>>.from(state.messages);
        final chatMessages = List<MessageEntity>.from(currentMessages[message.chatId] ?? []);

        // Update or add message
        final index = chatMessages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          chatMessages[index] = message;
        } else {
          chatMessages.add(message);
          chatMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        }

        currentMessages[message.chatId] = chatMessages;
        state = state.copyWith(messages: currentMessages);
      } catch (e) {
        Logger.e('Error handling message sent confirmation', e);
      }
    });
  }

  Future<MessageEntity?> sendMessage({
    required String chatId,
    required String type,
    required String content,
    bool useSocket = false,
  }) async {
    state = state.copyWith(
      sending: {...state.sending, chatId: true},
      clearError: true,
    );

    try {
      MessageEntity message;

      if (useSocket) {
        // Send via Socket.IO
        _socketDataSource.sendMessage(
          chatId: chatId,
          type: type,
          content: content,
        );

        // Create optimistic message
        message = MessageEntity(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          chatId: chatId,
          senderId: '', // Will be set by backend
          content: content,
          type: type,
          timestamp: DateTime.now(),
          status: 'sending',
        );
      } else {
        // Send via REST API
        message = await _repository.sendMessage(
          chatId: chatId,
          type: type,
          content: content,
        );
      }

      // Add to local state
      final currentMessages = Map<String, List<MessageEntity>>.from(state.messages);
      final chatMessages = List<MessageEntity>.from(currentMessages[chatId] ?? []);
      chatMessages.add(message);
      chatMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      currentMessages[chatId] = chatMessages;

      state = state.copyWith(
        messages: currentMessages,
        sending: {...state.sending, chatId: false},
      );

      // Mark as delivered
      await _repository.markAsDelivered(chatId);

      return message;
    } catch (e) {
      Logger.e('Error sending message', e);
      state = state.copyWith(
        sending: {...state.sending, chatId: false},
        error: e.toString(),
      );
      return null;
    }
  }

  Future<void> loadMessages(String chatId, {int limit = 50, String? before}) async {
    try {
      final messages = await _repository.getChatMessages(
        chatId: chatId,
        limit: limit,
        before: before,
      );

      final currentMessages = Map<String, List<MessageEntity>>.from(state.messages);
      if (before == null) {
        // Replace messages
        currentMessages[chatId] = messages;
      } else {
        // Append messages
        final existing = currentMessages[chatId] ?? [];
        currentMessages[chatId] = [...existing, ...messages];
      }

      state = state.copyWith(messages: currentMessages);
    } catch (e) {
      Logger.e('Error loading messages', e);
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> markAsRead(String chatId) async {
    try {
      await _repository.markAsRead(chatId);
      _socketDataSource.markAsRead(chatId);
    } catch (e) {
      Logger.e('Error marking messages as read', e);
    }
  }

  Future<void> editMessage({
    required String messageId,
    required String chatId,
    required String content,
  }) async {
    try {
      final updatedMessage = await _repository.editMessage(
        messageId: messageId,
        content: content,
      );

      final currentMessages = Map<String, List<MessageEntity>>.from(state.messages);
      final chatMessages = List<MessageEntity>.from(currentMessages[chatId] ?? []);
      final index = chatMessages.indexWhere((m) => m.id == messageId);

      if (index != -1) {
        chatMessages[index] = updatedMessage;
        currentMessages[chatId] = chatMessages;
        state = state.copyWith(messages: currentMessages);
      }
    } catch (e) {
      Logger.e('Error editing message', e);
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteMessage({
    required String messageId,
    required String chatId,
    bool deleteForEveryone = false,
  }) async {
    try {
      await _repository.deleteMessage(
        messageId: messageId,
        deleteForEveryone: deleteForEveryone,
      );

      final currentMessages = Map<String, List<MessageEntity>>.from(state.messages);
      final chatMessages = List<MessageEntity>.from(currentMessages[chatId] ?? []);
      chatMessages.removeWhere((m) => m.id == messageId);
      currentMessages[chatId] = chatMessages;
      state = state.copyWith(messages: currentMessages);
    } catch (e) {
      Logger.e('Error deleting message', e);
      state = state.copyWith(error: e.toString());
    }
  }
}

/// Message controller provider
final messageControllerProvider = StateNotifierProvider<MessageController, MessageState>((ref) {
  final repository = ref.watch(messageRepositoryProvider);
  final socket = ref.watch(messageSocketProvider);
  return MessageController(repository, socket);
});
