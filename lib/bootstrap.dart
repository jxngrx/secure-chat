import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/config/env.dart';
import 'core/config/flavor.dart';
import 'core/constants/storage_keys.dart';
import 'core/services/background_service_manager.dart';
import 'core/services/fcm_service.dart';
import 'core/services/callkit_service.dart';
import 'core/storage/secure_storage.dart';
import 'core/utils/logger.dart';
import 'di/injection_container.dart';
import 'package:workmanager/workmanager.dart';
import 'core/services/background_task_handler.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (must be done before other services)
  // Note: You need to run 'flutterfire configure' first to generate firebase_options.dart
  try {
    // Try to initialize Firebase - will work if firebase_options.dart exists
    // If it doesn't exist, Firebase.initializeApp() will fail gracefully
    await Firebase.initializeApp();
    Logger.d('Firebase initialized successfully');
  } catch (e) {
    Logger.w('Firebase initialization skipped. Run "flutterfire configure" to set up Firebase.');
    Logger.w('FCM notifications will not work until Firebase is configured.');
    Logger.w('Error: $e');
    // Continue without Firebase - app will still work, just no push notifications
  }

  // Initialize app configuration
  AppConfig.initialize(
    environment: Environment.dev,
    flavor: Flavor.dev,
  );

  // Initialize dependency injection
  await InjectionContainer.init();

  // Initialize FCM service (can be done before auth)
  try {
    await FCMService.instance.initialize();
  } catch (e) {
    Logger.e('Error initializing FCM service', e);
    // Continue - FCM will retry later
  }

  // Initialize CallKitService
  try {
    await CallKitService.instance.initialize();
    Logger.d('CallKitService initialized');
  } catch (e) {
    Logger.e('Error initializing CallKitService', e);
  }

  // Initialize Workmanager
  try {
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
  } catch (e) {
    Logger.e('Error initializing Workmanager', e);
  }

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

      // Sync FCM token with backend on app open
      await FCMService.instance.syncTokenWithBackend();
    }
  } catch (e) {
    // Silently fail - services can be initialized later after login
    Logger.w('Error initializing background services on startup: $e');
  }
}
