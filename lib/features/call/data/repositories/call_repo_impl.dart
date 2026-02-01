import '../../domain/repositories/call_repository.dart';
import '../../domain/entities/call_entity.dart';
import '../datasources/call_remote_ds.dart';
import '../models/call_model.dart';
import 'dart:async';

class CallRepositoryImpl implements CallRepository {
  CallRepositoryImpl._();

  static final CallRepositoryImpl instance = CallRepositoryImpl._();

  final CallRemoteDataSource _remoteDataSource = CallRemoteDataSource.instance;

  // Stream controllers for socket events - these should ideally be connected to a SocketDataSource
  // For now, providing dummy streams or we need to implement SocketDataSource for calls
  final _onIncomingCallController = StreamController<dynamic>.broadcast();
  final _onCallInitiatedController = StreamController<dynamic>.broadcast();
  final _onCallAnsweredController = StreamController<dynamic>.broadcast();
  final _onCallConnectedController = StreamController<dynamic>.broadcast();
  final _onCallRejectedController = StreamController<dynamic>.broadcast();
  final _onCallEndedController = StreamController<dynamic>.broadcast();
  final _onWebRTCOfferController = StreamController<dynamic>.broadcast();
  final _onWebRTCAnswerController = StreamController<dynamic>.broadcast();
  final _onWebRTCIceCandidateController = StreamController<dynamic>.broadcast();

  @override
  Future<Map<String, dynamic>> initiateCall(String receiverId) async {
    return await _remoteDataSource.initiateCall(receiverId);
  }

  @override
  Future<Map<String, dynamic>> answerCall(String callId) async {
    return await _remoteDataSource.answerCall(callId);
  }

  @override
  Future<void> rejectCall(String callId) async {
    await _remoteDataSource.rejectCall(callId);
  }

  @override
  Future<void> endCall(String callId) async {
    await _remoteDataSource.endCall(callId);
  }

  @override
  Future<List<CallEntity>> getCallHistory({int limit = 20}) async {
    final response = await _remoteDataSource.getCallHistory(limit: limit);
    return response.map((json) {
      final model = CallModel.fromJson(json);
      return model.toEntity();
    }).toList();
  }

  @override
  Stream<dynamic> get onIncomingCall => _onIncomingCallController.stream;

  @override
  Stream<dynamic> get onCallInitiated => _onCallInitiatedController.stream;

  @override
  Stream<dynamic> get onCallAnswered => _onCallAnsweredController.stream;

  @override
  Stream<dynamic> get onCallConnected => _onCallConnectedController.stream;

  @override
  Stream<dynamic> get onCallRejected => _onCallRejectedController.stream;

  @override
  Stream<dynamic> get onCallEnded => _onCallEndedController.stream;

  @override
  Stream<dynamic> get onWebRTCOffer => _onWebRTCOfferController.stream;

  @override
  Stream<dynamic> get onWebRTCAnswer => _onWebRTCAnswerController.stream;

  @override
  Stream<dynamic> get onWebRTCIceCandidate => _onWebRTCIceCandidateController.stream;

  @override
  void sendWebRTCOffer(String callId, Map<String, dynamic> offer, String receiverId) {
    // Implement via socket
  }

  @override
  void sendWebRTCAnswer(String callId, Map<String, dynamic> answer, String callerId) {
    // Implement via socket
  }

  @override
  void sendWebRTCIceCandidate(String callId, Map<String, dynamic> candidate, String receiverId) {
    // Implement via socket
  }

  @override
  void dispose() {
    _onIncomingCallController.close();
    _onCallInitiatedController.close();
    _onCallAnsweredController.close();
    _onCallConnectedController.close();
    _onCallRejectedController.close();
    _onCallEndedController.close();
    _onWebRTCOfferController.close();
    _onWebRTCAnswerController.close();
    _onWebRTCIceCandidateController.close();
  }
}
