import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../network/api_client.dart';
import '../storage/secure_storage.dart';
import '../constants/storage_keys.dart';
import '../utils/logger.dart';
import 'ip_logging_service.dart';

class LocationService {
  LocationService(
    this._apiClient,
    this._secureStorage,
    this._ipLoggingService,
  );

  final ApiClient _apiClient;
  final SecureStorage _secureStorage;
  final IPLoggingService _ipLoggingService;
  Timer? _locationUpdateTimer;
  bool _isTracking = false;

  /// Request location permissions
  Future<bool> requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      Logger.w('Location services are disabled');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        Logger.w('Location permissions are denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      Logger.w('Location permissions are permanently denied');
      return false;
    }

    return true;
  }

  /// Get current location
  Future<Map<String, dynamic>?> getCurrentLocation() async {
    try {
      final hasPermission = await requestLocationPermission();
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

  /// Start background location tracking
  /// Updates location every 30 seconds to backend
  Future<void> startLocationTracking() async {
    if (_isTracking) {
      Logger.d('Location tracking already started');
      return;
    }

    final hasPermission = await requestLocationPermission();
    if (!hasPermission) {
      Logger.w('Location permission not granted, cannot start tracking');
      return;
    }

    _isTracking = true;
    Logger.d('Starting location tracking');

    // Update immediately
    await _updateLocationToBackend();

    // Then update every 5 minutes
    _locationUpdateTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _updateLocationToBackend(),
    );
  }

  /// Stop location tracking
  void stopLocationTracking() {
    if (!_isTracking) {
      return;
    }

    _isTracking = false;
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    Logger.d('Stopped location tracking');
  }

  /// Update location to backend
  Future<void> _updateLocationToBackend() async {
    try {
      final location = await getCurrentLocation();
      if (location == null) {
        Logger.w('Could not get location for update');
        return;
      }

      final token = await _secureStorage.read(StorageKeys.authToken);
      if (token == null || token.isEmpty) {
        Logger.w('No auth token, skipping location update');
        return;
      }

      await _apiClient.post('/location/update-simple', {
        'latitude': location['latitude'],
        'longitude': location['longitude'],
        'accuracy': location['accuracy'],
      });

      Logger.d('Location updated to backend: ${location['latitude']}, ${location['longitude']}');

      // Log IP with location change
      await _ipLoggingService.logIPOnLocationChange(
        latitude: location['latitude'] as double,
        longitude: location['longitude'] as double,
        accuracy: location['accuracy'] as double?,
      );
    } catch (e) {
      Logger.e('Error updating location to backend', e);
    }
  }

  /// Check if tracking is active
  bool get isTracking => _isTracking;

  /// Dispose resources
  void dispose() {
    stopLocationTracking();
  }
}
