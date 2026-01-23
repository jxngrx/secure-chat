import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../network/api_client.dart';
import '../storage/secure_storage.dart';
import '../constants/storage_keys.dart';
import '../utils/logger.dart';
import '../../features/location/data/datasources/location_remote_ds.dart';

class LiveLocationService {
  LiveLocationService(this._locationDataSource, this._secureStorage);

  final LocationRemoteDataSource _locationDataSource;
  final SecureStorage _secureStorage;
  Timer? _liveLocationUpdateTimer;
  String? _currentLiveSessionId;
  bool _isSharing = false;

  /// Start live location sharing
  Future<String?> startLiveLocation({
    String? chatId,
    required double latitude,
    required double longitude,
    required double accuracy,
  }) async {
    if (_isSharing) {
      Logger.w('Live location already sharing');
      return _currentLiveSessionId;
    }

    try {
      final response = await _locationDataSource.startLiveLocation(
        chatId: chatId,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
      );

      _currentLiveSessionId = response['liveSessionId'] as String?;
      _isSharing = true;

      // Update location every 10-15 seconds (using 12 seconds)
      _liveLocationUpdateTimer = Timer.periodic(
        const Duration(seconds: 12),
        (_) => _updateLiveLocation(),
      );

      Logger.d('Live location started: $_currentLiveSessionId');
      return _currentLiveSessionId;
    } catch (e) {
      Logger.e('Error starting live location', e);
      return null;
    }
  }

  /// Update live location
  Future<void> _updateLiveLocation() async {
    if (!_isSharing || _currentLiveSessionId == null) {
      return;
    }

    try {
      final location = await _getCurrentLocation();
      if (location == null) {
        Logger.w('Could not get location for live update');
        return;
      }

      await _locationDataSource.updateLiveLocation(
        liveSessionId: _currentLiveSessionId!,
        latitude: location['latitude'] as double,
        longitude: location['longitude'] as double,
        accuracy: location['accuracy'] as double,
      );

      Logger.d('Live location updated');
    } catch (e) {
      Logger.e('Error updating live location', e);
    }
  }

  /// Stop live location sharing
  Future<void> stopLiveLocation() async {
    if (!_isSharing || _currentLiveSessionId == null) {
      return;
    }

    try {
      await _locationDataSource.stopLiveLocation(_currentLiveSessionId!);
      _liveLocationUpdateTimer?.cancel();
      _liveLocationUpdateTimer = null;
      _currentLiveSessionId = null;
      _isSharing = false;
      Logger.d('Live location stopped');
    } catch (e) {
      Logger.e('Error stopping live location', e);
    }
  }

  /// Get current location
  Future<Map<String, dynamic>?> _getCurrentLocation() async {
    try {
      final hasPermission = await _requestLocationPermission();
      if (!hasPermission) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
      };
    } catch (e) {
      Logger.e('Error getting location', e);
      return null;
    }
  }

  /// Request location permissions
  Future<bool> _requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  bool get isSharing => _isSharing;
  String? get currentLiveSessionId => _currentLiveSessionId;

  void dispose() {
    stopLiveLocation();
  }
}
