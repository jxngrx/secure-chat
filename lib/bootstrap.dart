import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/config/env.dart';
import 'core/config/flavor.dart';
import 'core/constants/storage_keys.dart';
import 'core/services/background_service_manager.dart';
import 'core/storage/secure_storage.dart';
import 'core/utils/logger.dart';
import 'di/injection_container.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize app configuration
  AppConfig.initialize(
    environment: Environment.dev,
    flavor: Flavor.dev,
  );

  // Initialize dependency injection
  await InjectionContainer.init();

  // Initialize background services if user is already authenticated
  _initializeBackgroundServicesIfAuthenticated();

  // Run the app
  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}

/// Initialize background services if user is already authenticated
Future<void> _initializeBackgroundServicesIfAuthenticated() async {
  try {
    final secureStorage = InjectionContainer.resolve<SecureStorage>();
    final token = await secureStorage.read(StorageKeys.authToken);

    if (token != null && token.isNotEmpty) {
      // User is authenticated, initialize background services
      final backgroundServiceManager =
          InjectionContainer.resolve<BackgroundServiceManager>();
      await backgroundServiceManager.initializeServices();
    }
  } catch (e) {
    // Silently fail - services can be initialized later after login
    Logger.w('Error initializing background services on startup: $e');
  }
}
