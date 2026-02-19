import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../network/api_client.dart';
import '../utils/logger.dart';
import '../storage/secure_storage.dart';
import '../constants/storage_keys.dart';
import '../../core/routing/route_names.dart';
import '../../app.dart' show navigatorKey;
import 'callkit_service.dart';

/// Top-level function to handle background messages
/// Must be a top-level function (not a class method)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Flutter binding is initialized for platform channels
  WidgetsFlutterBinding.ensureInitialized();

  Logger.d('FCM Background message received: ${message.messageId}');
  Logger.d('FCM Background message data: ${message.data}');

  if (message.data['type'] == 'call_incoming') {
    // Notify about incoming call via static stream
    FCMService.emitCallReceived(message.data);

    // Show native incoming call UI via CallKit
    // We use the singleton instance which is safe here as it doesn't depend on complex app state
    final data = message.data;
    final callId = data['callId'];
    if (callId == null) {
      Logger.e('FCM Background: callId is null, cannot show call UI');
      return;
    }

    await CallKitService.instance.showIncomingCall(
      callId: callId,
      callerName: data['callerName'] ?? 'Unknown Caller',
      callerId: data['callerId'] ?? 'unknown',
      avatar: data['callerAvatar'],
      hasVideo: data['isVideo'] == 'true',
    );
  }
}

// We need to move this logic effectively.
// Let's update `FCMService` class first.


class FCMService {
  FCMService._();
  static final FCMService instance = FCMService._();

  static final _callStreamController = StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get onCallReceived => _callStreamController.stream;

  static void emitCallReceived(Map<String, dynamic> data) {
    _callStreamController.add(data);
  }

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final ApiClient _apiClient = ApiClient.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  String? _currentFcmToken;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;

  /// Initialize FCM service
  /// Should be called after Firebase is initialized
  Future<AuthorizationStatus> initialize() async {
    try {
      // Initialize Local Notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _handleLocalNotificationTap(response);
        },
      );

      // Create High Importance Channel for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel', // id
        'High Importance Notifications', // title
        description: 'This channel is used for important notifications.', // description
        importance: Importance.max,
        enableLights: true,
        ledColor: Colors.blue,
      );

      // Create Dedicated Call Channel for Android
      const AndroidNotificationChannel callChannel = AndroidNotificationChannel(
        'calls_channel', // id
        'Incoming Calls', // title
        description: 'This channel is used for incoming call notifications.', // description
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Colors.green,
      );

      final androidPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.createNotificationChannel(channel);
      await androidPlugin?.createNotificationChannel(callChannel);

      // Request notification permissions
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      Logger.d('FCM Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get the token
        _currentFcmToken = await _firebaseMessaging.getToken();
        Logger.d('FCM Token: $_currentFcmToken');

        // Sync immediately if we can
        syncTokenWithBackend();

        _setupForegroundMessageHandler();
        _setupOnTokenRefresh();

        // Listen for when the app is opened from a notification when terminated
        final initialMessage = await _firebaseMessaging.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationTap(initialMessage);
        }

        // Listen for when the app is opened from a notification when in background
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      } else {
        Logger.w('FCM permission denied');
      }
      return settings.authorizationStatus;
    } catch (e) {
      Logger.e('Error initializing FCM', e);
      return AuthorizationStatus.notDetermined;
    }
  }

  /// Check current notification permission status
  Future<AuthorizationStatus> checkPermission() async {
    final settings = await _firebaseMessaging.getNotificationSettings();
    return settings.authorizationStatus;
  }

  /// Set up token refresh listener
  void _setupOnTokenRefresh() {
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      _currentFcmToken = newToken;
      Logger.d('FCM Token refreshed: $newToken');
      syncTokenWithBackend();
    });
  }

  /// Sync FCM token with backend
  Future<String> syncTokenWithBackend() async {
    Logger.d('FCMService: syncTokenWithBackend called');
    try {
      _currentFcmToken ??= await _firebaseMessaging.getToken();
      Logger.d('FCMService: Retrieved token: $_currentFcmToken');
    } catch (e) {
      Logger.e('FCMService: Error getting FCM token', e);
      return 'Error retrieving token: $e';
    }

    if (_currentFcmToken == null) {
      Logger.w('FCMService: Cannot sync FCM token: token is null');
      return 'Token is NULL';
    }

    try {
      // Check if user is authenticated before syncing
      final secureStorage = SecureStorage.instance;
      final token = await secureStorage.read(StorageKeys.authToken);
      Logger.d('FCMService: Auth Check - Token present: ${token != null && token.isNotEmpty}');

      if (token != null && token.isNotEmpty) {
        Logger.d('FCMService: Syncing FCM token with backend...');
        final start = DateTime.now();
        await _apiClient.put('/devices/fcm-token', {'fcmToken': _currentFcmToken});
        final end = DateTime.now();
        Logger.d('FCMService: FCM token synced successfully in ${end.difference(start).inMilliseconds}ms');
        return 'Success: Synced in ${end.difference(start).inMilliseconds}ms';
      } else {
        Logger.d('FCMService: Skipping FCM token sync: user not authenticated');
        return 'Skipped: Not Authenticated';
      }
    } catch (e) {
      Logger.e('FCMService: Error syncing FCM token with backend', e);
      return 'Sync Error: $e';
    }
  }

  /// Set up foreground message handler
  void _setupForegroundMessageHandler() {
    _foregroundSubscription?.cancel();
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      Logger.d('FCM Foreground message received: ${message.messageId}');

      if (message.data['type'] == 'call_incoming') {
        FCMService.emitCallReceived(message.data);
      }

      // Handle foreground notification (Show Local Notification)
      _handleForegroundNotification(message);
    });
  }

  /// Handle foreground notification
  void _handleForegroundNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;
    Map<String, dynamic> data = message.data;

    // Only show if we have a notification payload or it's a message type
    if (data['type'] == 'call_incoming') {
      showCallNotification(message);
    } else if (notification != null && android != null) {
        _flutterLocalNotificationsPlugin.show(
            id: notification.hashCode,
            title: notification.title,
            body: notification.body,
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                'high_importance_channel',
                'High Importance Notifications',
                channelDescription: 'This channel is used for important notifications.',
                icon: android.smallIcon,
                priority: Priority.max,
                importance: Importance.max,
              ),
            ),
            payload: data['chatId'],
        );
    } else if (data['type'] == 'message') {
        String title = data['senderName'] ?? 'New Message';
        String body = data['content'] ?? 'You have a new message';

        _flutterLocalNotificationsPlugin.show(
            id: message.hashCode,
            title: title,
            body: body,
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'high_importance_channel',
                'High Importance Notifications',
                channelDescription: 'This channel is used for important notifications.',
                icon: '@mipmap/ic_launcher',
                priority: Priority.max,
                importance: Importance.max,
              ),
            ),
             payload: data['chatId'],
        );
    }
  }

  /// Show a high-priority call notification
  Future<void> showCallNotification(RemoteMessage message) async {
    final data = message.data;
    final callerName = data['callerName'] ?? 'Someone';

    // Use CallKit for standard incoming call experience
    await CallKitService.instance.showIncomingCall(
      callId: data['callId'],
      callerName: callerName,
      callerId: data['callerId'] ?? 'unknown',
      avatar: data['callerAvatar'],
      hasVideo: data['isVideo'] == 'true',
    );
  }

  /// Handle local notification tap (from FlutterLocalNotificationsPlugin)
  void _handleLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    Logger.d('FCM Local notification tapped with payload: $payload');

    // Handle call notification tap - payload format: "call:{callId}"
    if (payload.startsWith('call:')) {
      final callId = payload.substring(5); // Remove "call:" prefix
      Logger.d('Processing call notification tap for callId: $callId');

      // Emit call received event so CallController can handle it
      // Note: We don't have full call data here, but the callId is enough
      // The CallController should already have the call state from the socket
      FCMService.emitCallReceived({
        'callId': callId,
        'callerId': '', // Will be filled by existing socket data
        'callerName': 'Incoming Call',
      });

      // Navigate to incoming call screen
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamed(RouteNames.incomingCall);
        Logger.d('Navigated to incoming call screen from notification tap');
      } else {
        Logger.w('Cannot navigate: navigatorKey.currentState is null');
      }
    } else if (payload.startsWith('chat:')) {
      // Handle chat notification tap - payload format: "chat:{chatId}"
      final chatId = payload.substring(5);
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamed(
          RouteNames.chat,
          arguments: {
            'chatId': chatId,
            'chatName': null, // Will be loaded by chat screen
            'chatAvatar': null,
            'isOnline': false,
          },
        );
        Logger.d('Navigated to chat: $chatId');
      }
    } else {
       // Legacy payload support (direct chatId)
       final chatId = payload;
       if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamed(
          RouteNames.chat,
          arguments: {
            'chatId': chatId,
            'chatName': null,
            'chatAvatar': null,
            'isOnline': false,
          },
        );
        Logger.d('Navigated to chat (legacy): $chatId');
      }
    }
  }

  /// Handle notification tap (app opened from notification)
  void _handleNotificationTap(RemoteMessage message) {
    Logger.d('FCM Notification tapped: ${message.messageId}');
    final data = message.data;

    if (data['type'] == 'message') {
      final chatId = data['chatId'] as String?;
      if (chatId != null && navigatorKey.currentContext != null) {
        // Navigate to chat screen using global navigator key
        Navigator.of(navigatorKey.currentContext!).pushNamed(
          RouteNames.chat,
          arguments: {
            'chatId': chatId,
            'chatName': data['senderName'] as String?,
            'chatAvatar': null,
            'isOnline': false,
          },
        );
        Logger.d('Navigated to chat: $chatId');
      }
    } else if (data['type'] == 'call_incoming') {
      // Direct call incoming - emit to stream so CallController picks it up
      FCMService.emitCallReceived(data);

      if (navigatorKey.currentContext != null) {
        Navigator.of(navigatorKey.currentContext!).pushNamed(RouteNames.incomingCall);
      }
    }
  }

  /// Get current FCM token
  String? get currentToken => _currentFcmToken;

  /// Dispose resources
  void dispose() {
    _foregroundSubscription?.cancel();
  }
}
