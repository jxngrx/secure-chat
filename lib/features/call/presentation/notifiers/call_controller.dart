import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../../domain/repositories/call_repository.dart';
import '../../data/repositories/call_repository_impl.dart';
import '../../../../core/services/webrtc_service.dart';
import '../../domain/entities/call_entity.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../di/injection_container.dart';

enum CallStatus {
  idle,
  initiating, // Dialing
  ringing,    // Incoming
  connecting,
  connected,
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
  final WebRTCService _webRTCService = WebRTCService.instance;

  String? _receiverId;
  String? _currentUserId;
  DateTime? _lastCallInitiationTime; // Track when we last initiated a call
  final List<Map<String, dynamic>> _iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ];

  CallController(this._repository) : super(const CallState()) {
    _loadCurrentUserId();
    _setupListeners();
  }

  /// Load current user ID from local storage
  Future<void> _loadCurrentUserId() async {
    try {
      final localStorage = InjectionContainer.resolve<LocalStorage>();
      final userProfileJson = await localStorage.read(StorageKeys.userProfile);
      if (userProfileJson != null && userProfileJson.isNotEmpty) {
        final userProfile = jsonDecode(userProfileJson) as Map<String, dynamic>;
        _currentUserId = userProfile['id'] as String?;
        state = state.copyWith(currentUserId: _currentUserId);
        Logger.d('CallController: Loaded current user ID: $_currentUserId');
      }
    } catch (e) {
      Logger.e('CallController: Error loading current user ID', e);
    }
  }

  // Getters for compatibility
  CallEntity? get currentCall => state.currentCall;
  bool get isCaller => state.isCaller;
  String? get currentUserId => _currentUserId;

  Future<void> toggleMute() async {
    final newMuteStatus = !state.isMuted;
    await _webRTCService.setMicrophoneMute(newMuteStatus);
    state = state.copyWith(isMuted: newMuteStatus);
  }

  Future<void> toggleSpeaker() async {
    final newSpeakerStatus = !state.isSpeakerOn;
    await _webRTCService.setSpeakerphoneOn(newSpeakerStatus);
    state = state.copyWith(isSpeakerOn: newSpeakerStatus);
  }

  void _setupListeners() {
    _repository.onIncomingCall.listen(_handleIncomingCall);
    _repository.onCallInitiated.listen(_handleCallInitiated);
    _repository.onCallAnswered.listen(_handleCallAnswered);
    _repository.onCallConnected.listen(_handleCallConnected);
    _repository.onCallRejected.listen(_handleCallRejected);
    _repository.onCallEnded.listen(_handleCallEnded);

    _repository.onWebRTCOffer.listen(_handleWebRTCOffer);
    _repository.onWebRTCAnswer.listen(_handleWebRTCAnswer);
    _repository.onWebRTCIceCandidate.listen(_handleWebRTCIceCandidate);
  }

  // --- Actions ---

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

  Future<void> initiateCall(String receiverId) async {
    if (state.status != CallStatus.idle) {
      Logger.w('CallController: Cannot initiate call - not idle (status: ${state.status})');
      return;
    }

    Logger.d('CallController: Initiating call to $receiverId (currentUserId: $_currentUserId)');

    try {
      // CRITICAL: Set isCaller to true FIRST before any other state changes
      // This ensures that if call:incoming arrives, it will be ignored
      state = state.copyWith(
        status: CallStatus.initiating,
        isCaller: true, // Mark as caller immediately
      );
      _receiverId = receiverId;
      _lastCallInitiationTime = DateTime.now(); // Track when we initiated

      // Play ringing sound (dialing tone for caller)
      await _playRingtone('dialing');

      // Call REST API and process response immediately
      final response = await _repository.initiateCall(receiverId);

      Logger.d('CallController: Call initiation response received: $response');

      // Extract call data from REST API response
      // Handle both string and ObjectId formats
      String callId = '';
      if (response['id'] != null) {
        callId = response['id'].toString();
      } else if (response['_id'] != null) {
        callId = response['_id'].toString();
      }

      // Extract receiverId from response
      String responseReceiverId = receiverId; // Default to parameter
      if (response['receiver'] != null) {
        final receiverData = response['receiver'] as Map<String, dynamic>?;
        if (receiverData != null && receiverData['id'] != null) {
          responseReceiverId = receiverData['id'].toString();
        }
      }

      // Extract status
      final status = response['status'] as String? ?? 'ringing';

      // Extract createdAt
      DateTime startTime = DateTime.now();
      if (response['createdAt'] != null) {
        final createdAtStr = response['createdAt'].toString();
        final parsedTime = DateTime.tryParse(createdAtStr);
        if (parsedTime != null) {
          startTime = parsedTime;
        }
      }

      // Create CallEntity from REST response immediately
      // This ensures callId is available even if socket event is delayed or missing
      final call = CallEntity(
        id: callId,
        callerId: _currentUserId ?? '', // We are the caller
        receiverId: responseReceiverId,
        status: status,
        startTime: startTime,
      );

      // Update state with callId immediately from REST response
      // Socket event will arrive as backup/confirmation but we don't wait for it
      state = state.copyWith(
        currentCall: call,
        status: CallStatus.initiating,
        isCaller: true,
      );

      Logger.d('CallController: Call state updated from REST response - callId: $callId, receiverId: $responseReceiverId, isCaller: ${state.isCaller}, initiatedAt: $_lastCallInitiationTime');
    } catch (e) {
      Logger.e('CallController: Error initiating call', e);
      state = state.copyWith(status: CallStatus.error);
      _resetCallIn(const Duration(seconds: 2));
    }
  }

  Future<void> answerCall() async {
    if (state.currentCall == null) return;

    try {
      state = state.copyWith(status: CallStatus.connecting);

      await _stopRingtone();
      await _repository.answerCall(state.currentCall!.id);

      await _initializeWebRTC(CallRole.receiver);

      // State updates to connected when onCallConnected fires or WebRTC connects
    } catch (e) {
      Logger.e('Error answering call', e);
      state = state.copyWith(status: CallStatus.error);
      _resetCallIn(const Duration(seconds: 2));
    }
  }

  Future<void> rejectCall() async {
    // CRITICAL: Stop ringtone immediately
    await _stopRingtone();

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
    // CRITICAL: Stop ringtone immediately when ending call
    await _stopRingtone();

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

  // --- Event Handlers ---

  void _handleIncomingCall(dynamic data) async {
    // data: { callId, callerId, rtcConfig }
    final callId = data['callId'] as String?;
    final callerId = data['callerId'] as String?;

    Logger.d('CallController: Received call:incoming event - callId: $callId, callerId: $callerId, currentUserId: $_currentUserId, isCaller: ${state.isCaller}, status: ${state.status}, lastInitiation: $_lastCallInitiationTime, receiverId: $_receiverId');

    // CRITICAL FIX #-1: If we have a receiverId set, we initiated a call - ALWAYS ignore incoming calls
    if (_receiverId != null && _receiverId!.isNotEmpty) {
      Logger.w('CallController: BLOCKING call:incoming - we have receiverId set (we initiated a call to $_receiverId)');
      return;
    }

    // CRITICAL FIX #0: If we recently initiated a call (within last 10 seconds), we're definitely the caller - ignore
    if (_lastCallInitiationTime != null) {
      final timeSinceInitiation = DateTime.now().difference(_lastCallInitiationTime!);
      if (timeSinceInitiation.inSeconds < 10) {
        Logger.w('CallController: Ignoring call:incoming - we initiated a call ${timeSinceInitiation.inSeconds}s ago (we are the caller)');
        return;
      }
    }

    // CRITICAL FIX #1: If we're already initiating a call, we're definitely the caller - ignore this event
    if (state.status == CallStatus.initiating) {
      Logger.w('CallController: Ignoring call:incoming - status is initiating (we are the caller)');
      return;
    }

    // CRITICAL FIX #2: If we're already in a call as the caller, ignore
    if (state.isCaller) {
      Logger.w('CallController: Ignoring call:incoming - already in call as caller (callId: $callId, currentCallId: ${state.currentCall?.id})');
      return;
    }

    // CRITICAL FIX #2.5: If currentUserId is not loaded yet, try to load it now
    if (_currentUserId == null) {
      Logger.d('CallController: currentUserId is null, attempting to load it');
      await _loadCurrentUserId();
      Logger.d('CallController: Loaded currentUserId: $_currentUserId');
    }

    // CRITICAL FIX #3: Check if callerId matches our current user ID (even if _currentUserId is null, we can still check isCaller)
    if (_currentUserId != null && callerId != null) {
      // Normalize both IDs to strings for comparison
      final normalizedCurrentUserId = _currentUserId!.trim();
      final normalizedCallerId = callerId.trim();

      if (normalizedCurrentUserId == normalizedCallerId) {
        Logger.w('CallController: Ignoring call:incoming - callerId matches currentUserId (callId: $callId, callerId: $normalizedCallerId, currentUserId: $normalizedCurrentUserId)');
        return;
      }
    }

    // CRITICAL FIX #4: If we have a current call and it's from us initiating, ignore
    if (state.currentCall != null && state.isCaller) {
      Logger.w('CallController: Ignoring call:incoming - have active call as caller');
      return;
    }

    if (state.status != CallStatus.idle) {
      // Busy - reject the call
      Logger.d('CallController: Busy, rejecting incoming call (callId: $callId, currentStatus: ${state.status})');
      if (callId != null) {
        _repository.rejectCall(callId);
      }
      return;
    }

    Logger.d('CallController: Processing incoming call - callId: $callId, callerId: $callerId, currentUserId: $_currentUserId');

    // FINAL SAFETY CHECK: Double-check we're not the caller before setting status to ringing
    if (state.isCaller || state.status == CallStatus.initiating) {
      Logger.w('CallController: FINAL CHECK FAILED - Ignoring call:incoming (isCaller: ${state.isCaller}, status: ${state.status})');
      return;
    }

    final call = CallEntity(
      id: callId ?? '',
      callerId: callerId ?? '',
      receiverId: '', // We are receiver
      status: 'ringing',
      startTime: DateTime.now(),
    );

    if (data['rtcConfig'] != null && data['rtcConfig']['iceServers'] != null) {
       // Parse ice servers
    }

    // Only set status to ringing if we're absolutely sure we're the receiver
    state = state.copyWith(
      status: CallStatus.ringing,
      currentCall: call,
      isCaller: false, // Explicitly set to false to ensure we're marked as receiver
    );
    _playRingtone('incoming');

    Logger.d('CallController: Incoming call state set - callId: $callId, isCaller: ${state.isCaller}');
  }

  void _handleCallInitiated(dynamic data) {
    // data: { callId, receiverId, rtcConfig? }
    final socketCallId = data['callId'] as String?;
    final socketReceiverId = data['receiverId'] as String?;

    Logger.d('CallController: Received call:initiated event - callId: $socketCallId, receiverId: $socketReceiverId, isCaller: ${state.isCaller}, currentCallId: ${state.currentCall?.id}');

    if (!state.isCaller) {
      Logger.w('CallController: Ignoring call:initiated - not caller (callId: $socketCallId, isCaller: ${state.isCaller})');
      return;
    }

    // If we already have a currentCall from REST response, treat socket event as confirmation/backup
    // Only update if callId matches (confirmation) or if we don't have a callId yet (backup)
    if (state.currentCall != null && state.currentCall!.id.isNotEmpty) {
      if (socketCallId == state.currentCall!.id) {
        Logger.d('CallController: call:initiated socket event confirms REST response - callId: $socketCallId (already set)');
        // Optionally update receiverId if it's more complete from socket
        if (socketReceiverId != null && socketReceiverId.isNotEmpty && socketReceiverId != state.currentCall!.receiverId) {
          final updatedCall = CallEntity(
            id: state.currentCall!.id,
            callerId: state.currentCall!.callerId,
            receiverId: socketReceiverId,
            status: state.currentCall!.status,
            startTime: state.currentCall!.startTime,
            endTime: state.currentCall!.endTime,
            isVideo: state.currentCall!.isVideo,
          );
          state = state.copyWith(currentCall: updatedCall);
          Logger.d('CallController: Updated receiverId from socket event - new receiverId: $socketReceiverId');
        }
        return; // Already have callId from REST, just confirm
      } else {
        Logger.w('CallController: call:initiated socket event has different callId - ignoring (REST callId: ${state.currentCall!.id}, socket callId: $socketCallId)');
        return; // Different callId, ignore
      }
    }

    // Backup: If we don't have currentCall yet (shouldn't happen with REST response, but handle gracefully)
    Logger.d('CallController: Setting call from socket event (backup path) - callId: $socketCallId');
    final call = CallEntity(
      id: socketCallId ?? '',
      callerId: _currentUserId ?? '', // We are caller
      receiverId: socketReceiverId ?? _receiverId ?? '',
      status: 'initiating',
      startTime: DateTime.now(),
    );

    state = state.copyWith(
      currentCall: call,
    );

    Logger.d('CallController: Call initiated state updated from socket - callId: ${call.id}, receiverId: ${call.receiverId}');
  }

  void _handleCallAnswered(dynamic data) {
    if (state.isCaller) {
      _stopRingtone(); // Stop dialing sound
      _initializeWebRTC(CallRole.caller);
      state = state.copyWith(status: CallStatus.connecting);
    }
  }

  void _handleCallConnected(dynamic data) {
    _stopRingtone(); // Ensure ringtone is stopped
    state = state.copyWith(status: CallStatus.connected);
  }

  void _handleCallRejected(dynamic data) {
    state = state.copyWith(status: CallStatus.rejected);
    _stopRingtone();
    _resetCallIn(const Duration(seconds: 2));
  }

  void _handleCallEnded(dynamic data) {
    state = state.copyWith(status: CallStatus.ended);
    _stopRingtone();
    _resetCall();
  }

  // --- WebRTC ---

  Future<void> _initializeWebRTC(CallRole role) async {
    try {
      await _webRTCService.initialize(iceServers: _iceServers);

      // Listen for ICE candidates
      _webRTCService.iceCandidates.listen((candidate) {
        if (state.currentCall != null) {
          _repository.sendWebRTCIceCandidate(
            state.currentCall!.id,
            _webRTCService.iceCandidateToMap(candidate),
            state.isCaller ? state.currentCall!.receiverId : state.currentCall!.callerId,
          );
        }
      });

      _webRTCService.connectionState.listen((connState) {
        if (connState == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
           state = state.copyWith(status: CallStatus.connected);
        } else if (connState == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
           endCall();
        }
      });

      if (role == CallRole.caller) {
        final offer = await _webRTCService.createOffer();
        _repository.sendWebRTCOffer(
          state.currentCall!.id,
          _webRTCService.sessionDescriptionToMap(offer),
          state.currentCall!.receiverId,
        );
      }
    } catch (e) {
      Logger.e('Error initializing WebRTC', e);
      endCall();
    }
  }

  void _handleWebRTCOffer(dynamic data) {
    if (state.isCaller) return;
    if (state.status != CallStatus.connecting && state.status != CallStatus.ringing) return;

    final offerMap = data['offer'];
    final callId = data['callId'];

    if (offerMap != null) {
      final offer = _webRTCService.mapToSessionDescription(offerMap);
      _webRTCService.setRemoteDescription(offer).then((_) async {
        final answer = await _webRTCService.createAnswer();
        _repository.sendWebRTCAnswer(
          callId,
          _webRTCService.sessionDescriptionToMap(answer),
          data['callerId'],
        );
      });
    }
  }

  void _handleWebRTCAnswer(dynamic data) {
    if (!state.isCaller) return;

    final answerMap = data['answer'];
    if (answerMap != null) {
      final answer = _webRTCService.mapToSessionDescription(answerMap);
      _webRTCService.setRemoteDescription(answer);
    }
  }

  void _handleWebRTCIceCandidate(dynamic data) {
    final candidateMap = data['candidate'];
    if (candidateMap != null) {
      final candidate = _webRTCService.mapToIceCandidate(candidateMap);
      _webRTCService.addIceCandidate(candidate);
    }
  }

  Future<void> _stopRingtone() async {
    try {
      await FlutterRingtonePlayer.stop();
      Logger.d('CallController: Ringtone stopped');
    } catch (e) {
      Logger.e('CallController: Error stopping ringtone', e);
      // Try again after a short delay
      try {
        await Future.delayed(const Duration(milliseconds: 100));
        await FlutterRingtonePlayer.stop();
      } catch (e2) {
        Logger.e('CallController: Failed to stop ringtone on retry', e2);
      }
    }
  }

  Future<void> _playRingtone(String type) async {
    try {
      // Stop any existing ringtone first
      await _stopRingtone();

      if (type == 'dialing') {
         Logger.d('CallController: Playing dialing feedback');
         // Use a more appropriate sound for dialing - notification is usually less intrusive than ringtone
         await FlutterRingtonePlayer.play(
            android: AndroidSounds.notification,
            ios: IosSounds.glass,
            looping: true,
            volume: 0.3,
         );
      } else {
        // Incoming call
        Logger.d('CallController: Playing incoming call ringtone');
        await FlutterRingtonePlayer.playRingtone(looping: true);
      }
    } catch (e) {
      Logger.e('CallController: Error playing ringtone', e);
    }
  }

  void _resetCall() {
    _webRTCService.close();
    _lastCallInitiationTime = null; // Reset initiation time
    _receiverId = null; // Reset receiver ID
    _stopRingtone(); // Ensure ringtone is stopped
    // Don't reset state to idle instantly if we want to show "Ended" screen
    state = state.copyWith(
      currentCall: null,
      isCaller: false,
      status: CallStatus.idle,
    );
  }

  void _resetCallIn(Duration duration) {
    Future.delayed(duration, () {
      _resetCall();
    });
  }

  @override
  void dispose() {
    _stopRingtone(); // Ensure it stops
    super.dispose();
  }
}

final callRepositoryProvider = Provider<CallRepository>((ref) {
  return CallRepositoryImpl.instance;
});

final callControllerProvider = StateNotifierProvider<CallController, CallState>((ref) {
  final repo = ref.watch(callRepositoryProvider);
  return CallController(repo);
});
