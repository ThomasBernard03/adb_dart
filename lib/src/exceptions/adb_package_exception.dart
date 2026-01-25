import 'package:adb_dart/src/exceptions/adb_exception.dart';

/// Thrown when package management operations fail.
class AdbPackageException extends AdbException {
  /// The device ID where the operation was attempted.
  final String? deviceId;

  /// The exit code from the ADB command, if available.
  final int? exitCode;

  /// Creates a new [AdbPackageException].
  AdbPackageException(super.message, {this.deviceId, this.exitCode});
}
