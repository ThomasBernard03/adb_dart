import 'dart:io';

import 'package:adb_dart/src/device_id.dart';
import 'package:adb_dart/src/exceptions/adb_initialization_exception.dart';
import 'package:adb_dart/src/logging/adb_logger.dart';
import 'package:adb_dart/src/logging/default_logger.dart';
import 'package:adb_dart/src/models/android_device.dart';
import 'package:adb_dart/src/models/battery_info.dart';
import 'package:adb_dart/src/models/display_info.dart';
import 'package:adb_dart/src/models/file_entry.dart';
import 'package:adb_dart/src/models/logcat_level.dart';
import 'package:adb_dart/src/models/network_info.dart';
import 'package:adb_dart/src/models/storage_info.dart';
import 'package:adb_dart/src/services/adb_device_service.dart';
import 'package:adb_dart/src/services/adb_file_system_service.dart';
import 'package:adb_dart/src/services/adb_logcat_service.dart';
import 'package:adb_dart/src/services/adb_package_service.dart';
import 'package:adb_dart/src/services/adb_property_service.dart';
import 'package:adb_dart/src/services/adb_system_service.dart';

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

  /// Service for system information operations.
  late final AdbSystemService _systemService;

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
    _systemService = AdbSystemService(
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

  // ==================
  // System Information
  // ==================

  /// Retrieves battery information from the device.
  ///
  /// Returns a [BatteryInfo] object containing level, status, health,
  /// temperature, voltage, and more.
  Future<BatteryInfo> getBatteryInfo(DeviceId deviceId) =>
      _systemService.getBatteryInfo(deviceId);

  /// Retrieves storage information for all mounted filesystems.
  ///
  /// Returns a list of [StorageInfo] objects for each relevant mount point.
  Future<List<StorageInfo>> getStorageInfo(DeviceId deviceId) =>
      _systemService.getStorageInfo(deviceId);

  /// Retrieves display information from the device.
  ///
  /// Returns a [DisplayInfo] object containing resolution and density.
  Future<DisplayInfo> getDisplayInfo(DeviceId deviceId) =>
      _systemService.getDisplayInfo(deviceId);

  /// Retrieves network information from the device.
  ///
  /// Returns a [NetworkInfo] object containing WiFi and interface information.
  Future<NetworkInfo> getNetworkInfo(DeviceId deviceId) =>
      _systemService.getNetworkInfo(deviceId);

  // ==================
  // App Management
  // ==================

  /// Uninstalls an application from the device.
  ///
  /// Set [keepData] to true to preserve the app's data and cache.
  ///
  /// Throws [AdbPackageException] if the uninstallation fails.
  Future<void> uninstallApplication(
    String packageName,
    DeviceId deviceId, {
    bool keepData = false,
  }) =>
      _packageService.uninstallApplication(packageName, deviceId,
          keepData: keepData);

  /// Clears all data for an application on the device.
  ///
  /// This removes all app data including cache, databases, and shared preferences.
  ///
  /// Throws [AdbPackageException] if the operation fails.
  Future<void> clearAppData(String packageName, DeviceId deviceId) =>
      _packageService.clearAppData(packageName, deviceId);

  /// Force stops an application on the device.
  ///
  /// This terminates all processes associated with the package.
  ///
  /// Throws [AdbPackageException] if the operation fails.
  Future<void> forceStopApp(String packageName, DeviceId deviceId) =>
      _packageService.forceStopApp(packageName, deviceId);

  /// Starts a specific activity on the device.
  ///
  /// [packageName] is the package name (e.g., 'com.example.app').
  /// [activityName] is the activity class name (e.g., '.MainActivity').
  ///
  /// Throws [AdbPackageException] if the activity cannot be started.
  Future<void> startActivity(
    String packageName,
    String activityName,
    DeviceId deviceId, {
    Map<String, String>? extras,
    String? action,
    String? data,
  }) =>
      _packageService.startActivity(
        packageName,
        activityName,
        deviceId,
        extras: extras,
        action: action,
        data: data,
      );

  /// Launches an application using its main/launcher activity.
  ///
  /// This is equivalent to tapping the app icon on the home screen.
  ///
  /// Throws [AdbPackageException] if the app cannot be launched.
  Future<void> launchApp(String packageName, DeviceId deviceId) =>
      _packageService.launchApp(packageName, deviceId);
}
