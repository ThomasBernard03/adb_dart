import 'package:adb_dart/src/device_id.dart';

class AndroidDevice {
  final String manufacturer;
  final String name;
  final DeviceId deviceId;

  const AndroidDevice({
    required this.manufacturer,
    required this.name,
    required this.deviceId,
  });
}
