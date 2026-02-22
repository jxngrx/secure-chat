import 'dart:async';
import '../../domain/repositories/call_repository.dart';
import '../../domain/entities/call_entity.dart';
import '../datasources/call_remote_ds.dart';
import '../datasources/call_socket_ds.dart';
import '../../../../core/utils/logger.dart';

class CallRepositoryImpl implements CallRepository {
  // FIXED: Use a factory constructor so the singleton ALSO calls _initSocketListeners
  static CallRepositoryImpl? _instance;
  static CallRepositoryImpl get instance {
    _instance ??= CallRepositoryImpl._internal();
    return _instance!;
  }

  final CallRemoteDataSource _remoteDS = CallRemoteDataSource.instance;
  final CallSocketDataSource _socketDS = CallSocketDataSource.instance;

  // Stream Controllers
  final _incomingCallController = StreamController<dynamic>.broadcast();
  final _callInitiatedController = StreamController<dynamic>.broadcast();
  final _callAnsweredController = StreamController<dynamic>.broadcast();
  final _callConnectedController = StreamController<dynamic>.broadcast();
  final _callRejectedController = StreamController<dynamic>.broadcast();
  final _callEndedController = StreamController<dynamic>.broadcast();
  final _callErrorController = StreamController<dynamic>.broadcast();
  final _webRTCOfferController = StreamController<dynamic>.broadcast();
  final _webRTCAnswerController = StreamController<dynamic>.broadcast();
  final _webRTCIceCandidateController = StreamController<dynamic>.broadcast();

  // FIXED: Private named constructor that ALWAYS calls _initSocketListeners
  CallRepositoryImpl._internal() {
    _initSocketListeners();
  }

  void _initSocketListeners() {
    _socketDS.onIncomingCall((data) => _incomingCallController.add(data));
    _socketDS.onCallInitiated((data) => _callInitiatedController.add(data));
    _socketDS.onCallAnswered((data) => _callAnsweredController.add(data));
    _socketDS.onCallConnected((data) => _callConnectedController.add(data));
    _socketDS.onCallRejected((data) => _callRejectedController.add(data));
    _socketDS.onCallEnded((data) => _callEndedController.add(data));
    _socketDS.onCallError((data) => _callErrorController.add(data));

    _socketDS.onWebRTCOffer((data) => _webRTCOfferController.add(data));
    _socketDS.onWebRTCAnswer((data) => _webRTCAnswerController.add(data));
    _socketDS.onWebRTCIceCandidate((data) => _webRTCIceCandidateController.add(data));
  }

  @override
  Stream<dynamic> get onIncomingCall => _incomingCallController.stream;
  @override
  Stream<dynamic> get onCallInitiated => _callInitiatedController.stream;
  @override
  Stream<dynamic> get onCallAnswered => _callAnsweredController.stream;
  @override
  Stream<dynamic> get onCallConnected => _callConnectedController.stream;
  @override
  Stream<dynamic> get onCallRejected => _callRejectedController.stream;
  @override
  Stream<dynamic> get onCallEnded => _callEndedController.stream;
  @override
  Stream<dynamic> get onCallError => _callErrorController.stream;
  @override
  Stream<dynamic> get onWebRTCOffer => _webRTCOfferController.stream;
  @override
  Stream<dynamic> get onWebRTCAnswer => _webRTCAnswerController.stream;
  @override
  Stream<dynamic> get onWebRTCIceCandidate => _webRTCIceCandidateController.stream;

  @override
  Future<void> initiateCall(String receiverId) async {
    _socketDS.initiateCall(receiverId);
  }

  @override
  Future<void> answerCall(String callId) async {
    // 1. Emit purely via WebSocket (good for fast, foreground active connections)
    _socketDS.answerCall(callId);

    // 2. Guarantee Backend sync via REST fallback for Killed-State Cold Starts.
    // When waking from a killed state, the socket might not be fully authenticated yet
    // before this method is invoked by the native CallKit callback!
    try {
      await _remoteDS.answerCall(callId);
      Logger.d('CallRepositoryImpl: REST Fallback answerCall succeeded for $callId');
    } catch (e) {
      Logger.w('CallRepositoryImpl: REST Fallback answerCall failed (expected if active): $e');
    }
  }

  @override
  Future<void> rejectCall(String callId) async {
    _socketDS.rejectCall(callId);
  }

  @override
  Future<void> endCall(String callId) async {
    _socketDS.endCall(callId);
  }

  @override
  Future<List<CallEntity>> getCallHistory({int limit = 20}) async {
    final calls = await _remoteDS.getCallHistory(limit: limit);
    return calls.map((json) => CallEntity.fromJson(json)).toList();
  }

  @override
  void sendWebRTCOffer(String callId, Map<String, dynamic> offer, String receiverId) {
    _socketDS.sendWebRTCOffer(callId, offer, receiverId);
  }

  @override
  void sendWebRTCAnswer(String callId, Map<String, dynamic> answer, String callerId) {
    _socketDS.sendWebRTCAnswer(callId, answer, callerId);
  }

  @override
  void sendWebRTCIceCandidate(String callId, Map<String, dynamic> candidate, String receiverId) {
    _socketDS.sendWebRTCIceCandidate(callId, candidate, receiverId);
  }

  @override
  void dispose() {
    _incomingCallController.close();
    _callInitiatedController.close();
    _callAnsweredController.close();
    _callConnectedController.close();
    _callRejectedController.close();
    _callEndedController.close();
    _callErrorController.close();
    _webRTCOfferController.close();
    _webRTCAnswerController.close();
    _webRTCIceCandidateController.close();
    _socketDS.dispose();
  }
}
