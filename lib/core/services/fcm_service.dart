import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../network/api_client.dart';
import '../utils/logger.dart';
import '../storage/secure_storage.dart';
import '../constants/storage_keys.dart';
import '../../core/routing/route_names.dart';
import '../../app.dart' show navigatorKey;

/// Top-level function to handle background messages
/// Must be a top-level function (not a class method)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  Logger.d('FCM Background message received: ${message.messageId}');
  Logger.d('FCM Background message data: ${message.data}');
  Logger.d('FCM Background message notification: ${message.notification?.title}');
}

class FCMService {
  FCMService._();
  static final FCMService instance = FCMService._();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final ApiClient _apiClient = ApiClient.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  String? _currentFcmToken;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;

  /// Initialize FCM service
  /// Should be called after Firebase is initialized
  Future<void> initialize() async {
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
          if (response.payload != null) {
              // Handle notification tap from local notification
              // We can't access RemoteMessage directly here easily, but we can pass data in payload
              // Payload string can be identifying info.
          }
        },
      );

      // Create High Importance Channel for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel', // id
        'High Importance Notifications', // title
        description: 'This channel is used for important notifications.', // description
        importance: Importance.max,
      );

      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

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
    } catch (e) {
      Logger.e('Error initializing FCM', e);
    }
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
  Future<void> syncTokenWithBackend() async {
    if (_currentFcmToken == null) {
      _currentFcmToken = await _firebaseMessaging.getToken();
    }

    if (_currentFcmToken == null) {
      Logger.w('Cannot sync FCM token: token is null');
      return;
    }

    try {
      // Check if user is authenticated before syncing
      final secureStorage = SecureStorage.instance;
      final token = await secureStorage.read(StorageKeys.authToken);

      if (token != null && token.isNotEmpty) {
        Logger.d('Syncing FCM token with backend...');
        await _apiClient.put('/devices/fcm-token', {'fcmToken': _currentFcmToken});
        Logger.d('FCM token synced successfully');
      } else {
        Logger.d('Skipping FCM token sync: user not authenticated');
      }
    } catch (e) {
      Logger.e('Error syncing FCM token with backend', e);
    }
  }

  // ... (Token handling same)

  /// Set up foreground message handler
  void _setupForegroundMessageHandler() {
    _foregroundSubscription?.cancel();
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      Logger.d('FCM Foreground message received: ${message.messageId}');

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
    if (notification != null && android != null) {
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
                // Add color if needed
              ),
            ),
            payload: data['chatId'], // Pass chat ID if available
        );
    } else if (data['type'] == 'message') {
        // If data-only message (no notification block), construct one
        // This is common for chat apps to avoid double notification in background vs foreground
        // But backend usually sends notification block.
        // If your backend sends 'data' only, we construct it.
        String title = data['senderName'] ?? 'New Message';
        String body = data['content'] ?? 'You have a new message';

        // Don't show if simple text check fails or logic says so.
        // But requested is "Show it".

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
    }
  }

  /// Get current FCM token
  String? get currentToken => _currentFcmToken;

  /// Dispose resources
  void dispose() {
    _foregroundSubscription?.cancel();
  }
}
