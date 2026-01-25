import 'package:adb_dart/src/logging/adb_logger.dart';

/// Default logger implementation that logs to the console.
///
/// This is the default logger used by [AdbClient] when no custom
/// logger is provided. It outputs log messages to the console using
/// Dart's built-in print function.
class DefaultLogger implements AdbLogger {
  /// Creates a constant default logger.
  const DefaultLogger();

  @override
  void debug(String message) {
    print('[DEBUG] $message');
  }

  @override
  void info(String message) {
    print('[INFO] $message');
  }

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    print('[ERROR] $message');
    if (error != null) {
      print('[ERROR] Error: $error');
    }
    if (stackTrace != null) {
      print('[ERROR] Stack trace:\n$stackTrace');
    }
  }
}
