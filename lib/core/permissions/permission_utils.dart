import 'permission_handler.dart';

class PermissionUtils {
  PermissionUtils._();

  static final PermissionUtils instance = PermissionUtils._();

  Future<bool> checkAndRequestContactsPermission() async {
    return await PermissionHandler.instance.requestContactsPermission();
  }

  Future<bool> checkAndRequestCameraPermission() async {
    return await PermissionHandler.instance.requestCameraPermission();
  }

  Future<bool> checkAndRequestMicrophonePermission() async {
    return await PermissionHandler.instance.requestMicrophonePermission();
  }
}
