import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:adb_dart/src/device_id.dart';
import 'package:adb_dart/src/exceptions/adb_property_exception.dart';
import 'package:adb_dart/src/logging/adb_logger.dart';
import 'package:adb_dart/src/logging/default_logger.dart';

/// Service for retrieving Android device system properties.
class AdbPropertyService {
  /// Absolute path to the adb executable.
  final String adbExecutablePath;

  /// Logger instance for ADB operations.
  final AdbLogger _logger;

  /// Creates a new [AdbPropertyService].
  ///
  /// Optionally provide a custom [logger] to receive log messages
  /// from ADB operations. If not provided, a default console logger is used.
  AdbPropertyService({
    required this.adbExecutablePath,
    AdbLogger? logger,
  }) : _logger = logger ?? const DefaultLogger();

  /// Retrieves all system properties of a connected Android device.
  ///
  /// The result is returned as a map where the key is the property
  /// name and the value is the associated property value.
  ///
  /// Throws [AdbPropertyException] if the ADB command fails or
  /// returns a non-zero exit code.
  Future<Map<String, String>> getProperties(DeviceId deviceId) async {
    final process = await Process.start(adbExecutablePath, [
      '-s',
      deviceId,
      'shell',
      'getprop',
    ]);

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    process.stdout.transform(utf8.decoder).listen(stdoutBuffer.write);
    process.stderr.transform(utf8.decoder).listen(stderrBuffer.write);

    final exitCode = await process.exitCode;

    if (exitCode != 0) {
      final stderr = stderrBuffer.toString();
      _logger.error('ADB error: $stderr');
      throw AdbPropertyException(
        'Unable to retrieve device properties: $stderr',
        deviceId: deviceId,
        exitCode: exitCode,
      );
    }

    final lines = stdoutBuffer.toString().split('\n');
    final properties = <String, String>{};
    final regex = RegExp(r'^\[(.+?)\]: \[(.*?)\]$');

    for (final line in lines) {
      final match = regex.firstMatch(line.trim());
      if (match == null) continue;

      properties[match.group(1)!] = match.group(2)!;
    }

    return properties;
  }
}
