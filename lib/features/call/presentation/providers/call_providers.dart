import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/call_repo_impl.dart';
import '../../domain/repositories/call_repository.dart';

/// Call repository provider
final callRepositoryProvider = Provider<CallRepository>((ref) {
  return CallRepositoryImpl.instance;
});
