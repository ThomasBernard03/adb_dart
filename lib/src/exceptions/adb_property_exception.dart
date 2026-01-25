import 'package:adb_dart/src/exceptions/adb_exception.dart';

/// Thrown when retrieving device properties fails.
class AdbPropertyException extends AdbException {
  /// The device ID where the operation was attempted.
  final String? deviceId;

  /// The exit code from the getprop command, if available.
  final int? exitCode;

  /// Creates a new [AdbPropertyException].
  AdbPropertyException(super.message, {this.deviceId, this.exitCode});
}
