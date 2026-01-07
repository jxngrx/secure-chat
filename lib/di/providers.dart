import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/device_info_service.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/presentation/notifiers/auth_controller.dart';
import '../features/auth/presentation/notifiers/auth_state.dart';
import 'injection_container.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return InjectionContainer.resolve<AuthRepository>();
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(repository);
});

final deviceInfoServiceProvider = Provider<DeviceInfoService>((ref) {
  return InjectionContainer.resolve<DeviceInfoService>();
});
