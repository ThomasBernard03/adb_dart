import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:adb_dart/src/device_id.dart';
import 'package:adb_dart/src/exceptions/adb_installation_exception.dart';
import 'package:adb_dart/src/exceptions/adb_package_exception.dart';
import 'package:adb_dart/src/logging/adb_logger.dart';
import 'package:adb_dart/src/logging/default_logger.dart';

/// Service for managing application installation and package operations.
class AdbPackageService {
  /// Absolute path to the adb executable.
  final String adbExecutablePath;

  /// Logger instance for ADB operations.
  final AdbLogger _logger;

  /// Creates a new [AdbPackageService].
  ///
  /// Optionally provide a custom [logger] to receive log messages
  /// from ADB operations. If not provided, a default console logger is used.
  AdbPackageService({
    required this.adbExecutablePath,
    AdbLogger? logger,
  }) : _logger = logger ?? const DefaultLogger();

  /// Installs an APK on the specified Android device.
  ///
  /// Throws [AdbInstallationException] if:
  /// - The provided file is not an APK
  /// - The APK file does not exist
  /// - The installation fails on the device
  /// - ADB returns a non-zero exit code
  Future<void> installApplication(File apkFile, DeviceId deviceId) async {
    if (!apkFile.path.endsWith('.apk')) {
      _logger.error('Provided file is not an APK: ${apkFile.path}');
      throw AdbInstallationException(
        'Provided file is not an APK: ${apkFile.path}',
        apkPath: apkFile.path,
        deviceId: deviceId,
      );
    }

    final process = await Process.start(adbExecutablePath, [
      '-s',
      deviceId,
      'install',
      apkFile.path,
    ]);

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    process.stdout.transform(utf8.decoder).listen(stdoutBuffer.write);
    process.stderr.transform(utf8.decoder).listen(stderrBuffer.write);

    final exitCode = await process.exitCode;

    if (exitCode != 0) {
      final stderr = stderrBuffer.toString();
      _logger.error('ADB install error: $stderr');
      throw AdbInstallationException(
        'Failed to install APK: $stderr',
        apkPath: apkFile.path,
        deviceId: deviceId,
        exitCode: exitCode,
      );
    }

    _logger.info('APK installed successfully: ${stdoutBuffer.toString()}');
  }

  /// Retrieves all third-party installed package names on a device.
  ///
  /// Throws [AdbPackageException] if the command fails or returns
  /// a non-zero exit code.
  Future<Iterable<String>> getAllPackages(DeviceId deviceId) async {
    final process = await Process.start(adbExecutablePath, [
      '-s',
      deviceId,
      'shell',
      'pm',
      'list',
      'packages',
      '-3',
    ]);

    final stdout = await process.stdout.transform(utf8.decoder).join();
    final stderr = await process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode;

    if (stderr.isNotEmpty) {
      _logger.error(stderr.trim());
    }

    if (exitCode != 0) {
      _logger.error('Failed to list packages (exitCode=$exitCode)');
      throw AdbPackageException(
        'Failed to list packages: $stderr',
        deviceId: deviceId,
        exitCode: exitCode,
      );
    }

    return stdout
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.startsWith('package:'))
        .map((line) => line.substring('package:'.length))
        .where((pkg) => pkg.isNotEmpty)
        .toList();
  }
}
