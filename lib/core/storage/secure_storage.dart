import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage._();

  static final SecureStorage instance = SecureStorage._();

  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  static const _iosOptions = IOSOptions();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> write(String key, String value) async {
    await _storage.write(
      key: key,
      value: value,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
  }

  Future<String?> read(String key) async {
    return _storage.read(
      key: key,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
  }

  Future<void> delete(String key) async {
    await _storage.delete(
      key: key,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
  }

  Future<void> deleteAll() async {
    await _storage.deleteAll(
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
  }
}
