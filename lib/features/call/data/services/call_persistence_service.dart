import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/logger.dart';

class CallPersistenceService {
  static const String _activeCallIdKey = 'active_call_id';
  static const String _connectedAtKey = 'call_connected_at';
  static const String _isCallerKey = 'call_is_caller';
  static const String _callerNameKey = 'call_caller_name';
  static const String _agoraTokenKey = 'call_agora_token';
  static const String _agoraChannelKey = 'call_agora_channel';
  static const String _agoraUidKey = 'call_agora_uid';

  static final CallPersistenceService instance = CallPersistenceService._();
  CallPersistenceService._();

  Future<void> saveCallState({
    required String callId,
    DateTime? connectedAt,
    bool isCaller = false,
    String? callerName,
    String? agoraToken,
    String? agoraChannel,
    String? agoraUid,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeCallIdKey, callId);
      if (connectedAt != null) {
        await prefs.setString(_connectedAtKey, connectedAt.toIso8601String());
      }
      await prefs.setBool(_isCallerKey, isCaller);
      if (callerName != null) {
        await prefs.setString(_callerNameKey, callerName);
      }
      if (agoraToken != null) {
        await prefs.setString(_agoraTokenKey, agoraToken);
      }
      if (agoraChannel != null) {
        await prefs.setString(_agoraChannelKey, agoraChannel);
      }
      if (agoraUid != null) {
        await prefs.setString(_agoraUidKey, agoraUid);
      }
      Logger.d('CallPersistenceService: Saved state for $callId (Agora: ${agoraChannel != null})');
    } catch (e) {
      Logger.e('CallPersistenceService: Error saving state', e);
    }
  }

  Future<Map<String, dynamic>?> loadCallState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final callId = prefs.getString(_activeCallIdKey);
      if (callId == null) return null;

      final connectedAtStr = prefs.getString(_connectedAtKey);
      final isCaller = prefs.getBool(_isCallerKey) ?? false;
      final callerName = prefs.getString(_callerNameKey);

      return {
        'callId': callId,
        'connectedAt': connectedAtStr != null ? DateTime.parse(connectedAtStr) : null,
        'isCaller': isCaller,
        'callerName': callerName,
        'agoraToken': prefs.getString(_agoraTokenKey),
        'agoraChannel': prefs.getString(_agoraChannelKey),
        'agoraUid': prefs.getString(_agoraUidKey),
      };
    } catch (e) {
      Logger.e('CallPersistenceService: Error loading state', e);
      return null;
    }
  }

  Future<void> clearCallState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeCallIdKey);
      await prefs.remove(_connectedAtKey);
      await prefs.remove(_isCallerKey);
      await prefs.remove(_callerNameKey);
      await prefs.remove(_agoraTokenKey);
      await prefs.remove(_agoraChannelKey);
      await prefs.remove(_agoraUidKey);
      Logger.d('CallPersistenceService: Cleared state');
    } catch (e) {
      Logger.e('CallPersistenceService: Error clearing state', e);
    }
  }
}
