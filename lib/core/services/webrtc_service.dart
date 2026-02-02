import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../features/call/domain/entities/call_entity.dart'; // Will be created later, but we can plan for it

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

  // Stream controllers
  final _localStreamController = StreamController<MediaStream>.broadcast();
  final _remoteStreamController = StreamController<MediaStream>.broadcast();
  final _iceCandidateController = StreamController<RTCIceCandidate>.broadcast();
  final _connectionStateController = StreamController<RTCPeerConnectionState>.broadcast();

  Stream<MediaStream> get localStream => _localStreamController.stream;
  Stream<MediaStream> get remoteStream => _remoteStreamController.stream;
  Stream<RTCIceCandidate> get iceCandidates => _iceCandidateController.stream;
  Stream<RTCPeerConnectionState> get connectionState => _connectionStateController.stream;

  MediaStream? get localStreamValue => _localStream;
  MediaStream? get remoteStreamValue => _remoteStream;

  Future<void> initialize({
    required List<Map<String, dynamic>> iceServers,
  }) async {
    // Create peer connection
    final configuration = {
      'iceServers': iceServers,
    };

    final constraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': false, // Audio-only for now
      },
      'optional': [],
    };

    _peerConnection = await createPeerConnection(configuration, constraints);

    // Setup event listeners
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      _iceCandidateController.add(candidate);
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      _connectionStateController.add(state);
    };

    _peerConnection!.onAddStream = (MediaStream stream) {
      _remoteStream = stream;
      _remoteStreamController.add(stream);
    };

    // Get local media stream (audio only)
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });

      // Add local stream to peer connection
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      _localStreamController.add(_localStream!);
    } catch (e) {
      print('Error getting user media: $e');
      rethrow;
    }
  }

  Future<RTCSessionDescription> createOffer() async {
    if (_peerConnection == null) {
      throw Exception('Peer connection not initialized');
    }

    try {
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });

      await _peerConnection!.setLocalDescription(offer);
      return offer;
    } catch (e) {
      print('Error creating offer: $e');
      rethrow;
    }
  }

  Future<RTCSessionDescription> createAnswer() async {
    if (_peerConnection == null) {
      throw Exception('Peer connection not initialized');
    }

    try {
      final answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });

      await _peerConnection!.setLocalDescription(answer);
      return answer;
    } catch (e) {
      print('Error creating answer: $e');
      rethrow;
    }
  }

  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    if (_peerConnection == null) {
      throw Exception('Peer connection not initialized');
    }

    await _peerConnection!.setRemoteDescription(description);
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    if (_peerConnection == null) {
      throw Exception('Peer connection not initialized');
    }

    await _peerConnection!.addCandidate(candidate);
  }

  Future<void> setSpeakerphoneOn(bool enabled) async {
    try {
      await Helper.setSpeakerphoneOn(enabled);
    } catch (e) {
      print('Error setting speakerphone: $e');
    }
  }

  Future<void> setMicrophoneMute(bool muted) async {
    try {
      _localStream?.getAudioTracks().forEach((track) {
        track.enabled = !muted;
      });
    } catch (e) {
      print('Error muting microphone: $e');
    }
  }

  Future<void> close() async {
    try {
      _localStream?.getTracks().forEach((track) => track.stop());
      await _localStream?.dispose();
      await _remoteStream?.dispose();
      await _peerConnection?.close();
    } catch (e) {
      print('Error closing WebRTC: $e');
    } finally {
      _peerConnection = null;
      _localStream = null;
      _remoteStream = null;
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
