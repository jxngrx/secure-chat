import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/config/env.dart';
import 'core/config/flavor.dart';
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

  // Run the app
  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
