import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/message_repository.dart';
import '../../domain/entities/message_entity.dart';
import '../../../chat/data/datasources/chat_socket_ds.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../di/injection_container.dart';
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
    // Listen for new messages (from other users or our own messages via broadcast)
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
          status: 'delivered',
        );

        final currentMessages = Map<String, List<MessageEntity>>.from(state.messages);
        final chatMessages = List<MessageEntity>.from(currentMessages[message.chatId] ?? []);

        // Check if message already exists by ID
        final existingByIdIndex = chatMessages.indexWhere((m) => m.id == message.id);
        if (existingByIdIndex != -1) {
          // Message already exists, just update it
          chatMessages[existingByIdIndex] = message;
          currentMessages[message.chatId] = chatMessages;
          state = state.copyWith(messages: currentMessages);
          return;
        }

        // Check if this is our own message that we sent optimistically
        // Match by content, type, and timestamp (within 5 seconds)
        int? optimisticIndex;
        for (int i = 0; i < chatMessages.length; i++) {
          final existing = chatMessages[i];
          if (existing.id.startsWith('temp_') &&
              existing.content == message.content &&
              existing.type == message.type &&
              existing.senderId == message.senderId &&
              (existing.timestamp.difference(message.timestamp).inSeconds.abs() < 5)) {
            optimisticIndex = i;
            break;
          }
        }

        if (optimisticIndex != null) {
          // Replace optimistic message with real message from server
          chatMessages[optimisticIndex] = message;
        } else {
          // New message from other user, add it
          chatMessages.add(message);
          chatMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        }

        currentMessages[message.chatId] = chatMessages;
        state = state.copyWith(messages: currentMessages);
      } catch (e) {
        Logger.e('Error handling new message from socket', e);
      }
    });

    // Listen for message sent confirmation
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

        // Try to find optimistic message by matching content and timestamp (within 5 seconds)
        // This handles the case where optimistic message has temp ID but real message has backend ID
        int? optimisticIndex;
        for (int i = 0; i < chatMessages.length; i++) {
          final existing = chatMessages[i];
          if (existing.id.startsWith('temp_') &&
              existing.content == message.content &&
              existing.type == message.type &&
              existing.senderId == message.senderId &&
              (existing.timestamp.difference(message.timestamp).inSeconds.abs() < 5)) {
            optimisticIndex = i;
            break;
          }
        }

        if (optimisticIndex != null) {
          // Replace optimistic message with real message
          chatMessages[optimisticIndex] = message;
        } else {
          // Check if message already exists by ID
          final existingIndex = chatMessages.indexWhere((m) => m.id == message.id);
          if (existingIndex != -1) {
            // Update existing message
            chatMessages[existingIndex] = message;
          } else {
            // Add new message (shouldn't happen for sent messages, but handle it)
            chatMessages.add(message);
            chatMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          }
        }

        currentMessages[message.chatId] = chatMessages;
        state = state.copyWith(messages: currentMessages);
      } catch (e) {
        Logger.e('Error handling message sent confirmation', e);
      }
    });

    // Listen for message deleted event
    _socketDataSource.onMessageDeleted((data) {
      try {
        final messageId = data['messageId'] as String;
        final chatId = data['chatId'] as String;
        final deleteForEveryone = data['deleteForEveryone'] as bool? ?? false;
        final sentUserMessageIsDeleted = data['sentUserMessageIsDeleted'] as bool? ?? false;
        final receiveUserMessageIsDeleted = data['receiveUserMessageIsDeleted'] as bool? ?? false;

        // Get current user ID (synchronously since we might not await here inside callback)
        // Ideally we should have userId in state or accessible synchronously
        // For now, we update the message entity in the list

        final currentMessages = Map<String, List<MessageEntity>>.from(state.messages);
        final chatMessages = List<MessageEntity>.from(currentMessages[chatId] ?? []);
        final index = chatMessages.indexWhere((m) => m.id == messageId);

        if (index != -1) {
          final oldMessage = chatMessages[index];

          if (deleteForEveryone) {
            // Update message to show as deleted
            chatMessages[index] = MessageEntity(
              id: oldMessage.id,
              chatId: oldMessage.chatId,
              senderId: oldMessage.senderId,
              senderName: oldMessage.senderName,
              senderAvatar: oldMessage.senderAvatar,
              content: 'This message was deleted', // Placeholder content
              type: oldMessage.type,
              timestamp: oldMessage.timestamp,
              status: oldMessage.status,
              editedAt: oldMessage.editedAt,
              mediaUrl: oldMessage.mediaUrl,
              mediaSize: oldMessage.mediaSize,
              voiceDuration: oldMessage.voiceDuration,
              deleteForEveryone: true,
              sentUserMessageIsDeleted: true, // Sender deleted for everyone implies this
              receiveUserMessageIsDeleted: receiveUserMessageIsDeleted,
            );
          } else {
            // "Delete for me" only logic is tricky without knowing "me".
            // The socket event should ideally only come if it affects "me" or everyone.
            // If we receive this event, it means the message metadata changed.
            // We should update the tags.
            // The UI will determine if it should be hidden based on the tags and currentUserId.

            chatMessages[index] = MessageEntity(
              id: oldMessage.id,
              chatId: oldMessage.chatId,
              senderId: oldMessage.senderId,
              senderName: oldMessage.senderName,
              senderAvatar: oldMessage.senderAvatar,
              content: oldMessage.content,
              type: oldMessage.type,
              timestamp: oldMessage.timestamp,
              status: oldMessage.status,
              editedAt: oldMessage.editedAt,
              mediaUrl: oldMessage.mediaUrl,
              mediaSize: oldMessage.mediaSize,
              voiceDuration: oldMessage.voiceDuration,
              deleteForEveryone: false,
              sentUserMessageIsDeleted: sentUserMessageIsDeleted,
              receiveUserMessageIsDeleted: receiveUserMessageIsDeleted,
            );

            // NOTE: We don't remove it here because we don't know "who" deleted it relative to "us" (sender/receiver)
            // inside this callback easily without async profile fetch.
            // The UI will filter it out if needed.
          }

          currentMessages[chatId] = chatMessages;
          state = state.copyWith(messages: currentMessages);
        }
      } catch (e) {
        Logger.e('Error handling message deleted event', e);
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
      String? optimisticId;

      if (useSocket) {
        // Get current user ID for optimistic message (async, but don't wait)
        String? currentUserId;
        final localStorage = InjectionContainer.resolve<LocalStorage>();
        localStorage.read(StorageKeys.userProfile).then((userProfileJson) {
          if (userProfileJson != null && userProfileJson.isNotEmpty) {
            try {
              final userProfile = jsonDecode(userProfileJson) as Map<String, dynamic>;
              currentUserId = userProfile['id'] as String?;
            } catch (e) {
              Logger.w('Could not parse user profile: $e');
            }
          }
        }).catchError((e) {
          Logger.w('Could not get current user ID: $e');
        });

        // Create optimistic message IMMEDIATELY (synchronously) for instant UI feedback
        optimisticId = 'temp_${DateTime.now().millisecondsSinceEpoch}_${content.hashCode}';
        final now = DateTime.now();
        message = MessageEntity(
          id: optimisticId,
          chatId: chatId,
          senderId: '', // Will be updated when we get user ID
          content: content,
          type: type,
          timestamp: now,
          status: 'sending',
        );

        // Add optimistic message to state IMMEDIATELY
        final currentMessages = Map<String, List<MessageEntity>>.from(state.messages);
        final chatMessages = List<MessageEntity>.from(currentMessages[chatId] ?? []);
        chatMessages.add(message);
        chatMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        currentMessages[chatId] = chatMessages;

        state = state.copyWith(
          messages: currentMessages,
          sending: {...state.sending, chatId: false},
        );

        // Get user ID and update optimistic message
        try {
          final userProfileJson = await localStorage.read(StorageKeys.userProfile);
          if (userProfileJson != null && userProfileJson.isNotEmpty) {
            final userProfile = jsonDecode(userProfileJson) as Map<String, dynamic>;
            currentUserId = userProfile['id'] as String?;

            // Update optimistic message with user ID
            final updatedMessages = Map<String, List<MessageEntity>>.from(state.messages);
            final updatedChatMessages = List<MessageEntity>.from(updatedMessages[chatId] ?? []);
            final optimisticIndex = updatedChatMessages.indexWhere((m) => m.id == optimisticId);
            if (optimisticIndex != -1 && currentUserId != null && currentUserId!.isNotEmpty) {
              updatedChatMessages[optimisticIndex] = MessageEntity(
                id: optimisticId,
                chatId: chatId,
                senderId: currentUserId!,
                content: content,
                type: type,
                timestamp: now,
                status: 'sending',
              );
              updatedMessages[chatId] = updatedChatMessages;
              state = state.copyWith(messages: updatedMessages);
            }
          }
        } catch (e) {
          Logger.w('Could not get current user ID for optimistic message: $e');
        }

        // Send via Socket.IO (non-blocking)
        _socketDataSource.sendMessage(
          chatId: chatId,
          type: type,
          content: content,
        );
      } else {
        // Send via REST API
        message = await _repository.sendMessage(
          chatId: chatId,
          type: type,
          content: content,
        );

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
      }

      // Mark as delivered (non-blocking for Socket.IO)
      if (!useSocket) {
        await _repository.markAsDelivered(chatId);
      }

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
      final index = chatMessages.indexWhere((m) => m.id == messageId);

      if (index != -1) {
        final oldMessage = chatMessages[index];
        // We need to know who "we" are to know if we are sender or receiver
        // But since we initiated the delete action, we know we are the deleter.
        // However, we don't have our ID here easy access synchronously to check against senderId.

        // Optimistic update:
        // We will assume backend returns success and socket event will eventually come to sync.
        // For now, we update local state to reflect what we expect.

        if (deleteForEveryone) {
           chatMessages[index] = MessageEntity(
            id: oldMessage.id,
            chatId: oldMessage.chatId,
            senderId: oldMessage.senderId,
            senderName: oldMessage.senderName,
            senderAvatar: oldMessage.senderAvatar,
            content: 'This message was deleted',
            type: oldMessage.type,
            timestamp: oldMessage.timestamp,
            status: oldMessage.status,
            editedAt: oldMessage.editedAt,
            mediaUrl: oldMessage.mediaUrl,
            mediaSize: oldMessage.mediaSize,
            voiceDuration: oldMessage.voiceDuration,
            deleteForEveryone: true,
            sentUserMessageIsDeleted: true, // If we can delete for everyone, we must be sender
            receiveUserMessageIsDeleted: oldMessage.receiveUserMessageIsDeleted,
          );
        } else {
          // Delete for me
          // We mark it as deleted by "us".
          // But we don't know if we are sender or receiver easily without user ID.
          // However, the UI filters messages based on these tags + currentUserId.
          // Since we can't easily set the correct "IsDeleted" tag without knowing if we are sender/receiver,
          // and we can't easily remove it from list because we don't want to break index if request fails...
          // A safer bet is to remove it from the list entirely for "delete for me" locally,
          // matching what the user expects: "it's gone".
          // If the page refreshes, the backend will return the correct tags and the UI will filter it then.

          chatMessages.removeAt(index);
        }
      }

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
