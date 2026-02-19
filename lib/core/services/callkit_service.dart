import 'dart:async';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import '../utils/logger.dart';

class CallKitService {
  CallKitService._();
  static final CallKitService instance = CallKitService._();

  // Stream for call events
  final _callEventController = StreamController<CallEvent>.broadcast();
  Stream<CallEvent> get onCallEvent => _callEventController.stream;

  CallEvent? _lastEvent;
  CallEvent? get lastEvent => _lastEvent;

  Future<void> initialize() async {
    // Request permissions for Android 13+ and CallKit
    await FlutterCallkitIncoming.requestNotificationPermission({
      "rationaleMessage_permission_phone": "Phone permission is required to show call UI.",
      "rationaleMessage_permission_notification": "Notification permission is required to show outgoing call UI."
    });

    FlutterCallkitIncoming.onEvent.listen((event) {
      if (event != null) {
        Logger.d('CallKit Event: ${event.event} - Body: ${event.body}');
        _lastEvent = event;
        _callEventController.add(event);
      }
    });
  }

  Future<void> showIncomingCall({
    required String callId,
    required String callerName,
    required String callerId,
    String? avatar,
    String? handle,
    bool hasVideo = false,
  }) async {
    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'Chat App',
      avatar: avatar,
      handle: handle ?? callerName,
      type: 0, // 0 - Audio Call, 1 - Video Call
      duration: 45000, // 45 seconds ringing
      // Use "Open" as the accept text so it opens the app
      textAccept: 'Open',
      textDecline: 'Decline',
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: true,
        subtitle: 'Missed call',
        callbackText: 'Call back',
      ),
      extra: <String, dynamic>{'userId': callerId, 'callId': callId},
      headers: <String, dynamic>{'platform': 'flutter'},
      android: const AndroidParams(
        isCustomNotification: false,
        isShowLogo: true,
        ringtonePath: 'default',
        backgroundColor: '#0F0F1A',
        backgroundUrl: '',
        actionColor: '#4CAF50',
        isShowCallID: true,
        incomingCallNotificationChannelName: 'Incoming Calls',
        missedCallNotificationChannelName: 'Missed Calls',
        isShowFullLockedScreen: true,
        isImportant: true,
      ),
      ios: const IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: false,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: false,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  Future<void> endCall(String callId) async {
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (e) {
      Logger.e('CallKitService: Error ending call $callId', e);
    }
  }

  Future<void> endAllCalls() async {
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      Logger.e('CallKitService: Error ending all calls', e);
    }
  }
}
