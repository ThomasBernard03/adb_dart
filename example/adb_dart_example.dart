import 'dart:developer';
import 'dart:io';

import 'package:adb_dart/adb_dart.dart';

Future<void> main() async {
  var adbClient = AdbClient(adbExecutablePath: "./platform-tools/adb");
  final devices = await adbClient.listConnectedDevices();

  final firstDevice = devices.firstOrNull;
  if (firstDevice == null) {
    return;
  }

  // 1) Listen logcat
  adbClient.listenLogcat(firstDevice.deviceId).listen((lines) {
    log("Lines received !:\n${lines.join("\n")}");
  });

  // Clear all logcat
  adbClient.clearLogcat(firstDevice.deviceId);

  // Install application
  final apkFile = File("my_awesome_application.apk");
  adbClient.installApplication(apkFile, firstDevice.deviceId);
}
