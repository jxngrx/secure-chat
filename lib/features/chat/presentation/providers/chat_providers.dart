import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/chat_repo_impl.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../data/datasources/chat_socket_ds.dart';

/// Chat repository provider
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl.instance;
});

/// Chat socket data source provider
final chatSocketProvider = Provider<ChatSocketDataSource>((ref) {
  return ChatSocketDataSource.instance;
});
