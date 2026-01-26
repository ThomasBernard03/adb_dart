/// Represents storage information for a filesystem on an Android device.
class StorageInfo {
  /// Mount point path (e.g., '/data', '/sdcard').
  final String mountPoint;

  /// Total size in bytes.
  final int totalBytes;

  /// Used space in bytes.
  final int usedBytes;

  /// Available space in bytes.
  final int availableBytes;

  /// Usage percentage (0-100).
  final int usagePercent;

  /// Filesystem type (e.g., 'ext4', 'fuse').
  final String? filesystem;

  const StorageInfo({
    required this.mountPoint,
    required this.totalBytes,
    required this.usedBytes,
    required this.availableBytes,
    required this.usagePercent,
    this.filesystem,
  });

  @override
  String toString() {
    return 'StorageInfo(mountPoint: $mountPoint, used: $usagePercent%, available: ${_formatBytes(availableBytes)})';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
