class AdbException implements Exception {
  final String message;

  AdbException(this.message);

  @override
  String toString() => 'AdbException: $message';
}
