import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/env.dart';
import '../storage/secure_storage.dart';
import '../constants/storage_keys.dart';
import '../utils/logger.dart';

class SocketClient {
  SocketClient._();

  static final SocketClient instance = SocketClient._();

  IO.Socket? _socket;
  final SecureStorage _secureStorage = SecureStorage.instance;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  /// Connect to Socket.IO server with authentication
  Future<void> connect() async {
    if (_socket != null && _isConnected) {
      Logger.d('Socket already connected');
      return;
    }

    try {
      final token = await _secureStorage.read(StorageKeys.authToken);
      if (token == null || token.isEmpty) {
        Logger.w('No auth token available, cannot connect socket');
        return;
      }

      _socket = IO.io(
        Env.socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .setAuth({'token': token})
            .setExtraHeaders({'Authorization': 'Bearer $token'})
            .build(),
      );

      _setupEventListeners();
      _socket!.connect();

      Logger.d('Socket.IO connecting to ${Env.socketUrl}');
    } catch (e) {
      Logger.e('Error connecting socket', e);
    }
  }

  /// Setup event listeners
  void _setupEventListeners() {
    _socket!.onConnect((_) {
      _isConnected = true;
      Logger.d('Socket.IO connected');
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      Logger.d('Socket.IO disconnected');
    });

    _socket!.onConnectError((error) {
      _isConnected = false;
      Logger.e('Socket.IO connection error', error);
    });

    _socket!.onError((error) {
      Logger.e('Socket.IO error', error);
    });
  }

  /// Disconnect from Socket.IO server
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
      Logger.d('Socket.IO disconnected and disposed');
    }
  }

  /// Emit an event to the server
  void emit(String event, dynamic data) {
    if (_socket == null || !_isConnected) {
      Logger.w('Socket not connected, cannot emit event: $event');
      return;
    }

    _socket!.emit(event, data);
    Logger.d('Socket.IO emit: $event');
  }

  /// Listen to an event from the server
  void on(String event, Function(dynamic) callback) {
    if (_socket == null) {
      Logger.w('Socket not initialized, cannot listen to event: $event');
      return;
    }

    _socket!.on(event, (data) {
      Logger.d('Socket.IO received: $event');
      callback(data);
    });
  }

  /// Remove event listener
  void off(String event) {
    _socket?.off(event);
  }

  /// Remove all event listeners
  void offAll() {
    _socket?.clearListeners();
  }

  /// Reconnect with new token (after login)
  Future<void> reconnect() async {
    disconnect();
    await Future.delayed(const Duration(milliseconds: 500));
    await connect();
  }
}
