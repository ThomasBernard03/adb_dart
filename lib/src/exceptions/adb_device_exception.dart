import 'package:adb_dart/src/exceptions/adb_exception.dart';

/// Thrown when device communication or discovery fails.
class AdbDeviceException extends AdbException {
  /// The device ID, if available.
  final String? deviceId;

  /// The exit code from the ADB command, if available.
  final int? exitCode;

  /// Creates a new [AdbDeviceException].
  AdbDeviceException(super.message, {this.deviceId, this.exitCode});
}
