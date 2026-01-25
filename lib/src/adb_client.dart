import 'dart:io';

import 'package:adb_dart/src/device_id.dart';
import 'package:adb_dart/src/exceptions/adb_initialization_exception.dart';
import 'package:adb_dart/src/logging/adb_logger.dart';
import 'package:adb_dart/src/logging/default_logger.dart';
import 'package:adb_dart/src/models/android_device.dart';
import 'package:adb_dart/src/models/file_entry.dart';
import 'package:adb_dart/src/models/logcat_level.dart';
import 'package:adb_dart/src/services/adb_device_service.dart';
import 'package:adb_dart/src/services/adb_file_system_service.dart';
import 'package:adb_dart/src/services/adb_logcat_service.dart';
import 'package:adb_dart/src/services/adb_package_service.dart';
import 'package:adb_dart/src/services/adb_property_service.dart';

/// A lightweight ADB client used to interact with Android devices
/// through the Android Debug Bridge executable.
class AdbClient {
  /// Absolute path to the adb executable.
  final String adbExecutablePath;

  /// Logger instance for ADB operations.
  final AdbLogger _logger;

  /// Service for device management operations.
  late final AdbDeviceService _deviceService;

  /// Service for package management operations.
  late final AdbPackageService _packageService;

  /// Service for system property operations.
  late final AdbPropertyService _propertyService;

  /// Service for logcat operations.
  late final AdbLogcatService _logcatService;

  /// Service for file system operations.
  late final AdbFileSystemService _fileSystemService;

  /// Creates a new [AdbClient].
  ///
  /// Optionally provide a custom [logger] to receive log messages
  /// from ADB operations. If not provided, a default console logger is used.
  ///
  /// Throws an [AdbInitializationException] if the adb executable
  /// does not exist at the provided path.
  AdbClient({
    required this.adbExecutablePath,
    AdbLogger? logger,
  }) : _logger = logger ?? const DefaultLogger() {
    final file = File(adbExecutablePath);

    if (!file.existsSync()) {
      throw AdbInitializationException(path: file.path);
    }

    // Initialize services
    _deviceService = AdbDeviceService(
      adbExecutablePath: adbExecutablePath,
      logger: _logger,
    );
    _packageService = AdbPackageService(
      adbExecutablePath: adbExecutablePath,
      logger: _logger,
    );
    _propertyService = AdbPropertyService(
      adbExecutablePath: adbExecutablePath,
      logger: _logger,
    );
    _logcatService = AdbLogcatService(
      adbExecutablePath: adbExecutablePath,
      logger: _logger,
    );
    _fileSystemService = AdbFileSystemService(
      adbExecutablePath: adbExecutablePath,
      logger: _logger,
    );
  }

  /// Lists all Android devices currently connected via ADB.
  ///
  /// Only devices in the `device` state are returned.
  ///
  /// Throws [AdbDeviceException] if the ADB command fails or
  /// returns a non-zero exit code.
  Future<Iterable<AndroidDevice>> listConnectedDevices() =>
      _deviceService.listConnectedDevices();

  /// Installs an APK on the specified Android device.
  ///
  /// Throws [AdbInstallationException] if:
  /// - The provided file is not an APK
  /// - The APK file does not exist
  /// - The installation fails on the device
  /// - ADB returns a non-zero exit code
  Future<void> installApplication(File apkFile, DeviceId deviceId) =>
      _packageService.installApplication(apkFile, deviceId);

  /// Retrieves all third-party installed package names on a device.
  ///
  /// Throws [AdbPackageException] if the command fails or returns
  /// a non-zero exit code.
  Future<Iterable<String>> getAllPackages(DeviceId deviceId) =>
      _packageService.getAllPackages(deviceId);

  /// Retrieves all system properties of a connected Android device.
  ///
  /// The result is returned as a map where the key is the property
  /// name and the value is the associated property value.
  ///
  /// Throws [AdbPropertyException] if the ADB command fails or
  /// returns a non-zero exit code.
  Future<Map<String, String>> getProperties(DeviceId deviceId) =>
      _propertyService.getProperties(deviceId);

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
  }) =>
      _logcatService.listenLogcat(
        deviceId,
        level: level,
        processId: processId,
      );

  /// Clears the logcat buffer on the specified device.
  ///
  /// Useful before starting a new logcat session.
  ///
  /// Throws [AdbLogcatException] if the command fails or returns
  /// a non-zero exit code.
  Future<void> clearLogcat(DeviceId deviceId) =>
      _logcatService.clearLogcat(deviceId);

  /// Lists files and directories at the specified path on a device.
  ///
  /// If [packageName] is provided, uses `run-as` to access the package's
  /// private directory with proper permissions.
  ///
  /// Returns a list of [FileEntry] objects representing the contents.
  Future<Iterable<FileEntry>> listFiles(
    String path,
    DeviceId deviceId, {
    String? packageName,
  }) =>
      _fileSystemService.listFiles(path, deviceId, packageName: packageName);

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
  }) =>
      _fileSystemService.deleteFile(filePath, deviceId,
          packageName: packageName);

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
  }) =>
      _fileSystemService.createDirectory(path, name, deviceId,
          packageName: packageName);

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
  }) =>
      _fileSystemService.downloadFile(
        filePath,
        destinationPath,
        deviceId,
        packageName: packageName,
      );

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
  }) =>
      _fileSystemService.uploadFile(
        localFilePath,
        destinationPath,
        deviceId,
        packageName: packageName,
      );
}
