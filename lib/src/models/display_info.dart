/// Represents display information for an Android device.
class DisplayInfo {
  /// Physical screen width in pixels.
  final int widthPixels;

  /// Physical screen height in pixels.
  final int heightPixels;

  /// Screen density in DPI.
  final int densityDpi;

  const DisplayInfo({
    required this.widthPixels,
    required this.heightPixels,
    required this.densityDpi,
  });

  /// Returns the screen resolution as a string (e.g., '1080x1920').
  String get resolution => '${widthPixels}x$heightPixels';

  @override
  String toString() {
    return 'DisplayInfo(resolution: $resolution, density: ${densityDpi}dpi)';
  }
}
