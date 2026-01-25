import 'package:adb_dart/src/exceptions/adb_exception.dart';

/// Thrown when APK installation fails.
class AdbInstallationException extends AdbException {
  /// The path to the APK file that failed to install.
  final String? apkPath;

  /// The device ID where installation was attempted.
  final String? deviceId;

  /// The exit code from the ADB install command, if available.
  final int? exitCode;

  /// Creates a new [AdbInstallationException].
  AdbInstallationException(
    super.message, {
    this.apkPath,
    this.deviceId,
    this.exitCode,
  });
}
