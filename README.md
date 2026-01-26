# adb_dart

A lightweight Dart client for interacting with Android devices through ADB (Android Debug Bridge).

This package provides a simple and intuitive API to manage Android devices, install applications, read logs, and more, directly from your Dart applications.

## Features

- **Device Management**
  - List connected Android devices with detailed information
  - Access device system properties
- **Package Management**
  - Install APK files on devices
  - Uninstall applications
  - Retrieve installed third-party packages
- **App Control**
  - Launch applications
  - Force stop applications
  - Clear app data
  - Start specific activities with extras
- **System Information**
  - Battery status (level, health, temperature, charging state)
  - Storage information (available space per mount point)
  - Display information (resolution, density)
  - Network information (WiFi status, IP addresses, interfaces)
- **Logcat**
  - Stream logcat output with filtering options (by level and process ID)
  - Clear logcat buffer
- **File System Operations**
  - List files and directories on the device
  - Upload and download files between device and local filesystem
  - Create directories on the device
  - Delete files and directories
  - Support for app-specific private directories using `run-as`
- **Logging**
  - Customizable logging with the `AdbLogger` interface
  - Default console logger included

## Prerequisites

You need to have ADB installed on your system. You can get it from:
- [Android SDK Platform Tools](https://developer.android.com/studio/releases/platform-tools)
- Or install Android Studio which includes ADB

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  adb_dart: ^1.2.0
```

Then run:

```bash
dart pub get
```

## Usage

### Initialize the client

```dart
import 'package:adb_dart/adb_dart.dart';

// Provide the path to your adb executable
final adbClient = AdbClient(adbExecutablePath: '/path/to/adb');

// With custom logger
final adbClient = AdbClient(
  adbExecutablePath: '/path/to/adb',
  logger: ConsoleLogger(), // Your custom AdbLogger implementation
);

// On macOS/Linux with Android Studio:
// final adbClient = AdbClient(adbExecutablePath: '~/Library/Android/sdk/platform-tools/adb');

// On Windows with Android Studio:
// final adbClient = AdbClient(adbExecutablePath: r'C:\Users\YourName\AppData\Local\Android\Sdk\platform-tools\adb.exe');
```

### List connected devices

```dart
final devices = await adbClient.listConnectedDevices();

for (final device in devices) {
  print('Device: ${device.name}');
  print('Manufacturer: ${device.manufacturer}');
  print('ID: ${device.deviceId}');
}
```

### Install an APK

```dart
final apkFile = File('/path/to/your/app.apk');
await adbClient.installApplication(apkFile, deviceId);
```

### List installed packages

```dart
final packages = await adbClient.getAllPackages(deviceId);
print('Installed packages: $packages');
```

### Get device properties

```dart
final properties = await adbClient.getProperties(deviceId);
print('Android version: ${properties['ro.build.version.release']}');
print('Device model: ${properties['ro.product.model']}');
```

### Listen to logcat

```dart
// Clear previous logs
await adbClient.clearLogcat(deviceId);

// Listen to all logs
adbClient.listenLogcat(deviceId).listen((lines) {
  for (final line in lines) {
    print(line);
  }
});

// Listen to specific log level
adbClient.listenLogcat(
  deviceId,
  level: LogcatLevel.error,
).listen((lines) {
  for (final line in lines) {
    print('Error: $line');
  }
});

// Listen to specific process
adbClient.listenLogcat(
  deviceId,
  processId: 12345,
).listen((lines) {
  for (final line in lines) {
    print(line);
  }
});
```

### File system operations

```dart
// List files in a directory
final files = await adbClient.listFiles('/sdcard/Download', deviceId);
for (final file in files) {
  print('${file.name} - ${file.type.name} - ${file.size} bytes');
}

// Create a directory
await adbClient.createDirectory('/sdcard/', 'MyFolder', deviceId);

// Upload a file to the device
await adbClient.uploadFile(
  'local/file.txt',
  '/sdcard/MyFolder/file.txt',
  deviceId,
);

// Download a file from the device
await adbClient.downloadFile(
  '/sdcard/MyFolder/file.txt',
  'downloaded_file.txt',
  deviceId,
);

// Delete a file or directory
await adbClient.deleteFile('/sdcard/MyFolder', deviceId);

// Access app-specific private directories
final appFiles = await adbClient.listFiles(
  '/data/data/com.example.app/files',
  deviceId,
  packageName: 'com.example.app', // Required for private directories
);

// Upload to app's private directory
await adbClient.uploadFile(
  'config.json',
  'files/config.json', // Relative path within app's directory
  deviceId,
  packageName: 'com.example.app',
);
```

### System information

```dart
// Get battery info
final battery = await adbClient.getBatteryInfo(deviceId);
print('Battery: ${battery.level}% - ${battery.status.name}');
print('Temperature: ${battery.temperature}°C');
print('Health: ${battery.health.name}');

// Get storage info
final storage = await adbClient.getStorageInfo(deviceId);
for (final mount in storage) {
  print('${mount.mountPoint}: ${mount.usagePercent}% used');
}

// Get display info
final display = await adbClient.getDisplayInfo(deviceId);
print('Resolution: ${display.resolution}');
print('Density: ${display.densityDpi} dpi');

// Get network info
final network = await adbClient.getNetworkInfo(deviceId);
if (network.wifi != null) {
  print('WiFi: ${network.wifi!.ssid} - ${network.wifi!.ipAddress}');
}
```

### App management

```dart
// Launch an app (like tapping its icon)
await adbClient.launchApp('com.example.app', deviceId);

// Start a specific activity
await adbClient.startActivity(
  'com.android.settings',
  '.Settings',
  deviceId,
);

// Start activity with extras
await adbClient.startActivity(
  'com.example.app',
  '.DeepLinkActivity',
  deviceId,
  extras: {'key': 'value'},
  action: 'android.intent.action.VIEW',
  data: 'https://example.com',
);

// Force stop an app
await adbClient.forceStopApp('com.example.app', deviceId);

// Clear app data
await adbClient.clearAppData('com.example.app', deviceId);

// Uninstall an app
await adbClient.uninstallApplication('com.example.app', deviceId);

// Uninstall but keep data (for reinstall)
await adbClient.uninstallApplication(
  'com.example.app',
  deviceId,
  keepData: true,
);
```

## Complete Example

```dart
import 'dart:io';
import 'package:adb_dart/adb_dart.dart';

Future<void> main() async {
  // Initialize ADB client
  final adbClient = AdbClient(adbExecutablePath: './platform-tools/adb');

  // List connected devices
  final devices = await adbClient.listConnectedDevices();

  if (devices.isEmpty) {
    print('No devices connected');
    return;
  }

  final device = devices.first;
  print('Using device: ${device.name} (${device.deviceId})');

  // Clear logcat
  await adbClient.clearLogcat(device.deviceId);

  // Listen to logcat
  adbClient.listenLogcat(device.deviceId).listen((lines) {
    for (final line in lines) {
      print(line);
    }
  });

  // Install an application
  final apkFile = File('my_app.apk');
  if (apkFile.existsSync()) {
    await adbClient.installApplication(apkFile, device.deviceId);
    print('Application installed successfully');
  }
}
```

## API Reference

### AdbClient

#### Constructor
- `AdbClient({required String adbExecutablePath, AdbLogger? logger})` - Creates a new ADB client instance with optional custom logger

#### Device Methods
- `Future<Iterable<AndroidDevice>> listConnectedDevices()` - Lists all connected devices
- `Future<Map<String, String>> getProperties(DeviceId deviceId)` - Retrieves device system properties

#### Package Methods
- `Future<void> installApplication(File apkFile, DeviceId deviceId)` - Installs an APK on a device
- `Future<void> uninstallApplication(String packageName, DeviceId deviceId, {bool keepData})` - Uninstalls an app
- `Future<Iterable<String>> getAllPackages(DeviceId deviceId)` - Gets all third-party packages installed

#### App Control Methods
- `Future<void> launchApp(String packageName, DeviceId deviceId)` - Launches an app
- `Future<void> startActivity(String packageName, String activityName, DeviceId deviceId, {...})` - Starts a specific activity
- `Future<void> forceStopApp(String packageName, DeviceId deviceId)` - Force stops an app
- `Future<void> clearAppData(String packageName, DeviceId deviceId)` - Clears all app data

#### System Information Methods
- `Future<BatteryInfo> getBatteryInfo(DeviceId deviceId)` - Gets battery status
- `Future<List<StorageInfo>> getStorageInfo(DeviceId deviceId)` - Gets storage information
- `Future<DisplayInfo> getDisplayInfo(DeviceId deviceId)` - Gets display information
- `Future<NetworkInfo> getNetworkInfo(DeviceId deviceId)` - Gets network information

#### Logcat Methods
- `Stream<Iterable<String>> listenLogcat(DeviceId deviceId, {LogcatLevel? level, int? processId})` - Streams logcat output
- `Future<void> clearLogcat(DeviceId deviceId)` - Clears the logcat buffer

#### File System Methods
- `Future<Iterable<FileEntry>> listFiles(String path, DeviceId deviceId, {String? packageName})` - Lists files and directories
- `Future<void> createDirectory(String path, String name, DeviceId deviceId, {String? packageName})` - Creates a directory
- `Future<void> uploadFile(String localFilePath, String destinationPath, DeviceId deviceId, {String? packageName})` - Uploads a file to the device
- `Future<void> downloadFile(String filePath, String destinationPath, DeviceId deviceId, {String? packageName})` - Downloads a file from the device
- `Future<void> deleteFile(String filePath, DeviceId deviceId, {String? packageName})` - Deletes a file or directory

### Models

#### FileEntry
Represents a file or directory on the Android device:
- `FileType type` - Type of the entry (file, directory, symlink, or unknown)
- `String name` - Name of the file or directory
- `String permissions` - Unix-style permissions (e.g., "drwxr-xr-x")
- `int? size` - Size in bytes (null for directories)
- `DateTime? date` - Last modification date
- `String? owner` - Owner user
- `String? group` - Owner group
- `int? links` - Number of hard links
- `String? symlinkTarget` - Target path if this is a symlink

#### FileType
Enumeration of file types:
- `FileType.file` - Regular file
- `FileType.directory` - Directory
- `FileType.symlink` - Symbolic link
- `FileType.unknown` - Unknown type

#### LogcatLevel
Available log levels for filtering:
- `LogcatLevel.verbose`
- `LogcatLevel.debug`
- `LogcatLevel.info`
- `LogcatLevel.warning`
- `LogcatLevel.error`
- `LogcatLevel.fatal`

#### BatteryInfo
Battery status information:
- `int level` - Battery percentage (0-100)
- `BatteryStatus status` - Charging status (charging, discharging, full, etc.)
- `BatteryHealth health` - Battery health (good, overheat, dead, etc.)
- `bool isPlugged` - Whether device is plugged in
- `PlugType? plugType` - Power source type (ac, usb, wireless)
- `double temperature` - Temperature in Celsius
- `int voltage` - Voltage in millivolts
- `String? technology` - Battery technology (e.g., "Li-ion")

#### StorageInfo
Storage mount point information:
- `String mountPoint` - Mount path (e.g., "/sdcard")
- `int totalBytes` - Total size in bytes
- `int usedBytes` - Used space in bytes
- `int availableBytes` - Available space in bytes
- `int usagePercent` - Usage percentage (0-100)
- `String? filesystem` - Filesystem type

#### DisplayInfo
Display information:
- `int widthPixels` - Screen width in pixels
- `int heightPixels` - Screen height in pixels
- `int densityDpi` - Screen density in DPI
- `String resolution` - Resolution as string (e.g., "1080x1920")

#### NetworkInfo
Network information:
- `WifiInfo? wifi` - WiFi connection info (ssid, rssi, ipAddress, etc.)
- `List<NetworkInterface> interfaces` - Network interfaces with IP addresses

### Logging

#### AdbLogger Interface
Implement this interface to create custom loggers:
```dart
abstract class AdbLogger {
  void debug(String message);
  void info(String message);
  void error(String message, {Object? error, StackTrace? stackTrace});
}
```

#### DefaultLogger
A built-in logger that outputs to the console. Used by default if no logger is provided.

### Exceptions

All exceptions extend `AdbException`:
- `AdbInitializationException` - Thrown when ADB executable is not found
- `AdbDeviceException` - Thrown when device operations fail
- `AdbPackageException` - Thrown when package operations fail
- `AdbPropertyException` - Thrown when property retrieval fails
- `AdbLogcatException` - Thrown when logcat operations fail
- `AdbInstallationException` - Thrown when APK installation fails

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Issues

If you encounter any issues or have suggestions, please file them in the [issue tracker](https://github.com/ThomasBernard03/adb_dart/issues).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
