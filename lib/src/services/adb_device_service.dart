import 'dart:io';

import 'package:adb_dart/src/device_id.dart';
import 'package:adb_dart/src/exceptions/adb_device_exception.dart';
import 'package:adb_dart/src/logging/adb_logger.dart';
import 'package:adb_dart/src/logging/default_logger.dart';
import 'package:adb_dart/src/models/android_device.dart';

/// Service for managing Android device discovery and communication.
class AdbDeviceService {
  /// Absolute path to the adb executable.
  final String adbExecutablePath;

  /// Logger instance for ADB operations.
  final AdbLogger _logger;

  /// Creates a new [AdbDeviceService].
  ///
  /// Optionally provide a custom [logger] to receive log messages
  /// from ADB operations. If not provided, a default console logger is used.
  AdbDeviceService({
    required this.adbExecutablePath,
    AdbLogger? logger,
  }) : _logger = logger ?? const DefaultLogger();

  /// Lists all Android devices currently connected via ADB.
  ///
  /// Only devices in the `device` state are returned.
  ///
  /// Throws [AdbDeviceException] if the ADB command fails or
  /// returns a non-zero exit code.
  Future<Iterable<AndroidDevice>> listConnectedDevices() async {
    _logger.debug('Searching connected devices');

    final result = await Process.run(adbExecutablePath, ['devices', '-l']);

    if (result.exitCode != 0) {
      final stderr = result.stderr.toString();
      _logger.error('Error fetching devices: $stderr');
      throw AdbDeviceException(
        'Failed to list devices: $stderr',
        exitCode: result.exitCode,
      );
    }

    final lines = (result.stdout as String).split('\n');
    final devices = <AndroidDevice>[];

    for (var line in lines) {
      line = line.trim();

      if (line.isEmpty || line.startsWith('List of devices')) {
        continue;
      }

      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 2 || parts[1] != 'device') {
        continue;
      }

      final DeviceId deviceId = parts[0];
      String name = deviceId;
      String manufacturer = 'Unknown';

      for (final part in parts.skip(2)) {
        if (part.startsWith('model:')) {
          name = part.replaceFirst('model:', '');
        } else if (part.startsWith('manufacturer:')) {
          manufacturer = part.replaceFirst('manufacturer:', '');
        }
      }

      devices.add(
        AndroidDevice(
          manufacturer: manufacturer,
          name: name,
          deviceId: deviceId,
        ),
      );
    }

    _logger.info('Found ${devices.length} devices');
    return devices;
  }
}
