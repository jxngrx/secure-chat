class DeviceEntity {
  const DeviceEntity({
    required this.deviceId,
    required this.deviceModel,
    required this.manufacturer,
    required this.osName,
    required this.osVersion,
    required this.appVersion,
    required this.platform,
    this.imei,
  });

  final String deviceId;
  final String deviceModel;
  final String manufacturer;
  final String osName;
  final String osVersion;
  final String appVersion;
  final String platform;
  final String? imei;
}
