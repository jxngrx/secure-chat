import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../../domain/repositories/call_repository.dart';
import '../../data/repositories/call_repository_impl.dart';
import '../../../../core/services/webrtc_service.dart';
import '../../domain/entities/call_entity.dart';
import '../../../../core/utils/logger.dart';

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

  const CallState({
    this.status = CallStatus.idle,
    this.calls = const [],
    this.isLoading = false,
    this.currentCall,
    this.isCaller = false,
  });

  CallState copyWith({
    CallStatus? status,
    List<CallEntity>? calls,
    bool? isLoading,
    CallEntity? currentCall,
    bool? isCaller,
  }) {
    return CallState(
      status: status ?? this.status,
      calls: calls ?? this.calls,
      isLoading: isLoading ?? this.isLoading,
      currentCall: currentCall ?? this.currentCall,
      isCaller: isCaller ?? this.isCaller,
    );
  }
}

class CallController extends StateNotifier<CallState> {
  final CallRepository _repository;
  final WebRTCService _webRTCService = WebRTCService.instance;

  String? _receiverId;
  final List<Map<String, dynamic>> _iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ];

  CallController(this._repository) : super(const CallState()) {
    _setupListeners();
  }

  // Getters for compatibility
  CallEntity? get currentCall => state.currentCall;
  bool get isCaller => state.isCaller;

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
    if (state.status != CallStatus.idle) return;

    try {
      state = state.copyWith(
        status: CallStatus.initiating,
        isCaller: true,
      );
      _receiverId = receiverId;

      // Play ringing sound
      await _playRingtone('dialing');

      await _repository.initiateCall(receiverId);
    } catch (e) {
      Logger.e('Error initiating call', e);
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
    if (state.currentCall == null) return;

    try {
      await _stopRingtone();
      await _repository.rejectCall(state.currentCall!.id);
      _resetCall();
    } catch (e) {
      Logger.e('Error rejecting call', e);
      _resetCall();
    }
  }

  Future<void> endCall() async {
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

  void _handleIncomingCall(dynamic data) {
    // data: { callId, callerId, rtcConfig }
    if (state.status != CallStatus.idle) {
      // Busy
      if (data['callId'] != null) {
        _repository.rejectCall(data['callId']);
      }
      return;
    }

    final call = CallEntity(
      id: data['callId'],
      callerId: data['callerId'],
      receiverId: '', // We are receiver
      status: 'ringing',
      startTime: DateTime.now(),
    );

    if (data['rtcConfig'] != null && data['rtcConfig']['iceServers'] != null) {
       // Parse ice servers
    }

    state = state.copyWith(
      status: CallStatus.ringing,
      currentCall: call,
      isCaller: false,
    );
    _playRingtone('incoming');
  }

  void _handleCallInitiated(dynamic data) {
    // data: { callId, receiverId }
    if (!state.isCaller) return;

    final call = CallEntity(
      id: data['callId'],
      callerId: '', // We are caller
      receiverId: data['receiverId'],
      status: 'initiating',
      startTime: DateTime.now(),
    );

    state = state.copyWith(
      currentCall: call,
    );
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
    } catch (e) {
      Logger.e('Error stopping ringtone', e);
    }
  }

  Future<void> _playRingtone(String type) async {
    try {
      if (type == 'dialing') {
         // Play a shorter notification or standard ringtone for dialing if desired
         // There isn't a direct "dialing" sound in system ringtones usually,
         // often apps use a custom file or just Silence/UI sound.
         // For now using notification sound as a placeholder or could loop ringtone.
         // Standard behavior: Caller hears ringing.
         await FlutterRingtonePlayer.play(
            android: AndroidSounds.ringtone,
            ios: IosSounds.glass, // or another appropriate sound
            looping: true,
            volume: 0.5, // slightly lower for feedback
         );
      } else {
        // Incoming call
        await FlutterRingtonePlayer.playRingtone(looping: true);
      }
    } catch (e) {
      Logger.e('Error playing ringtone', e);
    }
  }

  void _resetCall() {
    _webRTCService.close();
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
