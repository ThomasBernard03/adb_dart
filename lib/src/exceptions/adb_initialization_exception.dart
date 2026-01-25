import 'package:adb_dart/src/exceptions/adb_exception.dart';

/// Thrown when the ADB executable cannot be found at the specified path.
class AdbInitializationException extends AdbException {
  /// The path where the ADB executable was expected.
  final String path;

  /// Creates a new [AdbInitializationException].
  AdbInitializationException({required this.path})
      : super("Can't find file at $path");
}
