import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../domain/repositories/call_repository.dart';
import '../../data/repositories/call_repository_impl.dart';
import '../../../../core/services/agora_service.dart';
import '../../domain/entities/call_entity.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/permissions/permission_utils.dart';
import '../../../../di/injection_container.dart';
import '../../../../core/services/fcm_service.dart';
import '../../../../core/services/callkit_service.dart';
import '../../../../app.dart' show navigatorKey;
import '../../../../core/routing/route_names.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';

enum CallStatus {
  idle,
  initiating, // Caller is dialing
  ringing,    // Receiver sees incoming call
  connecting, // Call answered, setting up audio
  connected,  // Audio is live
  ended,
  rejected,
  error,
}

class CallState {
  final CallStatus status;
  final List<CallEntity> calls;
  final bool isLoading;
  final CallEntity? currentCall;
  final bool isCaller;
  final bool isMuted;
  final bool isSpeakerOn;
  final String? currentUserId;

  const CallState({
    this.status = CallStatus.idle,
    this.calls = const [],
    this.isLoading = false,
    this.currentCall,
    this.isCaller = false,
    this.isMuted = false,
    this.isSpeakerOn = false,
    this.currentUserId,
  });

  CallState copyWith({
    CallStatus? status,
    List<CallEntity>? calls,
    bool? isLoading,
    CallEntity? currentCall,
    bool? isCaller,
    bool? isMuted,
    bool? isSpeakerOn,
    String? currentUserId,
  }) {
    return CallState(
      status: status ?? this.status,
      calls: calls ?? this.calls,
      isLoading: isLoading ?? this.isLoading,
      currentCall: currentCall ?? this.currentCall,
      isCaller: isCaller ?? this.isCaller,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      currentUserId: currentUserId ?? this.currentUserId,
    );
  }
}

class CallController extends StateNotifier<CallState> {
  final CallRepository _repository;
  final AgoraService _agoraService = AgoraService.instance;

  String? _receiverId;
  String? _currentUserId;

  // Agora State
  String? _agoraToken;
  String? _agoraChannelId;
  String? _agoraUid;
  bool _agoraJoined = false; // Guard against double-join

  Timer? _callTimeoutTimer;
  bool _isRinging = false;

  // FIX ISSUE 5: Track subscriptions to prevent leaks/duplicates
  final List<StreamSubscription> _subscriptions = [];

  CallController(this._repository) : super(const CallState()) {
    _loadCurrentUserId();
    _setupSocketListeners();
    _setupAgoraListeners();
    _setupCallKitListeners();
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final localStorage = InjectionContainer.resolve<LocalStorage>();
      final userProfileJson = await localStorage.read(StorageKeys.userProfile);
      if (userProfileJson != null && userProfileJson.isNotEmpty) {
        final userProfile = jsonDecode(userProfileJson) as Map<String, dynamic>;
        _currentUserId = userProfile['id'] as String?;
        state = state.copyWith(currentUserId: _currentUserId);
        Logger.d('CallController: currentUserId=$_currentUserId');
      }
    } catch (e) {
      Logger.e('CallController: Error loading user ID', e);
    }
  }

  CallEntity? get currentCall => state.currentCall;
  bool get isCaller => state.isCaller;
  String? get currentUserId => _currentUserId;

  Future<void> toggleMute() async {
    final newMute = !state.isMuted;
    await _agoraService.setMicrophoneMute(newMute);
    state = state.copyWith(isMuted: newMute);
  }

  Future<void> toggleSpeaker() async {
    final newSpeaker = !state.isSpeakerOn;
    await _agoraService.setSpeakerphoneOn(newSpeaker);
    state = state.copyWith(isSpeakerOn: newSpeaker);
  }

  // ─── Socket Listeners ────────────────────────────────────────────────────────

  void _setupSocketListeners() {
    _subscriptions.add(_repository.onIncomingCall.listen(_handleIncomingCall));
    _subscriptions.add(_repository.onCallInitiated.listen(_handleCallInitiated));
    _subscriptions.add(_repository.onCallAnswered.listen(_handleCallAnswered));
    _subscriptions.add(_repository.onCallConnected.listen(_handleCallConnected));
    _subscriptions.add(_repository.onCallRejected.listen(_handleCallRejected));
    _subscriptions.add(_repository.onCallEnded.listen(_handleCallEnded));
    _subscriptions.add(_repository.onCallError.listen(_handleCallError));
    _subscriptions.add(FCMService.onCallReceived.listen(_handleFCMCallIncoming));
    Logger.d('CallController: Socket listeners registered');
  }

  // ─── Agora Listeners ─────────────────────────────────────────────────────────

  void _setupAgoraListeners() {
    _subscriptions.add(_agoraService.joinChannelSuccess.listen((channel) {
      Logger.d('CallController: Agora joined channel: $channel');
      _stopRingtone();
      if (state.status == CallStatus.connecting || state.status == CallStatus.initiating) {
        state = state.copyWith(status: CallStatus.connected);
      }
    }));

    _subscriptions.add(_agoraService.remoteUserJoined.listen((uid) {
      Logger.d('CallController: Remote user joined Agora: $uid');
      if (state.status != CallStatus.connected) {
        state = state.copyWith(status: CallStatus.connected);
      }
    }));

    _subscriptions.add(_agoraService.remoteUserOffline.listen((uid) {
      Logger.d('CallController: Remote user left Agora: $uid');
      if (state.status == CallStatus.connected) {
        endCall();
      }
    }));
  }

  // ─── CallKit Listeners ───────────────────────────────────────────────────────

  void _setupCallKitListeners() {
    _subscriptions.add(CallKitService.instance.onCallEvent.listen((event) async {
      Logger.d('CallController: CallKit event: ${event.event}');
      switch (event.event) {
        case Event.actionCallAccept:
          Logger.d('CallController: CallKit accept → opening IncomingCallScreen');
          navigatorKey.currentState?.pushNamed(RouteNames.incomingCall);
          break;
        case Event.actionCallDecline:
          Logger.d('CallController: CallKit decline → rejecting call');
          await rejectCall();
          break;
        case Event.actionCallEnded:
          Logger.d('CallController: CallKit ended');
          await endCall();
          break;
        case Event.actionCallTimeout:
          Logger.d('CallController: CallKit timeout');
          await endCall();
          break;
        default:
          break;
      }
    }));
  }

  // ─── Actions ─────────────────────────────────────────────────────────────────

  Future<void> loadCallHistory() async {
    state = state.copyWith(isLoading: true);
    try {
      final calls = await _repository.getCallHistory();
      state = state.copyWith(calls: calls, isLoading: false);
    } catch (e) {
      Logger.e('Error loading call history', e);
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> initiateCall(String receiverId) async {
    if (state.status != CallStatus.idle) {
      Logger.w('CallController: Cannot initiate - status=${state.status}');
      return false;
    }

    final authStatus = await FCMService.instance.checkPermission();
    if (authStatus != AuthorizationStatus.authorized &&
        authStatus != AuthorizationStatus.provisional) {
      final status = await FCMService.instance.initialize();
      if (status == AuthorizationStatus.authorized ||
          status == AuthorizationStatus.provisional) {
        await FCMService.instance.syncTokenWithBackend();
      }
    } else {
      await FCMService.instance.syncTokenWithBackend();
    }

    final hasPermission =
        await PermissionUtils.instance.checkAndRequestMicrophonePermission();
    if (!hasPermission) {
      Logger.w('CallController: Microphone permission denied');
      state = state.copyWith(status: CallStatus.error);
      _resetCallIn(const Duration(seconds: 2));
      return false;
    }

    Logger.d('CallController: Initiating call to $receiverId');
    try {
      state = state.copyWith(status: CallStatus.initiating, isCaller: true);
      _receiverId = receiverId;
      _agoraJoined = false;
      await _playRingtone('dialing');
      await _repository.initiateCall(receiverId);
      _startCallTimeout();
      return true;
    } catch (e) {
      Logger.e('CallController: Error initiating call', e);
      state = state.copyWith(status: CallStatus.error);
      _resetCallIn(const Duration(seconds: 2));
      return false;
    }
  }

  void _startCallTimeout() {
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = Timer(const Duration(seconds: 45), () {
      if (state.status == CallStatus.initiating ||
          state.status == CallStatus.ringing) {
        Logger.w('CallController: Call timed out');
        endCall();
      }
    });
  }

  void _stopCallTimeout() {
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = null;
  }

  Future<void> answerCall() async {
    if (state.currentCall == null) return;

    final hasPermission =
        await PermissionUtils.instance.checkAndRequestMicrophonePermission();
    if (!hasPermission) {
      Logger.w('CallController: Mic permission denied, rejecting');
      await rejectCall();
      return;
    }

    try {
      Logger.d('CallController: Answering call ${state.currentCall!.id}');
      await _stopRingtone();
      await CallKitService.instance.endAllCalls();

      state = state.copyWith(status: CallStatus.connecting);
      await _repository.answerCall(state.currentCall!.id);

      await _joinAgoraChannel();
    } catch (e) {
      Logger.e('Error answering call', e);
      state = state.copyWith(status: CallStatus.error);
      _resetCallIn(const Duration(seconds: 2));
    }
  }

  Future<void> rejectCall() async {
    Logger.d('CallController: Rejecting call');
    await _stopRingtone();
    await CallKitService.instance.endAllCalls();

    if (state.currentCall == null) {
      _resetCall();
      return;
    }
    try {
      await _repository.rejectCall(state.currentCall!.id);
      _resetCall();
    } catch (e) {
      Logger.e('Error rejecting call', e);
      _resetCall();
    }
  }

  Future<void> endCall() async {
    Logger.d('CallController: Ending call');
    await _stopRingtone();
    await CallKitService.instance.endAllCalls();

    if (state.currentCall == null) {
      _resetCall();
      return;
    }
    try {
      await _repository.endCall(state.currentCall!.id);
      _resetCall();
    } catch (e) {
      Logger.e('Error ending call', e);
      _resetCall();
    }
  }

  // ─── Socket Event Handlers ───────────────────────────────────────────────────

  void _handleIncomingCall(dynamic data) async {
    final incomingCallId = (data['callId'] ?? data['id'])?.toString() ?? '';
    Logger.d('CallController: call:incoming → callId=$incomingCallId');

    // FIX ISSUE 4: Handle duplicate events and auto-rejection race condition
    if (state.status != CallStatus.idle) {
       // If it's the SAME call, just ignore the duplicate socket event
       if (incomingCallId == state.currentCall?.id) {
         Logger.d('CallController: Ignoring duplicate incoming call event for $incomingCallId');
         return;
       }

       // If it's a DIFFERENT call, then we auto-reject because we're busy
       if (state.isCaller) {
          Logger.d('CallController: Busy in outgoing call, auto-rejecting incoming call $incomingCallId');
       } else {
          Logger.w('CallController: Already in call, auto-rejecting DIFFERENT incoming call $incomingCallId');
       }

       if (incomingCallId.isNotEmpty) _repository.rejectCall(incomingCallId);
       return;
    }

    // Ignore if we're actually the one who initiated this call (backup check)
    if (state.isCaller) return;

    // Store Agora config
    if (data['agora'] != null) {
      _agoraToken = data['agora']['token'];
      _agoraChannelId = data['agora']['channel'];
      _agoraUid = data['agora']['uid'];
      Logger.d('CallController: Receiver Agora config stored');
    }

    final callerId = (data['callerId'] ??
            (data['caller'] is Map ? data['caller']['id'] : null))
        ?.toString() ?? '';
    final callerName = data['callerName'] as String? ??
        (data['caller'] is Map ? data['caller']['username'] as String? : null);

    final call = CallEntity(
      id: incomingCallId,
      callerId: callerId,
      callerName: callerName,
      receiverId: _currentUserId ?? '',
      status: 'ringing',
      startTime: DateTime.now(),
    );

    state = state.copyWith(
      status: CallStatus.ringing,
      currentCall: call,
      isCaller: false,
    );
    _agoraJoined = false;
    await _playRingtone('incoming');
  }

  void _handleCallInitiated(dynamic data) {
    final socketCallId = (data['callId'] ?? data['id'])?.toString();
    Logger.d('CallController: call:initiated received for $socketCallId');

    // FIX ISSUE 5: Prevent duplicate processing if we already handled it
    if (state.currentCall?.id == socketCallId && state.status == CallStatus.initiating) {
      Logger.d('CallController: call:initiated already processed');
      return;
    }

    if (data['agora'] != null) {
      _agoraToken = data['agora']['token'];
      _agoraChannelId = data['agora']['channel'];
      _agoraUid = data['agora']['uid'];
      Logger.d('CallController: Caller Agora config stored');
    }

    if (socketCallId == null) return;

    final socketReceiverId = (data['receiverId'] ??
            (data['receiver'] is Map ? data['receiver']['id'] : null))
        ?.toString();
    final receiverName = data['receiver'] is Map
        ? data['receiver']['username'] as String?
        : null;

    final call = CallEntity(
      id: socketCallId,
      callerId: _currentUserId ?? '',
      receiverId: socketReceiverId ?? _receiverId ?? '',
      receiverName: receiverName,
      status: 'initiating',
      startTime: DateTime.now(),
    );

    state = state.copyWith(
      currentCall: call,
      isCaller: true,
      status: CallStatus.initiating,
    );
  }

  void _handleCallAnswered(dynamic data) {
    Logger.d('CallController: call:answered received! isCaller=${state.isCaller}');

    // Guard against duplicate processing or processing on wrong side
    if (state.status == CallStatus.connecting || state.status == CallStatus.connected) {
       Logger.d('CallController: Already connected/connecting, ignoring call:answered');
       return;
    }

    _stopCallTimeout();

    if (!state.isCaller) return;

    _stopRingtone();
    state = state.copyWith(status: CallStatus.connecting);
    _joinAgoraChannel();
  }

  void _handleCallConnected(dynamic data) {
    Logger.d('CallController: call:connected received');
    _stopRingtone();
    if (state.status != CallStatus.connected) {
      state = state.copyWith(status: CallStatus.connected);
    }
  }

  void _handleCallRejected(dynamic data) {
    Logger.d('CallController: call:rejected received');
    _stopCallTimeout();
    _stopRingtone();
    CallKitService.instance.endAllCalls();
    state = state.copyWith(status: CallStatus.rejected);
    _resetCallIn(const Duration(seconds: 2));
  }

  void _handleCallEnded(dynamic data) {
    Logger.d('CallController: call:ended received');
    _stopCallTimeout();
    _stopRingtone();
    CallKitService.instance.endAllCalls();
    state = state.copyWith(status: CallStatus.ended);
    _resetCallIn(const Duration(seconds: 2));
  }

  void _handleCallError(dynamic data) {
    Logger.e('CallController: call:error received: $data');
    _stopRingtone();
    CallKitService.instance.endAllCalls();
    state = state.copyWith(status: CallStatus.error);
    _resetCallIn(const Duration(seconds: 3));
  }

  // ─── Agora ───────────────────────────────────────────────────────────────────

  Future<void> _joinAgoraChannel() async {
    if (_agoraJoined) return;
    if (_agoraToken == null || _agoraChannelId == null || _agoraUid == null) {
      Logger.e('CallController: Cannot join Agora - missing config');
      return;
    }

    _agoraJoined = true;
    Logger.d('CallController: Joining Agora channel=$_agoraChannelId');
    await _agoraService.joinChannel(
      token: _agoraToken!,
      channelId: _agoraChannelId!,
      uid: _agoraUid!,
    );
  }

  // ─── Ringtone ────────────────────────────────────────────────────────────────

  Future<void> _stopRingtone() async {
    if (!_isRinging) return;
    _isRinging = false;
    try {
      await FlutterRingtonePlayer.stop();
    } catch (e) {
      try {
        await Future.delayed(const Duration(milliseconds: 100));
        await FlutterRingtonePlayer.stop();
      } catch (_) {}
    }
  }

  Future<void> _playRingtone(String type) async {
    await _stopRingtone();
    _isRinging = true;
    try {
      if (type == 'dialing') {
        await FlutterRingtonePlayer.play(
          android: AndroidSounds.notification,
          ios: IosSounds.glass,
          looping: true,
          volume: 0.3,
        );
      } else {
        await FlutterRingtonePlayer.playRingtone(looping: true);
      }
    } catch (e) {
      Logger.e('CallController: Error playing ringtone', e);
      _isRinging = false;
    }
  }

  // ─── Reset ───────────────────────────────────────────────────────────────────

  Future<void> _resetCall() async {
    _stopCallTimeout();
    _isRinging = false;
    _agoraJoined = false;
    await _stopRingtone();
    await CallKitService.instance.endAllCalls();
    await _agoraService.leaveChannel();

    _receiverId = null;
    _agoraToken = null;
    _agoraChannelId = null;
    _agoraUid = null;

    state = state.copyWith(
      currentCall: null,
      isCaller: false,
      status: CallStatus.idle,
      isMuted: false,
      isSpeakerOn: false,
    );
  }

  void _resetCallIn(Duration duration) {
    Future.delayed(duration, () => _resetCall());
  }

  void _handleFCMCallIncoming(Map<String, dynamic> data) {
    Logger.d('CallController: FCM call incoming: ${data['callId']}');
    _handleIncomingCall({
      'callId': data['callId'],
      'callerId': data['callerId'],
      'callerName': data['callerName'],
      'agora': {
        'token': data['agoraToken'],
        'channel': data['agoraChannel'],
        'uid': data['agoraUid'],
      },
    });
  }

  // FIX ISSUE 5: Cancel all subscriptions on dispose
  @override
  void dispose() {
    Logger.d('CallController: Disposing and canceling ${_subscriptions.length} subscriptions');
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _stopCallTimeout();
    _stopRingtone();
    super.dispose();
  }
}

final callRepositoryProvider = Provider<CallRepository>((ref) {
  return CallRepositoryImpl.instance;
});

final callControllerProvider =
    StateNotifierProvider<CallController, CallState>((ref) {
  final repo = ref.watch(callRepositoryProvider);
  return CallController(repo);
});
