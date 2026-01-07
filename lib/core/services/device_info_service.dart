import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../constants/storage_keys.dart';
import '../storage/secure_storage.dart';
import '../../features/device/domain/entities/device_entity.dart';

class DeviceInfoService {
  DeviceInfoService(this._secureStorage);

  final SecureStorage _secureStorage;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final Uuid _uuid = const Uuid();

  Future<DeviceEntity> getDeviceDetails() async {
    var deviceId = await _secureStorage.read(StorageKeys.deviceId);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = _uuid.v4();
      await _secureStorage.write(StorageKeys.deviceId, deviceId);
    }

    final packageInfo = await PackageInfo.fromPlatform();

    if (kIsWeb) {
      final webInfo = await _deviceInfo.webBrowserInfo;
      return DeviceEntity(
        deviceId: deviceId,
        deviceModel: webInfo.userAgent ?? 'Web Browser',
        manufacturer: webInfo.vendor ?? 'Unknown',
        osName: 'Web',
        osVersion: webInfo.appVersion ?? '1.0.0',
        appVersion: packageInfo.version,
        platform: 'Web',
      );
    }

    if (Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      return DeviceEntity(
        deviceId: deviceId,
        deviceModel: info.model ?? 'Android Device',
        manufacturer: info.manufacturer ?? 'Unknown',
        osName: 'Android',
        osVersion: info.version.release ?? 'Unknown',
        appVersion: packageInfo.version,
        platform: 'Android',
      );
    }

    if (Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      return DeviceEntity(
        deviceId: deviceId,
        deviceModel: info.utsname.machine ?? 'iPhone',
        manufacturer: 'Apple',
        osName: 'iOS',
        osVersion: info.systemVersion ?? 'Unknown',
        appVersion: packageInfo.version,
        platform: 'iOS',
      );
    }

    final baseInfo = await _deviceInfo.deviceInfo;
    return DeviceEntity(
      deviceId: deviceId,
      deviceModel: baseInfo.data['model']?.toString() ?? 'Unknown Device',
      manufacturer: baseInfo.data['manufacturer']?.toString() ?? 'Unknown',
      osName: Platform.operatingSystem,
      osVersion: Platform.operatingSystemVersion,
      appVersion: packageInfo.version,
      platform: Platform.operatingSystem,
    );
  }
}
