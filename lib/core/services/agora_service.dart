import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../utils/logger.dart';

class AgoraService {
  AgoraService._();
  static final AgoraService instance = AgoraService._();

  RtcEngine? _engine;
  final String _appId = 'c578a898eaad4c7aa82dd309bd762b6b'; // Provided by User

  // Stream controllers for UI updates
  final _remoteUserJoinedController = StreamController<int>.broadcast();
  final _remoteUserOfflineController = StreamController<int>.broadcast();
  final _joinChannelSuccessController = StreamController<String>.broadcast();
  final _leaveChannelController = StreamController<void>.broadcast();

  Stream<int> get remoteUserJoined => _remoteUserJoinedController.stream;
  Stream<int> get remoteUserOffline => _remoteUserOfflineController.stream;
  Stream<String> get joinChannelSuccess => _joinChannelSuccessController.stream;
  Stream<void> get onLeaveChannel => _leaveChannelController.stream;

  Future<void> initialize() async {
    if (_engine != null) return;

    try {
      // Create RtcEngine
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: _appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      // Register Event Handlers
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            Logger.d("Agora: Join Channel Success: ${connection.channelId}");
            _joinChannelSuccessController.add(connection.channelId ?? '');
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            Logger.d("Agora: User Joined: $remoteUid");
            _remoteUserJoinedController.add(remoteUid);
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            Logger.d("Agora: User Offline: $remoteUid");
            _remoteUserOfflineController.add(remoteUid);
          },
          onError: (ErrorCodeType err, String msg) {
             Logger.e("Agora: Error $err - $msg");
          },
        ),
      );

      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _engine!.enableAudio();

      // Strict Audio Only setup
      await _engine!.disableVideo();

      Logger.d("Agora Engine Initialized");
    } catch (e) {
      Logger.e("Agora Initialization Error", e);
    }
  }

  Future<void> joinChannel({
    required String token,
    required String channelId,
    required String uid, // String UID (User Account) from backend
  }) async {
    if (_engine == null) await initialize();

    try {
      await _engine!.joinChannelWithUserAccount(
        token: token,
        channelId: channelId,
        userAccount: uid,
      );
      Logger.d("Agora: Joining channel $channelId as $uid");
    } catch (e) {
      Logger.e("Agora Join Channel Error", e);
    }
  }

  Future<void> leaveChannel() async {
    try {
      await _engine?.leaveChannel();
      _leaveChannelController.add(null);
      Logger.d("Agora: Left channel");
    } catch (e) {
      Logger.e("Agora Leave Channel Error", e);
    }
  }

  Future<void> setSpeakerphoneOn(bool enabled) async {
    try {
      await _engine?.setEnableSpeakerphone(enabled);
      Logger.d("Agora: Speakerphone set to $enabled");
    } catch (e) {
      Logger.e("Agora Speakerphone Error", e);
    }
  }

  Future<void> setMicrophoneMute(bool muted) async {
    try {
      await _engine?.muteLocalAudioStream(muted);
      Logger.d("Agora: Microphone muted: $muted");
    } catch (e) {
      Logger.e("Agora Mute Error", e);
    }
  }

  Future<void> dispose() async {
    await leaveChannel();
    await _engine?.release();
    _engine = null;
  }
}
