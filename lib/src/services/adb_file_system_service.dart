import 'dart:io';

import 'package:adb_dart/src/device_id.dart';
import 'package:adb_dart/src/logging/adb_logger.dart';
import 'package:adb_dart/src/logging/default_logger.dart';
import 'package:adb_dart/src/models/file_entry.dart';
import 'package:adb_dart/src/models/file_type.dart';

/// Service for managing file system operations on Android devices.
///
/// Handles both public and private (app-specific) file operations.
/// When a [packageName] is provided, the service uses `run-as` to access
/// the package's private directories with proper permissions.
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
  /// package's private directory. The [filePath] should be relative to the
  /// package's data directory when using [packageName].
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

    final escaped = filePath.replaceAll("'", r"'\''");

    if (packageName != null) {
      command = [
        '-s',
        deviceId,
        'shell',
        'run-as',
        packageName,
        'rm',
        '-rf',
        "'$escaped'",
      ];
    } else {
      command = ['-s', deviceId, 'shell', 'rm', '-rf', "'$escaped'"];
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
  /// in the package's private directory. The [path] and [name] should be
  /// relative to the package's data directory when using [packageName].
  ///
  /// Uses `mkdir -p` to create parent directories as needed.
  Future<void> createDirectory(
    String path,
    String name,
    DeviceId deviceId, {
    String? packageName,
  }) async {
    if (name.isEmpty) return;

    final fullPath = path.isEmpty
        ? name
        : (path.endsWith('/') ? '$path$name' : '$path/$name');
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
      final escaped = fullPath.replaceAll("'", r"'\''");
      command = ['-s', deviceId, 'shell', 'mkdir', '-p', "'$escaped'"];
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
  /// files from the package's private directory. The [filePath] should be
  /// relative to the package's data directory when using [packageName].
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
  /// If [packageName] is provided, uploads to /data/local/tmp first, then uses
  /// `run-as` to copy the file to the package's private directory. The
  /// [destinationPath] should be relative to the package's data directory
  /// when using [packageName].
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
      final tmpPath = '/data/local/tmp/$fileName';

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

      // Determine the relative target path within the app directory
      final target = destinationPath.isNotEmpty ? destinationPath : fileName;

      // Escape paths for shell commands to handle spaces
      final escapedTmpPath = tmpPath.replaceAll("'", r"'\''");
      final escapedTarget = target.replaceAll("'", r"'\''");

      final copyResult = await Process.run(adbExecutablePath, [
        '-s',
        deviceId,
        'shell',
        'run-as',
        packageName,
        'cp',
        "'$escapedTmpPath'",
        "'$escapedTarget'",
      ]);

      // Escape tmpPath for rm command as well
      await Process.run(
          adbExecutablePath, ['-s', deviceId, 'shell', 'rm', "'$escapedTmpPath'"]);

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
