import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/device_info_service.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/presentation/notifiers/auth_controller.dart';
import '../features/auth/presentation/notifiers/auth_state.dart';
import '../features/session/domain/repositories/session_repository.dart';
import 'injection_container.dart';

// Export chat and message providers (must be before declarations)
export '../features/chat/presentation/providers/chat_providers.dart';
export '../features/message/presentation/providers/message_providers.dart';
export '../features/chat/presentation/notifiers/chat_controller.dart';
export '../features/message/presentation/notifiers/message_controller.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return InjectionContainer.resolve<AuthRepository>();
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final sessionRepository = InjectionContainer.resolve<SessionRepository>();
  return AuthController(repository, sessionRepository);
});

final deviceInfoServiceProvider = Provider<DeviceInfoService>((ref) {
  return InjectionContainer.resolve<DeviceInfoService>();
});
