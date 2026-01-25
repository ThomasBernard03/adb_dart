import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:adb_dart/src/device_id.dart';
import 'package:adb_dart/src/exceptions/adb_logcat_exception.dart';
import 'package:adb_dart/src/logging/adb_logger.dart';
import 'package:adb_dart/src/logging/default_logger.dart';
import 'package:adb_dart/src/models/logcat_level.dart';

/// Service for managing logcat streaming and buffer operations.
class AdbLogcatService {
  /// Absolute path to the adb executable.
  final String adbExecutablePath;

  /// Logger instance for ADB operations.
  final AdbLogger _logger;

  /// Creates a new [AdbLogcatService].
  ///
  /// Optionally provide a custom [logger] to receive log messages
  /// from ADB operations. If not provided, a default console logger is used.
  AdbLogcatService({
    required this.adbExecutablePath,
    AdbLogger? logger,
  }) : _logger = logger ?? const DefaultLogger();

  /// Starts listening to the logcat output of a device.
  ///
  /// Logs are buffered and emitted periodically as batches
  /// to avoid flooding the stream.
  ///
  /// Throws [AdbLogcatException] if the deviceId is empty or invalid.
  Stream<Iterable<String>> listenLogcat(
    DeviceId deviceId, {
    LogcatLevel? level,
    int? processId,
  }) async* {
    if (deviceId.isEmpty) {
      _logger.error('Device id is empty, logcat listener aborted');
      throw AdbLogcatException(
        'Device id is empty',
        deviceId: deviceId,
      );
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
  ///
  /// Throws [AdbLogcatException] if the command fails or returns
  /// a non-zero exit code.
  Future<void> clearLogcat(DeviceId deviceId) async {
    _logger.debug('Clearing logcat');

    final result = await Process.run(adbExecutablePath, [
      '-s',
      deviceId,
      'logcat',
      '-c',
    ]);

    if (result.exitCode != 0) {
      final stderr = result.stderr.toString();
      _logger.error('Error while clearing logcat: $stderr');
      throw AdbLogcatException(
        'Failed to clear logcat: $stderr',
        deviceId: deviceId,
        exitCode: result.exitCode,
      );
    }

    _logger.info('Logcat cleared successfully');
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
