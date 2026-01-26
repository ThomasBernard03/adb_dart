import 'dart:io';

import 'package:adb_dart/adb_dart.dart';

/// Custom logger implementation that prints to console.
class ConsoleLogger implements AdbLogger {
  @override
  void debug(String message) => print('[DEBUG] $message');

  @override
  void info(String message) => print('[INFO] $message');

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    print('[ERROR] $message');
    if (error != null) print('  Cause: $error');
    if (stackTrace != null) print('  Stack: $stackTrace');
  }
}

Future<void> main() async {
  // Create ADB client with custom logger
  final adbFile = File("/Users/thomasbernard/Development/adb_dart/example/adb");
  final adbClient = AdbClient(
    adbExecutablePath: adbFile.path,
    logger: ConsoleLogger(),
  );

  try {
    // List connected devices
    print('Searching for devices...');
    final devices = await adbClient.listConnectedDevices();

    if (devices.isEmpty) {
      print('No devices connected');
      return;
    }

    print('Found ${devices.length} device(s)');
    final firstDevice = devices.first;
    print('Using device: ${firstDevice.name} (${firstDevice.deviceId})');

    // Get device properties
    try {
      final properties = await adbClient.getProperties(firstDevice.deviceId);
      print(
          'Device Android version: ${properties['ro.build.version.release']}');
    } on AdbPropertyException catch (e) {
      print('Could not retrieve properties: $e');
    }

    // Clear logcat
    try {
      await adbClient.clearLogcat(firstDevice.deviceId);
      print('Logcat cleared');
    } on AdbLogcatException catch (e) {
      print('Failed to clear logcat: $e');
    }

    // Listen to logcat
    print('Starting logcat listener...');
    adbClient.listenLogcat(firstDevice.deviceId).listen(
      (lines) {
        print('Logcat lines received: ${lines.length}');
        for (final line in lines) {
          print('  $line');
        }
      },
      onError: (error) {
        print('Logcat error: $error');
      },
    );

    // Install application (example - will fail if file doesn't exist)
    final apkFile = File('my_awesome_application.apk');
    if (apkFile.existsSync()) {
      try {
        await adbClient.installApplication(apkFile, firstDevice.deviceId);
        print('APK installed successfully');
      } on AdbInstallationException catch (e) {
        print('Installation failed: $e');
      }
    } else {
      print('APK file not found: ${apkFile.path}');
    }

    // List installed packages
    try {
      final packages = await adbClient.getAllPackages(firstDevice.deviceId);
      print('Found ${packages.length} third-party packages');
    } on AdbPackageException catch (e) {
      print('Failed to list packages: $e');
    }

    // ==================
    // File Management
    // ==================

    print('\n--- File System Operations ---');

    // List files in a directory
    try {
      final files = await adbClient.listFiles('/sdcard/', firstDevice.deviceId);
      print('Files in /sdcard/:');
      for (final file in files) {
        print('  ${file.name} (${file.type.name}) - ${file.size} bytes');
      }
    } catch (e) {
      print('Failed to list files: $e');
    }

    // Create a test directory
    try {
      await adbClient.createDirectory(
        '/sdcard/',
        'AdbDartTest',
        firstDevice.deviceId,
      );
      print('Created directory: /sdcard/AdbDartTest');
    } catch (e) {
      print('Failed to create directory: $e');
    }

    // Upload a file to the device
    final testFile = File('test.txt');
    if (!testFile.existsSync()) {
      await testFile.writeAsString('Hello from adb_dart!');
    }

    try {
      await adbClient.uploadFile(
        testFile.path,
        '/sdcard/AdbDartTest/test.txt',
        firstDevice.deviceId,
      );
      print('Uploaded file to: /sdcard/AdbDartTest/test.txt');
    } catch (e) {
      print('Failed to upload file: $e');
    }

    // Download a file from the device
    try {
      await adbClient.downloadFile(
        '/sdcard/AdbDartTest/test.txt',
        'downloaded_test.txt',
        firstDevice.deviceId,
      );
      print('Downloaded file to: downloaded_test.txt');
    } catch (e) {
      print('Failed to download file: $e');
    }

    // Working with app-specific private directories
    const String packageName = 'com.example.myapp';

    try {
      // List files in app's private directory
      final appFiles = await adbClient.listFiles(
        '/data/data/$packageName/files',
        firstDevice.deviceId,
        packageName: packageName,
      );
      print('\nFiles in app directory:');
      for (final file in appFiles) {
        print('  ${file.name}');
      }
    } catch (e) {
      print('Could not access app directory (app may not be installed): $e');
    }

    // Delete test files (cleanup)
    try {
      await adbClient.deleteFile(
        '/sdcard/AdbDartTest',
        firstDevice.deviceId,
      );
      print('\nCleaned up test directory');
    } catch (e) {
      print('Failed to delete test directory: $e');
    }

    // ==================
    // System Information
    // ==================

    print('\n--- System Information ---');

    // Get battery info
    try {
      final battery = await adbClient.getBatteryInfo(firstDevice.deviceId);
      print('Battery:');
      print('  Level: ${battery.level}%');
      print('  Status: ${battery.status.name}');
      print('  Health: ${battery.health.name}');
      print('  Temperature: ${battery.temperature}°C');
      print('  Plugged: ${battery.isPlugged ? battery.plugType?.name ?? "yes" : "no"}');
    } catch (e) {
      print('Failed to get battery info: $e');
    }

    // Get storage info
    try {
      final storage = await adbClient.getStorageInfo(firstDevice.deviceId);
      print('\nStorage:');
      for (final mount in storage) {
        print('  ${mount.mountPoint}: ${mount.usagePercent}% used');
      }
    } catch (e) {
      print('Failed to get storage info: $e');
    }

    // Get display info
    try {
      final display = await adbClient.getDisplayInfo(firstDevice.deviceId);
      print('\nDisplay:');
      print('  Resolution: ${display.resolution}');
      print('  Density: ${display.densityDpi} dpi');
    } catch (e) {
      print('Failed to get display info: $e');
    }

    // Get network info
    try {
      final network = await adbClient.getNetworkInfo(firstDevice.deviceId);
      print('\nNetwork:');
      if (network.wifi != null) {
        print('  WiFi: ${network.wifi!.ssid}');
        print('  IP: ${network.wifi!.ipAddress}');
      }
      print('  Interfaces: ${network.interfaces.length}');
      for (final iface in network.interfaces) {
        print('    ${iface.name}: ${iface.ipv4Address ?? "no IPv4"}');
      }
    } catch (e) {
      print('Failed to get network info: $e');
    }

    // ==================
    // App Management
    // ==================

    print('\n--- App Management ---');

    const String testPackage = 'com.example.testapp';

    // Launch an app
    try {
      await adbClient.launchApp(testPackage, firstDevice.deviceId);
      print('Launched $testPackage');
    } catch (e) {
      print('Failed to launch app (may not be installed): $e');
    }

    // Force stop an app
    try {
      await adbClient.forceStopApp(testPackage, firstDevice.deviceId);
      print('Force stopped $testPackage');
    } catch (e) {
      print('Failed to force stop app: $e');
    }

    // Clear app data
    try {
      await adbClient.clearAppData(testPackage, firstDevice.deviceId);
      print('Cleared data for $testPackage');
    } catch (e) {
      print('Failed to clear app data: $e');
    }

    // Start a specific activity
    try {
      await adbClient.startActivity(
        'com.android.settings',
        '.Settings',
        firstDevice.deviceId,
      );
      print('Opened Settings app');
    } catch (e) {
      print('Failed to start activity: $e');
    }

    // Uninstall an app (with keepData option)
    // try {
    //   await adbClient.uninstallApplication(
    //     testPackage,
    //     firstDevice.deviceId,
    //     keepData: true, // Keep app data for potential reinstall
    //   );
    //   print('Uninstalled $testPackage (data preserved)');
    // } catch (e) {
    //   print('Failed to uninstall app: $e');
    // }

  } on AdbDeviceException catch (e) {
    print('Device error: $e');
  } on AdbException catch (e) {
    print('ADB error: $e');
  }
}
