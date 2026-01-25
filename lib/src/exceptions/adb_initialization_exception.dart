import 'package:adb_dart/src/exceptions/adb_exception.dart';

class AdbInitializationException implements AdbException {
  final String path;

  AdbInitializationException({required this.path});

  @override
  String get message => "Can't find file at $path";
}
