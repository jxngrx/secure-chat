import 'package:flutter/material.dart';
import 'route_names.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/username_setup_screen.dart';
import '../../features/auth/presentation/screens/notification_permission_screen.dart';
import '../../features/contacts/presentation/screens/contact_sync_screen.dart';
import '../../features/chat/presentation/screens/chat_list_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/chat/presentation/screens/file_viewer_screen.dart';
import '../../features/chat/data/models/chat_item_model.dart';
import '../../features/chat/data/models/file_model.dart';
import '../../features/call/presentation/screens/calls_screen.dart';
import '../../features/contacts/presentation/screens/contacts_list_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/edit_profile_screen.dart';
import '../../features/user/presentation/screens/user_search_screen.dart';
import '../../features/call/presentation/screens/incoming_call_screen.dart';
import '../../features/call/presentation/screens/outgoing_call_screen.dart';
import '../../features/call/presentation/screens/active_call_screen.dart';

class AppRouteObserver extends NavigatorObserver {
  final ValueNotifier<String?> currentRoute = ValueNotifier<String?>(null);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentRoute.value = route.settings.name;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentRoute.value = previousRoute?.settings.name;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    currentRoute.value = newRoute?.settings.name;
  }
}

class AppRouter {
  AppRouter._();

  static final AppRouteObserver routeObserver = AppRouteObserver();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
      case RouteNames.splash:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
        );
      case RouteNames.welcome:
        return MaterialPageRoute(
          builder: (_) => const WelcomeScreen(),
        );
      case RouteNames.login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        );
      case RouteNames.register:
        return MaterialPageRoute(
          builder: (_) => const RegisterScreen(),
        );
      case RouteNames.usernameSetup:
        return MaterialPageRoute(
          builder: (_) => const UsernameSetupScreen(),
        );
      case RouteNames.notificationPermission:
        return MaterialPageRoute(
          builder: (_) => const NotificationPermissionScreen(),
        );
      case RouteNames.contactSync:
        return MaterialPageRoute(
          builder: (_) => const ContactSyncScreen(),
        );
      case RouteNames.chatList:
        return MaterialPageRoute(
          builder: (_) => const ChatListScreen(),
        );
      case RouteNames.chat:
        final args = settings.arguments;
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: args['chatId'] as String? ?? 'default',
              chatName: args['chatName'] as String?,
              chatAvatar: args['chatAvatar'] as String?,
              isOnline: args['isOnline'] as bool? ?? false,
            ),
          );
        } else if (args is String) {
          return MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: args,
              chatName: null,
              chatAvatar: null,
              isOnline: false,
            ),
          );
        }
        return MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: 'default',
            chatName: 'Chat',
            chatAvatar: null,
            isOnline: false,
          ),
        );
      case RouteNames.settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
        );
      case RouteNames.editProfile:
        return MaterialPageRoute(
          builder: (_) => const EditProfileScreen(),
        );
      case RouteNames.calls:
        return MaterialPageRoute(
          builder: (_) => const CallsScreen(),
        );
      case RouteNames.contacts:
        return MaterialPageRoute(
          builder: (_) => const ContactsListScreen(),
        );
      case RouteNames.userSearch:
        return MaterialPageRoute(
          builder: (_) => const UserSearchScreen(),
        );
      case RouteNames.incomingCall:
        return MaterialPageRoute(
          builder: (_) => const IncomingCallScreen(),
        );
      case RouteNames.outgoingCall:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => OutgoingCallScreen(
            receiverId: args['receiverId'] as String,
            receiverName: args['receiverName'] as String,
          ),
        );
      case RouteNames.activeCall:
        return MaterialPageRoute(
          builder: (_) => const ActiveCallScreen(),
        );
      case RouteNames.fileViewer:
        final file = settings.arguments;
        if (file is FileModel) {
          return MaterialPageRoute(
            builder: (_) => FileViewerScreen(file: file),
          );
        }
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('Invalid file data'),
            ),
          ),
        );
      default:
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Page Not Found'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Route not found',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${settings.name}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        RouteNames.splash,
                        (route) => false,
                      );
                    },
                    child: const Text('Go to Home'),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }
}
