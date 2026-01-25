import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:adb_dart/src/device_id.dart';
import 'package:adb_dart/src/exceptions/adb_initialization_exception.dart';
import 'package:adb_dart/src/models/android_device.dart';
import 'package:adb_dart/src/models/logcat_level.dart';

/// A lightweight ADB client used to interact with Android devices
/// through the Android Debug Bridge executable.
class AdbClient {
  /// Absolute path to the adb executable.
  final String adbExecutablePath;

  /// Creates a new [AdbClient].
  ///
  /// Throws an [AdbInitializationException] if the adb executable
  /// does not exist at the provided path.
  AdbClient({required this.adbExecutablePath}) {
    final file = File(adbExecutablePath);

    if (!file.existsSync()) {
      throw AdbInitializationException(path: file.path);
    }
  }

  /// Lists all Android devices currently connected via ADB.
  ///
  /// Only devices in the `device` state are returned.
  /// If an error occurs, an empty list is returned.
  Future<Iterable<AndroidDevice>> listConnectedDevices() async {
    try {
      log('Searching connected devices');

      final result = await Process.run(adbExecutablePath, ['devices', '-l']);

      if (result.exitCode != 0) {
        log('Error fetching devices: ${result.stderr}');
        return const [];
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

      log('Found ${devices.length} devices');
      return devices;
    } catch (e, stack) {
      log('Exception while fetching devices', error: e, stackTrace: stack);
      return const [];
    }
  }

  /// Installs an APK on the specified Android device.
  ///
  /// The installation fails silently if the provided file
  /// is not an APK or if ADB returns a non-zero exit code.
  Future<void> installApplication(File apkFile, DeviceId deviceId) async {
    try {
      if (!apkFile.path.endsWith('.apk')) {
        log('Provided file is not an APK: ${apkFile.path}');
        return;
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
        log('ADB install error: ${stderrBuffer.toString()}');
        throw Exception('Failed to install APK');
      }

      log('APK installed successfully: ${stdoutBuffer.toString()}');
    } catch (e, stack) {
      log(
        'Error while installing APK: ${apkFile.path}',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Retrieves all third-party installed package names on a device.
  ///
  /// Returns an empty list if the command fails.
  Future<Iterable<String>> getAllPackages(DeviceId deviceId) async {
    try {
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
        log(stderr.trim());
      }

      if (exitCode != 0) {
        log('Failed to list packages (exitCode=$exitCode)');
        return const [];
      }

      return stdout
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.startsWith('package:'))
          .map((line) => line.substring('package:'.length))
          .where((pkg) => pkg.isNotEmpty)
          .toList();
    } catch (e, stack) {
      log(
        'Exception while listing packages for device $deviceId',
        error: e,
        stackTrace: stack,
      );
      return const [];
    }
  }

  /// Retrieves all system properties of a connected Android device.
  ///
  /// The result is returned as a map where the key is the property
  /// name and the value is the associated property value.
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
      log('ADB error: ${stderrBuffer.toString()}');
      throw Exception('Unable to retrieve device properties');
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

  /// Starts listening to the logcat output of a device.
  ///
  /// Logs are buffered and emitted periodically as batches
  /// to avoid flooding the stream.
  Stream<Iterable<String>> listenLogcat(
    DeviceId deviceId, {
    LogcatLevel? level,
    int? processId,
  }) async* {
    if (deviceId.isEmpty) {
      log('Device id is empty, logcat listener aborted');
      return;
    }

    final args = <String>['-s', deviceId, 'logcat'];

    if (level != null) {
      args.add('*:${_mapLevel(level)}');
    }

    if (processId != null) {
      args.addAll(['--pid', processId.toString()]);
    }

    final process = await Process.start(adbExecutablePath, args);

    final buffer = <String>[];
    final controller = StreamController<Iterable<String>>();
    Timer? timer;

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            buffer.add(line);

            timer ??= Timer.periodic(const Duration(milliseconds: 250), (_) {
              if (buffer.isNotEmpty) {
                controller.add(List.from(buffer));
                buffer.clear();
              }
            });
          },
          onDone: () {
            timer?.cancel();
            if (buffer.isNotEmpty) {
              controller.add(List.from(buffer));
            }
            controller.close();
          },
        );

    yield* controller.stream;
  }

  /// Clears the logcat buffer on the specified device.
  ///
  /// Useful before starting a new logcat session.
  Future<void> clearLogcat(DeviceId deviceId) async {
    try {
      log('Clearing logcat');

      final result = await Process.run(adbExecutablePath, [
        '-s',
        deviceId,
        'logcat',
        '-c',
      ]);

      if (result.exitCode != 0) {
        log('Error while clearing logcat: ${result.stderr}');
      } else {
        log('Logcat cleared successfully');
      }
    } catch (e, stack) {
      log('Exception while clearing logcat', error: e, stackTrace: stack);
    }
  }

  /// Maps a [LogcatLevel] enum to its corresponding
  /// single-letter ADB logcat representation.
  String _mapLevel(LogcatLevel level) {
    switch (level) {
      case LogcatLevel.verbose:
        return 'V';
      case LogcatLevel.debug:
        return 'D';
      case LogcatLevel.info:
        return 'I';
      case LogcatLevel.warning:
        return 'W';
      case LogcatLevel.error:
        return 'E';
      case LogcatLevel.fatal:
        return 'F';
    }
  }
}
