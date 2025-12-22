import 'dart:io';

class NetworkInfo {
  NetworkInfo._();

  static final NetworkInfo instance = NetworkInfo._();

  Future<bool> get isConnected async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
