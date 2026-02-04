import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../core/utils/logger.dart';

enum CallRole {
  caller,
  receiver,
}

class WebRTCService {
  WebRTCService._();
  static final WebRTCService instance = WebRTCService._();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // ICE Buffering
  bool _isRemoteDescriptionSet = false;
  final List<RTCIceCandidate> _bufferedIceCandidates = [];

  // Stream controllers
  final _localStreamController = StreamController<MediaStream>.broadcast();
  final _remoteStreamController = StreamController<MediaStream>.broadcast();
  final _iceCandidateController = StreamController<RTCIceCandidate>.broadcast();
  final _connectionStateController = StreamController<RTCPeerConnectionState>.broadcast();
  final _iceConnectionStateController = StreamController<RTCIceConnectionState>.broadcast();

  Stream<MediaStream> get localStream => _localStreamController.stream;
  Stream<MediaStream> get remoteStream => _remoteStreamController.stream;
  Stream<RTCIceCandidate> get iceCandidates => _iceCandidateController.stream;
  Stream<RTCPeerConnectionState> get connectionState => _connectionStateController.stream;
  Stream<RTCIceConnectionState> get iceConnectionState => _iceConnectionStateController.stream;

  MediaStream? get localStreamValue => _localStream;
  MediaStream? get remoteStreamValue => _remoteStream;

  Future<void> initialize({
    required List<Map<String, dynamic>> iceServers,
  }) async {
    Logger.d('WebRTC: Initializing service with strict AUDIO-ONLY constraints');

    // Reset state
    _isRemoteDescriptionSet = false;
    _bufferedIceCandidates.clear();

    // Create peer connection with Unified Plan
    final configuration = {
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan', // Enforce Unified Plan
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
    };

    final constraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': false, // STRICTLY NO VIDEO
      },
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ],
    };

    try {
      _peerConnection = await createPeerConnection(configuration, constraints);
      Logger.d('WebRTC: PeerConnection created');

      // Setup event listeners
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        Logger.d('WebRTC: Generated ICE candidate: ${candidate.candidate}');
        _iceCandidateController.add(candidate);
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        Logger.d('WebRTC: Connection state changed: $state');
        _connectionStateController.add(state);
      };

      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        Logger.d('WebRTC: ICE connection state changed: $state');
        _iceConnectionStateController.add(state);
      };

      _peerConnection!.onSignalingState = (RTCSignalingState state) {
        Logger.d('WebRTC: Signaling state changed: $state');
      };

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        Logger.d('WebRTC: Remote track received: ${event.track.kind}');
        if (event.track.kind == 'video') {
           Logger.w('WebRTC: Ignored unexpected remote VIDEO track');
           return;
        }
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          _remoteStreamController.add(_remoteStream!);
        }
      };

      // Get local media stream (STRICT AUDIO ONLY)
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false, // ABSOLUTELY NO VIDEO
      });
      Logger.d('WebRTC: Local audio stream obtained');

      // Add audio track to peer connection via Transceiver for better control
      _localStream!.getAudioTracks().forEach((track) {
        _peerConnection!.addTransceiver(
          track: track,
          init: RTCRtpTransceiverInit(
            direction: TransceiverDirection.SendRecv,
            streams: [_localStream!],
          ),
        );
      });
      Logger.d('WebRTC: Audio transceiver added');

      _localStreamController.add(_localStream!);
    } catch (e) {
      Logger.e('WebRTC: Error during initialization', e);
      await close();
      rethrow;
    }
  }

  Future<RTCSessionDescription> createOffer({bool iceRestart = false}) async {
    if (_peerConnection == null) throw Exception('Peer connection not initialized');

    try {
      // Ensure no video transceivers exist before offering
      final transceivers = await _peerConnection!.transceivers;
      for (var t in transceivers) {
        if (t.sender.track?.kind == 'video' || t.receiver.track?.kind == 'video') {
          Logger.w('WebRTC: Found video transceiver, stopping it');
          await t.stop();
        }
      }

      final constraints = {
        'mandatory': {
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo': false,
          'IceRestart': iceRestart,
        },
        'optional': [],
      };

      Logger.d('WebRTC: Creating offer (iceRestart: $iceRestart)');
      final offer = await _peerConnection!.createOffer(constraints);

      Logger.d('WebRTC: Created Offer. SDP has video? ${offer.sdp!.contains('m=video')}');

      await _peerConnection!.setLocalDescription(offer);
      return offer;
    } catch (e) {
      Logger.e('WebRTC: Error creating offer', e);
      rethrow;
    }
  }

  Future<RTCSessionDescription> createAnswer() async {
    if (_peerConnection == null) throw Exception('Peer connection not initialized');

    try {
      final constraints = {
        'mandatory': {
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo': false,
        },
        'optional': [],
      };

      final answer = await _peerConnection!.createAnswer(constraints);
      Logger.d('WebRTC: Created Answer');

      await _peerConnection!.setLocalDescription(answer);
      return answer;
    } catch (e) {
      Logger.e('WebRTC: Error creating answer', e);
      rethrow;
    }
  }

  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    if (_peerConnection == null) throw Exception('Peer connection not initialized');

    try {
      Logger.d('WebRTC: Setting remote description (${description.type})');
      await _peerConnection!.setRemoteDescription(description);
      _isRemoteDescriptionSet = true;
      Logger.d('WebRTC: Remote description set');

      // Flush buffered candidates
      if (_bufferedIceCandidates.isNotEmpty) {
        Logger.d('WebRTC: Flushing ${_bufferedIceCandidates.length} buffered ICE candidates');
        for (final candidate in _bufferedIceCandidates) {
          await _peerConnection!.addCandidate(candidate);
        }
        _bufferedIceCandidates.clear();
      }
    } catch (e) {
      Logger.e('WebRTC: Error setting remote description', e);
      rethrow;
    }
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    if (_peerConnection == null) throw Exception('Peer connection not initialized');

    if (!_isRemoteDescriptionSet) {
      Logger.d('WebRTC: Buffering ICE candidate (remote description not set)');
      _bufferedIceCandidates.add(candidate);
    } else {
      try {
        await _peerConnection!.addCandidate(candidate);
        Logger.d('WebRTC: Added ICE candidate');
      } catch (e) {
        Logger.e('WebRTC: Error adding ICE candidate', e);
      }
    }
  }

  Future<void> setSpeakerphoneOn(bool enabled) async {
    try {
      await Helper.setSpeakerphoneOn(enabled);
      Logger.d('WebRTC: Speakerphone set to $enabled');
    } catch (e) {
      Logger.e('WebRTC: Error setting speakerphone', e);
    }
  }

  Future<void> setMicrophoneMute(bool muted) async {
    try {
      if (_localStream != null) {
        final tracks = _localStream!.getAudioTracks();
        for (var track in tracks) {
          track.enabled = !muted;
        }
        Logger.d('WebRTC: Microphone muted: $muted');
      }
    } catch (e) {
      Logger.e('WebRTC: Error muting microphone', e);
    }
  }

  Future<void> close() async {
    Logger.d('WebRTC: Closing connection');
    try {
      _localStream?.getTracks().forEach((track) {
        track.stop();
      });
      await _localStream?.dispose();
      await _remoteStream?.dispose();
      await _peerConnection?.close();
    } catch (e) {
      Logger.e('WebRTC: Error closing session', e);
    } finally {
      _peerConnection = null;
      _localStream = null;
      _remoteStream = null;
      _isRemoteDescriptionSet = false;
      _bufferedIceCandidates.clear();
    }
  }

  // Helpers for mapping
  Map<String, dynamic> sessionDescriptionToMap(RTCSessionDescription description) {
    return {
      'type': description.type,
      'sdp': description.sdp,
    };
  }

  RTCSessionDescription mapToSessionDescription(Map<String, dynamic> map) {
    return RTCSessionDescription(
      map['sdp'],
      map['type'],
    );
  }

  Map<String, dynamic> iceCandidateToMap(RTCIceCandidate candidate) {
    return {
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    };
  }

  RTCIceCandidate mapToIceCandidate(Map<String, dynamic> map) {
    return RTCIceCandidate(
      map['candidate'],
      map['sdpMid'],
      map['sdpMLineIndex'],
    );
  }
}
