# adb_dart

A lightweight Dart client for interacting with Android devices through ADB (Android Debug Bridge).

This package provides a simple and intuitive API to manage Android devices, install applications, read logs, and more, directly from your Dart applications.

## Features

- List connected Android devices
- Install APK files on devices
- Retrieve installed packages
- Access device system properties
- Stream logcat output with filtering options
- Clear logcat buffer

## Prerequisites

You need to have ADB installed on your system. You can get it from:
- [Android SDK Platform Tools](https://developer.android.com/studio/releases/platform-tools)
- Or install Android Studio which includes ADB

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  adb_dart: ^1.0.0
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
- `AdbClient({required String adbExecutablePath})` - Creates a new ADB client instance

#### Methods
- `Future<Iterable<AndroidDevice>> listConnectedDevices()` - Lists all connected devices
- `Future<void> installApplication(File apkFile, DeviceId deviceId)` - Installs an APK on a device
- `Future<Iterable<String>> getAllPackages(DeviceId deviceId)` - Gets all third-party packages installed
- `Future<Map<String, String>> getProperties(DeviceId deviceId)` - Retrieves device system properties
- `Stream<Iterable<String>> listenLogcat(DeviceId deviceId, {LogcatLevel? level, int? processId})` - Streams logcat output
- `Future<void> clearLogcat(DeviceId deviceId)` - Clears the logcat buffer

### LogcatLevel

Available log levels for filtering:
- `LogcatLevel.verbose`
- `LogcatLevel.debug`
- `LogcatLevel.info`
- `LogcatLevel.warning`
- `LogcatLevel.error`
- `LogcatLevel.fatal`

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Issues

If you encounter any issues or have suggestions, please file them in the [issue tracker](https://github.com/ThomasBernard03/adb_dart/issues).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
