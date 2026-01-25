import 'package:adb_dart/src/exceptions/adb_exception.dart';

/// Thrown when logcat operations fail.
class AdbLogcatException extends AdbException {
  /// The device ID where the operation was attempted.
  final String? deviceId;

  /// The exit code from the logcat command, if available.
  final int? exitCode;

  /// Creates a new [AdbLogcatException].
  AdbLogcatException(super.message, {this.deviceId, this.exitCode});
}
