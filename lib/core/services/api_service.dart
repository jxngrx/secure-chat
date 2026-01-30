import 'dart:io';
import '../../features/auth/data/datasources/auth_remote_ds.dart';
import '../../features/user/data/datasources/user_remote_ds.dart';
import '../../features/chat/data/datasources/chat_remote_ds.dart';
import '../../features/message/data/datasources/message_remote_ds.dart';
import '../../features/call/data/datasources/call_remote_ds.dart';
import '../../features/contacts/data/datasources/contact_remote_ds.dart';
import '../../features/session/data/datasources/session_remote_ds.dart';
import '../../features/location/data/datasources/location_remote_ds.dart';
import '../../features/media/data/datasources/media_remote_ds.dart';
import '../network/api_client.dart';
import '../services/device_info_service.dart';
import '../utils/logger.dart';

/// Centralized API Service
///
/// This service provides a single interface for all backend API calls.
/// It wraps existing data sources and adds missing endpoints.
///
/// Usage:
/// ```dart
/// final apiService = ApiService.instance;
/// final profile = await apiService.getProfile();
/// ```
class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  // Data sources
  final ApiClient _apiClient = ApiClient.instance;
  final AuthRemoteDataSource _authDS = AuthRemoteDataSource(ApiClient.instance);
  final UserRemoteDataSource _userDS = UserRemoteDataSource.instance;
  final ChatRemoteDataSource _chatDS = ChatRemoteDataSource.instance;
  final MessageRemoteDataSource _messageDS = MessageRemoteDataSource.instance;
  final CallRemoteDataSource _callDS = CallRemoteDataSource.instance;
  final ContactRemoteDataSource _contactDS = ContactRemoteDataSource.instance;
  final SessionRemoteDataSource _sessionDS = SessionRemoteDataSource.instance;
  final LocationRemoteDataSource _locationDS = LocationRemoteDataSource.instance;
  final MediaRemoteDataSource _mediaDS = MediaRemoteDataSource.instance;

  // ============================================================================
  // AUTHENTICATION
  // ============================================================================

  /// Register a new user
  ///
  /// Returns: { token, user, session }
  Future<Map<String, dynamic>> register({
    String? username,
    required String password,
    required String deviceId,
    String? phone,
  }) async {
    try {
      return await _authDS.register(
        username: username,
        password: password,
        deviceId: deviceId,
        phone: phone,
      );
    } catch (e) {
      Logger.e('Error registering user', e);
      rethrow;
    }
  }

  /// Login user
  ///
  /// Returns: { token, user, session }
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    required String deviceId,
  }) async {
    try {
      return await _authDS.login(
        username: username,
        password: password,
        deviceId: deviceId,
      );
    } catch (e) {
      Logger.e('Error logging in', e);
      rethrow;
    }
  }

  /// Update username
  ///
  /// [username] - New username (3-30 chars, alphanumeric + underscores)
  Future<Map<String, dynamic>> updateUsername(String username) async {
    try {
      return await _authDS.updateUsername(username);
    } catch (e) {
      Logger.e('Error updating username', e);
      rethrow;
    }
  }

  /// Update phone number
  ///
  /// [phone] - New phone number (E.164 format preferred)
  Future<Map<String, dynamic>> updatePhone(String phone) async {
    try {
      return await _authDS.updatePhone(phone);
    } catch (e) {
      Logger.e('Error updating phone', e);
      rethrow;
    }
  }

  // ============================================================================
  // USERS
  // ============================================================================

  /// Get current user profile
  Future<Map<String, dynamic>> getProfile() async {
    try {
      return await _userDS.getProfile();
    } catch (e) {
      Logger.e('Error getting profile', e);
      rethrow;
    }
  }

  /// Search users by phone or username
  ///
  /// [query] - Search query:
  ///   - 10 digits: searches phone only
  ///   - +12 digits: searches phone only (extracts last 10 digits)
  ///   - Other: searches username only
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      return await _userDS.searchUsers(query);
    } catch (e) {
      Logger.e('Error searching users', e);
      rethrow;
    }
  }

  /// Get user by ID
  Future<Map<String, dynamic>> getUserById(String userId) async {
    try {
      return await _userDS.getUserById(userId);
    } catch (e) {
      Logger.e('Error getting user by ID', e);
      rethrow;
    }
  }

  /// Check if username is available
  ///
  /// [username] - Username to check (3-30 chars, alphanumeric + underscores)
  ///
  /// Returns: true if available, false if taken or invalid
  Future<bool> checkUsernameAvailability(String username) async {
    try {
      return await _userDS.checkUsernameAvailability(username);
    } catch (e) {
      Logger.e('Error checking username availability', e);
      rethrow;
    }
  }

  // ============================================================================
  // DEVICES
  // ============================================================================

  /// Register or update device
  ///
  /// [deviceId] - Device UUID (auto-generated if not provided)
  /// [deviceModel] - Device model name
  /// [manufacturer] - Device manufacturer
  /// [osName] - Operating system name
  /// [osVersion] - Operating system version
  /// [appVersion] - App version
  /// [platform] - Platform ('Android' or 'iOS')
  /// [imei] - IMEI (optional, 15 digits)
  Future<Map<String, dynamic>> registerDevice({
    required String deviceId,
    required String deviceModel,
    required String manufacturer,
    required String osName,
    required String osVersion,
    required String appVersion,
    required String platform,
    String? imei,
  }) async {
    try {
      final payload = <String, dynamic>{
        'deviceId': deviceId,
        'deviceModel': deviceModel,
        'manufacturer': manufacturer,
        'osName': osName,
        'osVersion': osVersion,
        'appVersion': appVersion,
        'platform': platform,
      };
      if (imei != null && imei.isNotEmpty) {
        payload['imei'] = imei;
      }

      final response = await _apiClient.post('/devices/register', payload);
      return response['data'] as Map<String, dynamic>? ?? {};
    } catch (e) {
      Logger.e('Error registering device', e);
      rethrow;
    }
  }

  /// Get all devices for current user
  Future<List<Map<String, dynamic>>> getUserDevices() async {
    try {
      final response = await _apiClient.get('/devices');
      final devices = response['data'] as List<dynamic>? ?? [];
      return devices.cast<Map<String, dynamic>>();
    } catch (e) {
      Logger.e('Error getting user devices', e);
      rethrow;
    }
  }

  /// Get device by deviceId
  ///
  /// [deviceId] - Device UUID
  Future<Map<String, dynamic>> getDeviceById(String deviceId) async {
    try {
      final response = await _apiClient.get('/devices/$deviceId');
      return response['data'] as Map<String, dynamic>? ?? {};
    } catch (e) {
      Logger.e('Error getting device by ID', e);
      rethrow;
    }
  }

  // ============================================================================
  // SESSIONS
  // ============================================================================

  /// Create new session
  ///
  /// [deviceId] - Device UUID
  /// [loginMethod] - 'phone' or 'google'
  /// [location] - Optional location data { latitude, longitude, accuracy }
  Future<Map<String, dynamic>> createSession({
    required String deviceId,
    required String loginMethod,
    Map<String, dynamic>? location,
  }) async {
    try {
      return await _sessionDS.createSession(
        deviceId: deviceId,
        loginMethod: loginMethod,
        location: location,
      );
    } catch (e) {
      Logger.e('Error creating session', e);
      rethrow;
    }
  }

  /// Get all active sessions for current user
  Future<List<Map<String, dynamic>>> getSessions() async {
    try {
      return await _sessionDS.getSessions();
    } catch (e) {
      Logger.e('Error getting sessions', e);
      rethrow;
    }
  }

  /// Deactivate specific session (logout from one device)
  Future<void> deactivateSession(String sessionId) async {
    try {
      await _sessionDS.deactivateSession(sessionId);
    } catch (e) {
      Logger.e('Error deactivating session', e);
      rethrow;
    }
  }

  /// Deactivate all sessions (logout from all devices)
  Future<void> deactivateAllSessions() async {
    try {
      await _sessionDS.deactivateAllSessions();
    } catch (e) {
      Logger.e('Error deactivating all sessions', e);
      rethrow;
    }
  }

  // ============================================================================
  // LOCATION
  // ============================================================================

  /// Update last known location
  ///
  /// Backend automatically fetches most recent active session if not provided in headers.
  ///
  /// [latitude] - Latitude (-90 to 90)
  /// [longitude] - Longitude (-180 to 180)
  /// [accuracy] - Accuracy in meters (optional)
  Future<void> updateLocation({
    required double latitude,
    required double longitude,
    double? accuracy,
  }) async {
    try {
      final payload = <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
      };
      if (accuracy != null) {
        payload['accuracy'] = accuracy;
      }

      await _apiClient.post('/location/update-simple', payload);
    } catch (e) {
      Logger.e('Error updating location', e);
      rethrow;
    }
  }

  /// Get last known location
  Future<Map<String, dynamic>> getLastKnownLocation() async {
    try {
      return await _locationDS.getLastKnownLocation();
    } catch (e) {
      Logger.e('Error getting last known location', e);
      rethrow;
    }
  }

  /// Start live location sharing
  ///
  /// [chatId] - Optional chat ID for sharing in specific chat
  /// [latitude] - Initial latitude
  /// [longitude] - Initial longitude
  /// [accuracy] - Accuracy in meters
  ///
  /// Returns: { liveSessionId, latitude, longitude, accuracy, timestamp, isLive }
  Future<Map<String, dynamic>> startLiveLocation({
    String? chatId,
    required double latitude,
    required double longitude,
    required double accuracy,
  }) async {
    try {
      return await _locationDS.startLiveLocation(
        chatId: chatId,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
      );
    } catch (e) {
      Logger.e('Error starting live location', e);
      rethrow;
    }
  }

  /// Update live location (call every 10-15 seconds)
  ///
  /// [liveSessionId] - Live location session ID from startLiveLocation
  /// [latitude] - Current latitude
  /// [longitude] - Current longitude
  /// [accuracy] - Accuracy in meters
  Future<void> updateLiveLocation({
    required String liveSessionId,
    required double latitude,
    required double longitude,
    required double accuracy,
  }) async {
    try {
      await _locationDS.updateLiveLocation(
        liveSessionId: liveSessionId,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
      );
    } catch (e) {
      Logger.e('Error updating live location', e);
      rethrow;
    }
  }

  /// Stop live location sharing
  ///
  /// [liveSessionId] - Live location session ID
  Future<void> stopLiveLocation(String liveSessionId) async {
    try {
      await _locationDS.stopLiveLocation(liveSessionId);
    } catch (e) {
      Logger.e('Error stopping live location', e);
      rethrow;
    }
  }

  // ============================================================================
  // CONTACTS
  // ============================================================================

  /// Sync contacts with backend
  ///
  /// Phone numbers are automatically hashed with SHA-256 before sending.
  ///
  /// [phoneNumbers] - List of phone numbers in E.164 format
  ///
  /// Returns: List of matched contacts
  Future<List<Map<String, dynamic>>> syncContacts(List<String> phoneNumbers) async {
    try {
      return await _contactDS.syncContacts(phoneNumbers);
    } catch (e) {
      Logger.e('Error syncing contacts', e);
      rethrow;
    }
  }

  /// Get all contacts for current user
  Future<List<Map<String, dynamic>>> getContacts() async {
    try {
      return await _contactDS.getContacts();
    } catch (e) {
      Logger.e('Error getting contacts', e);
      rethrow;
    }
  }

  // ============================================================================
  // CHATS
  // ============================================================================

  /// Get all chats for current user
  ///
  /// Returns: List of chats sorted by lastMessageAt (most recent first)
  Future<List<Map<String, dynamic>>> getChats() async {
    try {
      return await _chatDS.getChats();
    } catch (e) {
      Logger.e('Error getting chats', e);
      rethrow;
    }
  }

  /// Get chat by ID
  ///
  /// [chatId] - Chat ID (format: "userId1_userId2")
  Future<Map<String, dynamic>> getChatById(String chatId) async {
    try {
      return await _chatDS.getChatById(chatId);
    } catch (e) {
      Logger.e('Error getting chat by ID', e);
      rethrow;
    }
  }

  /// Create or get existing chat with another user
  ///
  /// [otherUserId] - Other user's ID
  ///
  /// Returns: Chat object with participants populated
  Future<Map<String, dynamic>> createOrGetChat(String otherUserId) async {
    try {
      return await _chatDS.createOrGetChat(otherUserId);
    } catch (e) {
      Logger.e('Error creating/getting chat', e);
      rethrow;
    }
  }

  // ============================================================================
  // MESSAGES
  // ============================================================================

  /// Send message via REST API
  ///
  /// [chatId] - Chat ID
  /// [type] - Message type: 'text', 'image', 'video', 'voice', 'file'
  /// [content] - Message content (text or file URL for media)
  ///
  /// Returns: Message object
  Future<Map<String, dynamic>> sendMessage({
    required String chatId,
    required String type,
    required String content,
  }) async {
    try {
      return await _messageDS.sendMessage(
        chatId: chatId,
        type: type,
        content: content,
      );
    } catch (e) {
      Logger.e('Error sending message', e);
      rethrow;
    }
  }

  /// Get chat messages with pagination
  ///
  /// [chatId] - Chat ID
  /// [limit] - Number of messages to fetch (default: 50)
  /// [before] - Message ID to fetch messages before (for pagination)
  ///
  /// Returns: List of messages (oldest first)
  Future<List<Map<String, dynamic>>> getChatMessages({
    required String chatId,
    int limit = 50,
    String? before,
  }) async {
    try {
      return await _messageDS.getChatMessages(
        chatId: chatId,
        limit: limit,
        before: before,
      );
    } catch (e) {
      Logger.e('Error getting chat messages', e);
      rethrow;
    }
  }

  /// Mark all unread messages in chat as read
  ///
  /// [chatId] - Chat ID
  Future<void> markAsRead(String chatId) async {
    try {
      await _messageDS.markAsRead(chatId);
    } catch (e) {
      Logger.e('Error marking messages as read', e);
      rethrow;
    }
  }

  /// Mark all undelivered messages in chat as delivered
  ///
  /// [chatId] - Chat ID
  Future<void> markAsDelivered(String chatId) async {
    try {
      await _messageDS.markAsDelivered(chatId);
    } catch (e) {
      Logger.e('Error marking messages as delivered', e);
      rethrow;
    }
  }

  /// Edit message
  ///
  /// Only works if message is unread and within 30 minutes of creation.
  ///
  /// [messageId] - Message ID
  /// [content] - New message content
  ///
  /// Returns: Updated message object
  Future<Map<String, dynamic>> editMessage({
    required String messageId,
    required String content,
  }) async {
    try {
      return await _messageDS.editMessage(
        messageId: messageId,
        content: content,
      );
    } catch (e) {
      Logger.e('Error editing message', e);
      rethrow;
    }
  }

  /// Delete message
  ///
  /// [messageId] - Message ID
  /// [deleteForEveryone] - If true, permanently deletes (only if unread).
  ///                      If false, soft deletes (adds to deletedFor array).
  Future<void> deleteMessage({
    required String messageId,
    bool deleteForEveryone = false,
  }) async {
    try {
      await _messageDS.deleteMessage(
        messageId: messageId,
        deleteForEveryone: deleteForEveryone,
      );
    } catch (e) {
      Logger.e('Error deleting message', e);
      rethrow;
    }
  }

  // ============================================================================
  // CALLS
  // ============================================================================

  /// Initiate call
  ///
  /// [receiverId] - Receiver's user ID
  ///
  /// Returns: { id, caller, receiver, status, rtcConfig }
  Future<Map<String, dynamic>> initiateCall(String receiverId) async {
    try {
      return await _callDS.initiateCall(receiverId);
    } catch (e) {
      Logger.e('Error initiating call', e);
      rethrow;
    }
  }

  /// Answer call
  ///
  /// [callId] - Call ID
  ///
  /// Returns: Call object with updated status
  Future<Map<String, dynamic>> answerCall(String callId) async {
    try {
      return await _callDS.answerCall(callId);
    } catch (e) {
      Logger.e('Error answering call', e);
      rethrow;
    }
  }

  /// Reject call
  ///
  /// [callId] - Call ID
  Future<void> rejectCall(String callId) async {
    try {
      await _callDS.rejectCall(callId);
    } catch (e) {
      Logger.e('Error rejecting call', e);
      rethrow;
    }
  }

  /// End call
  ///
  /// [callId] - Call ID
  ///
  /// Returns: Call object with duration calculated
  Future<Map<String, dynamic>> endCall(String callId) async {
    try {
      return await _callDS.endCall(callId);
    } catch (e) {
      Logger.e('Error ending call', e);
      rethrow;
    }
  }

  /// Get call history
  ///
  /// [limit] - Number of calls to fetch (default: 50)
  ///
  /// Returns: List of calls (most recent first)
  Future<List<Map<String, dynamic>>> getCallHistory({int limit = 50}) async {
    try {
      return await _callDS.getCallHistory(limit: limit);
    } catch (e) {
      Logger.e('Error getting call history', e);
      rethrow;
    }
  }

  // ============================================================================
  // MEDIA
  // ============================================================================

  /// Upload file
  ///
  /// [file] - File to upload (max 10MB)
  ///
  /// Returns: { url, filename, size, mimetype }
  Future<Map<String, dynamic>> uploadFile(File file) async {
    try {
      return await _mediaDS.uploadFile(file.path);
    } catch (e) {
      Logger.e('Error uploading file', e);
      rethrow;
    }
  }

  /// Delete file
  ///
  /// [url] - File URL to delete
  Future<void> deleteFile(String url) async {
    try {
      await _mediaDS.deleteFile(url);
    } catch (e) {
      Logger.e('Error deleting file', e);
      rethrow;
    }
  }

  // ============================================================================
  // HEALTH
  // ============================================================================

  /// Health check endpoint
  ///
  /// Returns: { status: "ok", timestamp: "..." }
  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await _apiClient.get('/health');
      return response;
    } catch (e) {
      Logger.e('Error checking health', e);
      rethrow;
    }
  }
}
