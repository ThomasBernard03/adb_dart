/// Abstract logger interface for ADB operations.
///
/// Implement this interface to provide custom logging behavior
/// for the ADB client operations.
///
/// Example:
/// ```dart
/// class ConsoleLogger implements AdbLogger {
///   @override
///   void debug(String message) => print('[DEBUG] $message');
///
///   @override
///   void info(String message) => print('[INFO] $message');
///
///   @override
///   void error(String message, {Object? error, StackTrace? stackTrace}) {
///     print('[ERROR] $message');
///     if (error != null) print('Error: $error');
///     if (stackTrace != null) print('Stack: $stackTrace');
///   }
/// }
/// ```
abstract class AdbLogger {
  /// Logs a debug message.
  ///
  /// Use for detailed information useful during development and troubleshooting.
  void debug(String message);

  /// Logs an informational message.
  ///
  /// Use for general information about normal operations.
  void info(String message);

  /// Logs an error message with optional error and stack trace.
  ///
  /// Use when an error occurs during ADB operations.
  void error(String message, {Object? error, StackTrace? stackTrace});
}
