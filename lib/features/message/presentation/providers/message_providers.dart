import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/message_repo_impl.dart';
import '../../domain/repositories/message_repository.dart';
import '../../../chat/data/datasources/chat_socket_ds.dart';

/// Message repository provider
final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepositoryImpl.instance;
});

/// Chat socket provider for message events
final messageSocketProvider = Provider<ChatSocketDataSource>((ref) {
  return ChatSocketDataSource.instance;
});
