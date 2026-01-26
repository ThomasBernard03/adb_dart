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

  /// Uninstalls an application from the device.
  ///
  /// Throws [AdbPackageException] if the uninstallation fails.
  Future<void> uninstallApplication(
    String packageName,
    DeviceId deviceId, {
    bool keepData = false,
  }) async {
    _logger.debug('Uninstalling $packageName from device $deviceId');

    final args = ['-s', deviceId, 'uninstall'];
    if (keepData) {
      args.add('-k');
    }
    args.add(packageName);

    final result = await Process.run(adbExecutablePath, args);

    if (result.exitCode != 0 ||
        (result.stdout as String).toLowerCase().contains('failure')) {
      final error = result.stderr.toString().isNotEmpty
          ? result.stderr.toString()
          : result.stdout.toString();
      _logger.error('Failed to uninstall $packageName: $error');
      throw AdbPackageException(
        'Failed to uninstall $packageName: $error',
        deviceId: deviceId,
        exitCode: result.exitCode,
      );
    }

    _logger.info('Successfully uninstalled $packageName');
  }

  /// Clears all data for an application on the device.
  ///
  /// This removes all app data including cache, databases, and shared preferences.
  ///
  /// Throws [AdbPackageException] if the operation fails.
  Future<void> clearAppData(String packageName, DeviceId deviceId) async {
    _logger.debug('Clearing data for $packageName on device $deviceId');

    final result = await Process.run(
      adbExecutablePath,
      ['-s', deviceId, 'shell', 'pm', 'clear', packageName],
    );

    final output = result.stdout as String;

    if (result.exitCode != 0 || !output.toLowerCase().contains('success')) {
      final error = result.stderr.toString().isNotEmpty
          ? result.stderr.toString()
          : output;
      _logger.error('Failed to clear data for $packageName: $error');
      throw AdbPackageException(
        'Failed to clear data for $packageName: $error',
        deviceId: deviceId,
        exitCode: result.exitCode,
      );
    }

    _logger.info('Successfully cleared data for $packageName');
  }

  /// Force stops an application on the device.
  ///
  /// This terminates all processes associated with the package.
  ///
  /// Throws [AdbPackageException] if the operation fails.
  Future<void> forceStopApp(String packageName, DeviceId deviceId) async {
    _logger.debug('Force stopping $packageName on device $deviceId');

    final result = await Process.run(
      adbExecutablePath,
      ['-s', deviceId, 'shell', 'am', 'force-stop', packageName],
    );

    if (result.exitCode != 0) {
      final error = result.stderr.toString();
      _logger.error('Failed to force stop $packageName: $error');
      throw AdbPackageException(
        'Failed to force stop $packageName: $error',
        deviceId: deviceId,
        exitCode: result.exitCode,
      );
    }

    _logger.info('Successfully force stopped $packageName');
  }

  /// Starts an activity on the device.
  ///
  /// [packageName] is the package name (e.g., 'com.example.app').
  /// [activityName] is the activity class name (e.g., '.MainActivity' or full name).
  ///
  /// Throws [AdbPackageException] if the activity cannot be started.
  Future<void> startActivity(
    String packageName,
    String activityName,
    DeviceId deviceId, {
    Map<String, String>? extras,
    String? action,
    String? data,
  }) async {
    _logger.debug('Starting $packageName/$activityName on device $deviceId');

    final args = ['-s', deviceId, 'shell', 'am', 'start', '-n'];

    // Build component name
    final component = activityName.startsWith('.')
        ? '$packageName/$packageName$activityName'
        : '$packageName/$activityName';
    args.add(component);

    // Add action if specified
    if (action != null) {
      args.addAll(['-a', action]);
    }

    // Add data URI if specified
    if (data != null) {
      args.addAll(['-d', data]);
    }

    // Add extras if specified
    if (extras != null) {
      for (final entry in extras.entries) {
        args.addAll(['--es', entry.key, entry.value]);
      }
    }

    final result = await Process.run(adbExecutablePath, args);
    final output = result.stdout as String;

    if (result.exitCode != 0 || output.toLowerCase().contains('error')) {
      final error = result.stderr.toString().isNotEmpty
          ? result.stderr.toString()
          : output;
      _logger.error('Failed to start activity: $error');
      throw AdbPackageException(
        'Failed to start activity $component: $error',
        deviceId: deviceId,
        exitCode: result.exitCode,
      );
    }

    _logger.info('Successfully started $component');
  }

  /// Launches an application using its main/launcher activity.
  ///
  /// This is equivalent to tapping the app icon on the home screen.
  ///
  /// Throws [AdbPackageException] if the app cannot be launched.
  Future<void> launchApp(String packageName, DeviceId deviceId) async {
    _logger.debug('Launching $packageName on device $deviceId');

    final result = await Process.run(
      adbExecutablePath,
      [
        '-s',
        deviceId,
        'shell',
        'monkey',
        '-p',
        packageName,
        '-c',
        'android.intent.category.LAUNCHER',
        '1',
      ],
    );

    final output = result.stdout as String;

    if (result.exitCode != 0 ||
        output.toLowerCase().contains('no activities found')) {
      final error = result.stderr.toString().isNotEmpty
          ? result.stderr.toString()
          : output;
      _logger.error('Failed to launch $packageName: $error');
      throw AdbPackageException(
        'Failed to launch $packageName: $error',
        deviceId: deviceId,
        exitCode: result.exitCode,
      );
    }

    _logger.info('Successfully launched $packageName');
  }
}
