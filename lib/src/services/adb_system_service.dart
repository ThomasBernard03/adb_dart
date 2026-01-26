import 'dart:io';

import 'package:adb_dart/src/device_id.dart';
import 'package:adb_dart/src/logging/adb_logger.dart';
import 'package:adb_dart/src/logging/default_logger.dart';
import 'package:adb_dart/src/models/battery_info.dart';
import 'package:adb_dart/src/models/display_info.dart';
import 'package:adb_dart/src/models/network_info.dart';
import 'package:adb_dart/src/models/storage_info.dart';

/// Service for retrieving system information from Android devices.
class AdbSystemService {
  /// Absolute path to the adb executable.
  final String adbExecutablePath;

  /// Logger instance for ADB operations.
  final AdbLogger _logger;

  /// Creates a new [AdbSystemService].
  AdbSystemService({
    required this.adbExecutablePath,
    AdbLogger? logger,
  }) : _logger = logger ?? const DefaultLogger();

  /// Retrieves battery information from the device.
  ///
  /// Returns a [BatteryInfo] object containing level, status, health,
  /// temperature, voltage, and more.
  Future<BatteryInfo> getBatteryInfo(DeviceId deviceId) async {
    _logger.debug('Getting battery info for device $deviceId');

    final result = await Process.run(
      adbExecutablePath,
      ['-s', deviceId, 'shell', 'dumpsys', 'battery'],
    );

    if (result.exitCode != 0) {
      _logger.error('Failed to get battery info: ${result.stderr}');
      throw Exception('Failed to get battery info: ${result.stderr}');
    }

    final output = result.stdout as String;
    final lines = output.split('\n');

    int level = 0;
    BatteryStatus status = BatteryStatus.unknown;
    BatteryHealth health = BatteryHealth.unknown;
    bool isPlugged = false;
    PlugType? plugType;
    double temperature = 0;
    int voltage = 0;
    String? technology;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('level:')) {
        level = int.tryParse(trimmed.split(':').last.trim()) ?? 0;
      } else if (trimmed.startsWith('status:')) {
        final statusCode = int.tryParse(trimmed.split(':').last.trim()) ?? 1;
        status = _parseStatus(statusCode);
      } else if (trimmed.startsWith('health:')) {
        final healthCode = int.tryParse(trimmed.split(':').last.trim()) ?? 1;
        health = _parseHealth(healthCode);
      } else if (trimmed.startsWith('AC powered:')) {
        if (trimmed.contains('true')) {
          isPlugged = true;
          plugType = PlugType.ac;
        }
      } else if (trimmed.startsWith('USB powered:')) {
        if (trimmed.contains('true')) {
          isPlugged = true;
          plugType = PlugType.usb;
        }
      } else if (trimmed.startsWith('Wireless powered:')) {
        if (trimmed.contains('true')) {
          isPlugged = true;
          plugType = PlugType.wireless;
        }
      } else if (trimmed.startsWith('temperature:')) {
        final temp = int.tryParse(trimmed.split(':').last.trim()) ?? 0;
        temperature = temp / 10.0; // Convert from tenths of degree
      } else if (trimmed.startsWith('voltage:')) {
        voltage = int.tryParse(trimmed.split(':').last.trim()) ?? 0;
      } else if (trimmed.startsWith('technology:')) {
        technology = trimmed.split(':').last.trim();
      }
    }

    _logger.info('Battery level: $level%');

    return BatteryInfo(
      level: level,
      status: status,
      health: health,
      isPlugged: isPlugged,
      plugType: plugType,
      temperature: temperature,
      voltage: voltage,
      technology: technology,
    );
  }

  /// Retrieves storage information for all mounted filesystems.
  ///
  /// Returns a list of [StorageInfo] objects for each mount point.
  Future<List<StorageInfo>> getStorageInfo(DeviceId deviceId) async {
    _logger.debug('Getting storage info for device $deviceId');

    final result = await Process.run(
      adbExecutablePath,
      ['-s', deviceId, 'shell', 'df', '-h'],
    );

    if (result.exitCode != 0) {
      _logger.error('Failed to get storage info: ${result.stderr}');
      throw Exception('Failed to get storage info: ${result.stderr}');
    }

    final output = result.stdout as String;
    final lines = output.split('\n').skip(1); // Skip header
    final storageList = <StorageInfo>[];

    for (final line in lines) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 6) continue;

      // Filter for relevant mount points
      final mountPoint = parts.last;
      if (!_isRelevantMountPoint(mountPoint)) continue;

      final totalBytes = _parseSize(parts[1]);
      final usedBytes = _parseSize(parts[2]);
      final availableBytes = _parseSize(parts[3]);
      final usagePercent =
          int.tryParse(parts[4].replaceAll('%', '').trim()) ?? 0;

      storageList.add(StorageInfo(
        mountPoint: mountPoint,
        totalBytes: totalBytes,
        usedBytes: usedBytes,
        availableBytes: availableBytes,
        usagePercent: usagePercent,
        filesystem: parts[0],
      ));
    }

    _logger.info('Found ${storageList.length} storage mount points');
    return storageList;
  }

  /// Retrieves display information from the device.
  ///
  /// Returns a [DisplayInfo] object containing resolution and density.
  Future<DisplayInfo> getDisplayInfo(DeviceId deviceId) async {
    _logger.debug('Getting display info for device $deviceId');

    // Get screen size
    final sizeResult = await Process.run(
      adbExecutablePath,
      ['-s', deviceId, 'shell', 'wm', 'size'],
    );

    // Get screen density
    final densityResult = await Process.run(
      adbExecutablePath,
      ['-s', deviceId, 'shell', 'wm', 'density'],
    );

    int width = 0;
    int height = 0;
    int density = 0;

    // Parse size (e.g., "Physical size: 1080x1920")
    final sizeOutput = sizeResult.stdout as String;
    final sizeMatch = RegExp(r'(\d+)x(\d+)').firstMatch(sizeOutput);
    if (sizeMatch != null) {
      width = int.tryParse(sizeMatch.group(1) ?? '0') ?? 0;
      height = int.tryParse(sizeMatch.group(2) ?? '0') ?? 0;
    }

    // Parse density (e.g., "Physical density: 420")
    final densityOutput = densityResult.stdout as String;
    final densityMatch = RegExp(r'(\d+)').firstMatch(densityOutput);
    if (densityMatch != null) {
      density = int.tryParse(densityMatch.group(1) ?? '0') ?? 0;
    }

    _logger.info('Display: ${width}x$height @ ${density}dpi');

    return DisplayInfo(
      widthPixels: width,
      heightPixels: height,
      densityDpi: density,
    );
  }

  /// Retrieves network information from the device.
  ///
  /// Returns a [NetworkInfo] object containing WiFi and interface information.
  Future<NetworkInfo> getNetworkInfo(DeviceId deviceId) async {
    _logger.debug('Getting network info for device $deviceId');

    // Get IP addresses
    final ipResult = await Process.run(
      adbExecutablePath,
      ['-s', deviceId, 'shell', 'ip', 'addr'],
    );

    // Get WiFi info
    final wifiResult = await Process.run(
      adbExecutablePath,
      ['-s', deviceId, 'shell', 'dumpsys', 'wifi'],
    );

    final interfaces = _parseNetworkInterfaces(ipResult.stdout as String);
    final wifi = _parseWifiInfo(wifiResult.stdout as String);

    _logger.info('Found ${interfaces.length} network interfaces');

    return NetworkInfo(
      wifi: wifi,
      interfaces: interfaces,
    );
  }

  // Helper methods

  BatteryStatus _parseStatus(int code) {
    switch (code) {
      case 2:
        return BatteryStatus.charging;
      case 3:
        return BatteryStatus.discharging;
      case 4:
        return BatteryStatus.notCharging;
      case 5:
        return BatteryStatus.full;
      default:
        return BatteryStatus.unknown;
    }
  }

  BatteryHealth _parseHealth(int code) {
    switch (code) {
      case 2:
        return BatteryHealth.good;
      case 3:
        return BatteryHealth.overheat;
      case 4:
        return BatteryHealth.dead;
      case 5:
        return BatteryHealth.overVoltage;
      case 6:
        return BatteryHealth.unspecifiedFailure;
      case 7:
        return BatteryHealth.cold;
      default:
        return BatteryHealth.unknown;
    }
  }

  bool _isRelevantMountPoint(String mountPoint) {
    return mountPoint == '/data' ||
        mountPoint == '/sdcard' ||
        mountPoint == '/storage/emulated' ||
        mountPoint.startsWith('/storage/') ||
        mountPoint == '/' ||
        mountPoint == '/system';
  }

  int _parseSize(String size) {
    size = size.trim().toUpperCase();
    final numericPart =
        double.tryParse(size.replaceAll(RegExp(r'[A-Z]'), '')) ?? 0;

    if (size.endsWith('K')) {
      return (numericPart * 1024).round();
    } else if (size.endsWith('M')) {
      return (numericPart * 1024 * 1024).round();
    } else if (size.endsWith('G')) {
      return (numericPart * 1024 * 1024 * 1024).round();
    } else if (size.endsWith('T')) {
      return (numericPart * 1024 * 1024 * 1024 * 1024).round();
    }
    return numericPart.round();
  }

  List<NetworkInterface> _parseNetworkInterfaces(String output) {
    final interfaces = <NetworkInterface>[];
    final lines = output.split('\n');

    String? currentInterface;
    String? ipv4;
    String? ipv6;
    String? mac;

    for (final line in lines) {
      // New interface (e.g., "2: wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP>")
      final interfaceMatch = RegExp(r'^\d+:\s+(\w+):').firstMatch(line);
      if (interfaceMatch != null) {
        // Save previous interface
        if (currentInterface != null && currentInterface != 'lo') {
          interfaces.add(NetworkInterface(
            name: currentInterface,
            ipv4Address: ipv4,
            ipv6Address: ipv6,
            macAddress: mac,
          ));
        }
        currentInterface = interfaceMatch.group(1);
        ipv4 = null;
        ipv6 = null;
        mac = null;
      }

      // IPv4 address (e.g., "inet 192.168.1.100/24")
      final ipv4Match = RegExp(r'inet\s+([\d.]+)').firstMatch(line);
      if (ipv4Match != null) {
        ipv4 = ipv4Match.group(1);
      }

      // IPv6 address (e.g., "inet6 fe80::1/64")
      final ipv6Match = RegExp(r'inet6\s+([a-f0-9:]+)').firstMatch(line);
      if (ipv6Match != null) {
        ipv6 = ipv6Match.group(1);
      }

      // MAC address (e.g., "link/ether aa:bb:cc:dd:ee:ff")
      final macMatch =
          RegExp(r'link/ether\s+([a-f0-9:]+)', caseSensitive: false)
              .firstMatch(line);
      if (macMatch != null) {
        mac = macMatch.group(1);
      }
    }

    // Don't forget the last interface
    if (currentInterface != null && currentInterface != 'lo') {
      interfaces.add(NetworkInterface(
        name: currentInterface,
        ipv4Address: ipv4,
        ipv6Address: ipv6,
        macAddress: mac,
      ));
    }

    return interfaces;
  }

  WifiInfo? _parseWifiInfo(String output) {
    String? ssid;
    int? rssi;
    int? linkSpeed;
    String? ipAddress;
    String? macAddress;

    // Parse SSID
    final ssidMatch = RegExp(r'SSID:\s*"?([^"\n]+)"?').firstMatch(output);
    if (ssidMatch != null) {
      ssid = ssidMatch.group(1)?.trim();
    }

    // Parse RSSI
    final rssiMatch = RegExp(r'RSSI:\s*(-?\d+)').firstMatch(output);
    if (rssiMatch != null) {
      rssi = int.tryParse(rssiMatch.group(1) ?? '');
    }

    // Parse link speed
    final speedMatch = RegExp(r'Link speed:\s*(\d+)').firstMatch(output);
    if (speedMatch != null) {
      linkSpeed = int.tryParse(speedMatch.group(1) ?? '');
    }

    // Parse IP address
    final ipMatch = RegExp(r'IP address:\s*([\d.]+)').firstMatch(output);
    if (ipMatch != null) {
      ipAddress = ipMatch.group(1);
    }

    // Parse MAC address
    final macMatch = RegExp(r'MAC:\s*([a-f0-9:]+)', caseSensitive: false)
        .firstMatch(output);
    if (macMatch != null) {
      macAddress = macMatch.group(1);
    }

    // Only return WifiInfo if we have at least an SSID
    if (ssid == null || ssid.isEmpty || ssid == '<unknown ssid>') {
      return null;
    }

    return WifiInfo(
      ssid: ssid,
      rssi: rssi,
      linkSpeed: linkSpeed,
      ipAddress: ipAddress,
      macAddress: macAddress,
    );
  }
}
