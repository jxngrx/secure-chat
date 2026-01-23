# Backend Integration Guide

This document explains how to integrate the backend services with the Flutter frontend.

## Overview

The app now includes:
1. ✅ India-only phone number input (no country selector, no gaps)
2. ✅ Dynamic mic/send icon in chat screen
3. ✅ Call icon (replaced video call)
4. ✅ Missed call display in chat screen
5. ✅ Background location tracking service
6. ✅ Device registration service

## Services Created

### 1. LocationService (`lib/core/services/location_service.dart`)
- Handles location permissions
- Tracks location every 30 seconds
- Updates backend via `/api/v1/location/update`
- Automatically handles permission requests

### 2. DeviceRegistrationService (`lib/core/services/device_registration_service.dart`)
- Registers device after authentication
- Calls `/api/v1/devices/register` endpoint
- Includes device details (model, OS, version, etc.)

### 3. BackgroundServiceManager (`lib/core/services/background_service_manager.dart`)
- Manages all background services
- Initializes device registration and location tracking
- Should be called after successful authentication

## Integration Steps

### Step 1: After OTP Verification Success

In your OTP verification success handler (e.g., in `otp_screen.dart` or auth controller), add:

```dart
import 'package:get_it/get_it.dart';
import '../../../../di/injection_container.dart';
import '../../../../core/services/background_service_manager.dart';

// After successful OTP verification
final backgroundServiceManager = InjectionContainer.resolve<BackgroundServiceManager>();
await backgroundServiceManager.initializeServices();
```

### Step 2: On App Startup (if user is already authenticated)

In your app initialization (e.g., `main.dart` or `bootstrap.dart`):

```dart
import 'package:get_it/get_it.dart';
import 'di/injection_container.dart';
import 'core/services/background_service_manager.dart';
import 'core/storage/secure_storage.dart';
import 'core/constants/storage_keys.dart';

// Check if user is authenticated
final secureStorage = InjectionContainer.resolve<SecureStorage>();
final token = await secureStorage.read(StorageKeys.authToken);

if (token != null && token.isNotEmpty) {
  // User is authenticated, initialize background services
  final backgroundServiceManager = InjectionContainer.resolve<BackgroundServiceManager>();
  await backgroundServiceManager.initializeServices();
}
```

### Step 3: On Logout

When user logs out, stop all background services:

```dart
final backgroundServiceManager = InjectionContainer.resolve<BackgroundServiceManager>();
backgroundServiceManager.stopAllServices();
```

## API Endpoints Used

### Device Registration
```
POST /api/v1/devices/register
Headers: Authorization: Bearer <token>
Body: {
  "deviceId": "...",
  "deviceModel": "...",
  "manufacturer": "...",
  "osName": "...",
  "osVersion": "...",
  "appVersion": "...",
  "platform": "...",
  "imei": "..." // Optional
}
```

### Location Update
```
POST /api/v1/location/update
Headers: Authorization: Bearer <token>
Body: {
  "latitude": 40.7128,
  "longitude": -74.0060,
  "accuracy": 10
}
```

## Dependencies Added

- `geolocator: ^12.0.0` - For location services

Make sure to run:
```bash
flutter pub get
```

## Platform-Specific Setup

### Android
Add location permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

### iOS
Add location permissions to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to provide better services</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We need your location to provide better services</string>
```

## Testing

1. **Phone Input**: Verify India-only country code (+91) is fixed
2. **Phone Format**: Verify no gaps in phone number input
3. **Chat Screen**: Type in message field - mic icon should change to send icon
4. **Call Icon**: Verify call icon appears instead of video call icon
5. **Missed Calls**: Verify missed call messages display correctly in chat
6. **Location Tracking**: Check logs for location updates every 30 seconds
7. **Device Registration**: Verify device is registered after authentication

## Notes

- Location tracking updates every 30 seconds
- Device registration happens once after authentication
- All services are automatically managed by `BackgroundServiceManager`
- Services are registered in dependency injection container
