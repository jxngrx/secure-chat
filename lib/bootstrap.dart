import 'package:flutter/material.dart';
import 'app.dart';
import 'core/config/app_config.dart';
import 'core/config/env.dart';
import 'core/config/flavor.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize app configuration
  AppConfig.initialize(
    environment: Environment.dev,
    flavor: Flavor.dev,
  );

  // Initialize dependency injection
  // TODO: Initialize DI container

  // Run the app
  runApp(const App());
}
