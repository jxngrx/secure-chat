import 'package:permission_handler/permission_handler.dart' as ph;

class PermissionHandler {
  PermissionHandler._();

  static final PermissionHandler instance = PermissionHandler._();

  /// Request contacts permission
  /// Returns true if granted, false otherwise
  Future<bool> requestContactsPermission() async {
    try {
      final status = await ph.Permission.contacts.request();
      return status.isGranted;
    } catch (e) {
      return false;
    }
  }

  /// Check if contacts permission is granted
  Future<bool> isContactsPermissionGranted() async {
    try {
      final status = await ph.Permission.contacts.status;
      return status.isGranted;
    } catch (e) {
      return false;
    }
  }

  /// Check if contacts permission is permanently denied
  Future<bool> isContactsPermissionPermanentlyDenied() async {
    try {
      final status = await ph.Permission.contacts.status;
      return status.isPermanentlyDenied;
    } catch (e) {
      return false;
    }
  }

  /// Open app settings if permission is permanently denied
  Future<bool> openAppSettings() async {
    try {
      // Call the top-level function from permission_handler package
      return await ph.openAppSettings();
    } catch (e) {
      return false;
    }
  }

  /// Request camera permission
  Future<bool> requestCameraPermission() async {
    try {
      final status = await ph.Permission.camera.request();
      return status.isGranted;
    } catch (e) {
      return false;
    }
  }

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    try {
      final status = await ph.Permission.microphone.request();
      return status.isGranted;
    } catch (e) {
      return false;
    }
  }
}
