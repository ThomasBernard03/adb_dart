import 'dart:io';

import 'package:adb_dart/src/device_id.dart';
import 'package:adb_dart/src/logging/adb_logger.dart';
import 'package:adb_dart/src/logging/default_logger.dart';
import 'package:adb_dart/src/models/file_entry.dart';
import 'package:adb_dart/src/models/file_type.dart';

/// Service for managing file system operations on Android devices.
///
/// Handles both public and private (app-specific) file operations,
/// using run-as when necessary to access package-private directories.
class AdbFileSystemService {
  /// Absolute path to the adb executable.
  final String adbExecutablePath;

  /// Logger instance for ADB operations.
  final AdbLogger _logger;

  /// Creates a new [AdbFileSystemService].
  ///
  /// Optionally provide a custom [logger] to receive log messages
  /// from ADB operations. If not provided, a default console logger is used.
  AdbFileSystemService({
    required this.adbExecutablePath,
    AdbLogger? logger,
  }) : _logger = logger ?? const DefaultLogger();

  /// Parses a path to determine if it's a private app path (/data/data/).
  /// Returns the package name and optional subpath if it's a private path.
  ({String package, String? subPath})? _parsePrivateAppPath(String path) {
    if (!path.startsWith('/data/data/')) return null;

    final parts = path.split('/');
    if (parts.length < 4) return null;

    final package = parts[3];
    final subPath = parts.length > 4 ? parts.sublist(4).join('/') : null;

    return (package: package, subPath: subPath);
  }

  /// Parses a single line from `ls -l` output into a [FileEntry].
  FileEntry _parseLsLine(String line) {
    final regex = RegExp(
      r'^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+'
      r'(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2})\s+(.+)$',
    );

    final match = regex.firstMatch(line);

    if (match == null) {
      return FileEntry(
        type: FileType.unknown,
        permissions: line.split(' ').first,
        name: line.split(' ').last,
      );
    }

    final perm = match.group(1)!;
    final namePart = match.group(8)!;

    final type = perm.startsWith('d')
        ? FileType.directory
        : perm.startsWith('l')
            ? FileType.symlink
            : FileType.file;

    String name = namePart;
    String? symlinkTarget;

    if (type == FileType.symlink && namePart.contains('->')) {
      final split = namePart.split('->');
      name = split[0].trim();
      symlinkTarget = split[1].trim();
    }

    return FileEntry(
      type: type,
      permissions: perm,
      links: int.tryParse(match.group(2)!),
      owner: match.group(3),
      group: match.group(4),
      size: int.tryParse(match.group(5)!),
      date: DateTime.tryParse('${match.group(6)} ${match.group(7)}'),
      name: name,
      symlinkTarget: symlinkTarget,
    );
  }

  /// Parses the output from `ls -l` into a list of [FileEntry] objects.
  List<FileEntry> _parseLsOutput(String output) {
    return output
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .skip(1) // Skip the total line
        .map(_parseLsLine)
        .toList();
  }

  /// Lists files and directories at the specified path on a device.
  ///
  /// If [packageName] is provided, uses `run-as` to access the package's
  /// private directory with proper permissions.
  ///
  /// Returns a list of [FileEntry] objects representing the contents.
  Future<List<FileEntry>> listFiles(
    String path,
    DeviceId deviceId, {
    String? packageName,
  }) async {
    _logger.debug('Listing files at: $path');

    final List<String> command;

    if (packageName != null) {
      command = [
        '-s',
        deviceId,
        'shell',
        'run-as',
        packageName,
        'ls',
        '-l',
        path
      ];
    } else {
      command = ['-s', deviceId, 'shell', 'ls', '-l', path];
    }

    final result = await Process.run(adbExecutablePath, command);

    if (result.exitCode != 0) {
      final stderr = result.stderr.toString();
      _logger.error('Error listing files: $stderr');
      return [];
    }

    return _parseLsOutput(result.stdout as String);
  }

  /// Deletes a file or directory on the specified device.
  ///
  /// If [packageName] is provided, uses `run-as` to delete files in the
  /// package's private directory.
  ///
  /// Uses `rm -rf` to recursively delete directories.
  Future<void> deleteFile(
    String filePath,
    DeviceId deviceId, {
    String? packageName,
  }) async {
    if (filePath.isEmpty) return;

    _logger.debug('Deleting file: $filePath');

    final List<String> command;

    if (packageName != null) {
      command = [
        '-s',
        deviceId,
        'shell',
        'run-as',
        packageName,
        'rm',
        '-rf',
        filePath,
      ];
    } else {
      final privatePath = _parsePrivateAppPath(filePath);

      if (privatePath != null) {
        final target = privatePath.subPath ?? '.';
        command = [
          '-s',
          deviceId,
          'shell',
          'run-as',
          privatePath.package,
          'rm',
          '-rf',
          target,
        ];
      } else {
        final escaped = filePath.replaceAll("'", r"'\''");
        command = ['-s', deviceId, 'shell', 'rm', '-rf', "'$escaped'"];
      }
    }

    final result = await Process.run(adbExecutablePath, command);

    if (result.exitCode != 0) {
      final stderr = result.stderr.toString();
      _logger.error('Delete failed: $stderr');
    }
  }

  /// Creates a directory on the specified device.
  ///
  /// If [packageName] is provided, uses `run-as` to create the directory
  /// in the package's private directory.
  ///
  /// Uses `mkdir -p` to create parent directories as needed.
  Future<void> createDirectory(
    String path,
    String name,
    DeviceId deviceId, {
    String? packageName,
  }) async {
    if (path.isEmpty || name.isEmpty) return;

    final fullPath = path.endsWith('/') ? '$path$name' : '$path/$name';
    _logger.debug('Creating directory: $fullPath');

    final List<String> command;

    if (packageName != null) {
      command = [
        '-s',
        deviceId,
        'shell',
        'run-as',
        packageName,
        'mkdir',
        '-p',
        fullPath,
      ];
    } else {
      final privatePath = _parsePrivateAppPath(fullPath);

      if (privatePath != null) {
        final target = privatePath.subPath ?? name;
        command = [
          '-s',
          deviceId,
          'shell',
          'run-as',
          privatePath.package,
          'mkdir',
          '-p',
          target,
        ];
      } else {
        final escaped = fullPath.replaceAll("'", r"'\''");
        command = ['-s', deviceId, 'shell', 'mkdir', '-p', "'$escaped'"];
      }
    }

    final result = await Process.run(adbExecutablePath, command);

    if (result.exitCode != 0) {
      final stderr = result.stderr.toString();
      _logger.error('mkdir failed: $stderr');
    }
  }

  /// Downloads a file from the device to the local filesystem.
  ///
  /// If [packageName] is provided, uses `run-as` with `exec-out` to download
  /// files from the package's private directory.
  ///
  /// Falls back to standard `adb pull` for public files.
  Future<void> downloadFile(
    String filePath,
    String destinationPath,
    DeviceId deviceId, {
    String? packageName,
  }) async {
    if (filePath.isEmpty || destinationPath.isEmpty) return;

    _logger.debug('Downloading file: $filePath -> $destinationPath');

    if (packageName != null) {
      final localFile = File(destinationPath);
      await localFile.parent.create(recursive: true);

      final process = await Process.start(adbExecutablePath, [
        '-s',
        deviceId,
        'exec-out',
        'run-as',
        packageName,
        'cat',
        filePath,
      ]);

      final sink = localFile.openWrite();
      await process.stdout.pipe(sink);
      await sink.close();

      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        _logger.error('Download failed (exec-out)');
      }
      return;
    }

    final privatePath = _parsePrivateAppPath(filePath);

    if (privatePath != null) {
      final localFile = File(destinationPath);
      await localFile.parent.create(recursive: true);

      final process = await Process.start(adbExecutablePath, [
        '-s',
        deviceId,
        'exec-out',
        'run-as',
        privatePath.package,
        'cat',
        filePath,
      ]);

      final sink = localFile.openWrite();
      await process.stdout.pipe(sink);
      await sink.close();

      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        _logger.error('Download failed (exec-out)');
      }
      return;
    }

    final result = await Process.run(adbExecutablePath, [
      '-s',
      deviceId,
      'pull',
      filePath,
      destinationPath,
    ]);

    if (result.exitCode != 0) {
      final stderr = result.stderr.toString();
      _logger.error('Download failed: $stderr');
    }
  }

  /// Uploads a file from the local filesystem to the device.
  ///
  /// If [packageName] is provided, uploads to /sdcard first, then uses
  /// `run-as` to copy the file to the package's private directory.
  ///
  /// Falls back to standard `adb push` for public destinations.
  Future<void> uploadFile(
    String localFilePath,
    String destinationPath,
    DeviceId deviceId, {
    String? packageName,
  }) async {
    final file = File(localFilePath);
    if (!await file.exists()) {
      _logger.error('Local file does not exist: $localFilePath');
      return;
    }

    _logger.debug('Uploading file: $localFilePath -> $destinationPath');

    if (packageName != null) {
      final fileName = file.uri.pathSegments.last;
      final tmpPath = '/sdcard/$fileName';

      final pushResult = await Process.run(adbExecutablePath, [
        '-s',
        deviceId,
        'push',
        localFilePath,
        tmpPath,
      ]);

      if (pushResult.exitCode != 0) {
        _logger.error(
            'Failed to push to temporary location: ${pushResult.stderr}');
        return;
      }

      final copyResult = await Process.run(adbExecutablePath, [
        '-s',
        deviceId,
        'shell',
        'run-as',
        packageName,
        'cp',
        tmpPath,
        destinationPath,
      ]);

      await Process.run(
          adbExecutablePath, ['-s', deviceId, 'shell', 'rm', tmpPath]);

      if (copyResult.exitCode != 0) {
        final stderr = copyResult.stderr.toString();
        _logger.error('Upload failed (private): $stderr');
      }
      return;
    }

    final privatePath = _parsePrivateAppPath(destinationPath);

    if (privatePath != null) {
      final fileName = file.uri.pathSegments.last;
      final tmpPath = '/sdcard/$fileName';

      final pushResult = await Process.run(adbExecutablePath, [
        '-s',
        deviceId,
        'push',
        localFilePath,
        tmpPath,
      ]);

      if (pushResult.exitCode != 0) {
        _logger.error(
            'Failed to push to temporary location: ${pushResult.stderr}');
        return;
      }

      final target = privatePath.subPath != null
          ? '${privatePath.subPath}/$fileName'
          : fileName;

      final copyResult = await Process.run(adbExecutablePath, [
        '-s',
        deviceId,
        'shell',
        'run-as',
        privatePath.package,
        'cp',
        tmpPath,
        target,
      ]);

      await Process.run(
          adbExecutablePath, ['-s', deviceId, 'shell', 'rm', tmpPath]);

      if (copyResult.exitCode != 0) {
        final stderr = copyResult.stderr.toString();
        _logger.error('Upload failed (private): $stderr');
      }
      return;
    }

    final result = await Process.run(adbExecutablePath, [
      '-s',
      deviceId,
      'push',
      localFilePath,
      destinationPath,
    ]);

    if (result.exitCode != 0) {
      final stderr = result.stderr.toString();
      _logger.error('Upload failed: $stderr');
    }
  }
}
