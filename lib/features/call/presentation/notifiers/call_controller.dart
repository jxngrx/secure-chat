import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/call_repository.dart';
import '../../domain/entities/call_entity.dart';
import '../../../../core/utils/logger.dart';
import '../providers/call_providers.dart';

class CallState {
  final List<CallEntity> calls;
  final bool isLoading;
  final String? error;

  CallState({
    this.calls = const [],
    this.isLoading = false,
    this.error,
  });

  CallState copyWith({
    List<CallEntity>? calls,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return CallState(
      calls: calls ?? this.calls,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CallController extends StateNotifier<CallState> {
  CallController(this._repository) : super(CallState()) {
    loadCallHistory();
  }

  final CallRepository _repository;

  Future<void> loadCallHistory({int limit = 50}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final calls = await _repository.getCallHistory(limit: limit);
      state = state.copyWith(calls: calls, isLoading: false);
    } catch (e) {
      Logger.e('Error loading call history', e);
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<CallEntity?> initiateCall(String receiverId) async {
    try {
      final call = await _repository.initiateCall(receiverId);
      await loadCallHistory(); // Reload to include new call
      return call;
    } catch (e) {
      Logger.e('Error initiating call', e);
      state = state.copyWith(error: e.toString());
      return null;
    }
  }
}

/// Call controller provider
final callControllerProvider = StateNotifierProvider<CallController, CallState>((ref) {
  final repository = ref.watch(callRepositoryProvider);
  return CallController(repository);
});
