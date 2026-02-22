import 'package:flutter/material.dart';
import 'core/routing/app_router.dart';
import 'core/routing/route_names.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'core/services/contact_sync_service.dart';
import 'core/utils/logger.dart';
import 'core/constants/storage_keys.dart';
import 'core/storage/secure_storage.dart';
import 'di/injection_container.dart';
import 'features/call/presentation/widgets/call_global_listener.dart';
import 'core/services/fcm_service.dart';

// Global navigator key for FCM notification navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // App came to foreground - sync contacts
      _syncContactsOnForeground();
    }
  }

  Future<void> _syncContactsOnForeground() async {
    try {
      // Check if user is authenticated
      final secureStorage = InjectionContainer.resolve<SecureStorage>();
      final authToken = await secureStorage.read(StorageKeys.authToken);

      if (authToken != null && authToken.isNotEmpty) {
        // User is authenticated, sync contacts silently
        Logger.d('App resumed - syncing contacts in background');
        await ContactSyncService.instance.syncContactsSilently();
      }
    } catch (e) {
      Logger.w('Error syncing contacts on app resume: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: AppStrings.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      onGenerateRoute: AppRouter.generateRoute,
      initialRoute: RouteNames.splash,
      navigatorObservers: [AppRouter.routeObserver],
      builder: (context, child) {
        return CallGlobalListener(child: child!);
      },
    );
  }
}
