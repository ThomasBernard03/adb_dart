import 'package:adb_dart/src/models/file_type.dart';

/// Represents a file or directory entry from an Android device.
class FileEntry {
  /// The type of this file entry (file, directory, symlink, or unknown).
  final FileType type;

  /// Unix-style permissions string (e.g., 'drwxr-xr-x').
  final String permissions;

  /// The name of the file or directory.
  final String name;

  /// Number of hard links (optional).
  final int? links;

  /// Owner of the file (optional).
  final String? owner;

  /// Group of the file (optional).
  final String? group;

  /// Size in bytes (optional).
  final int? size;

  /// Last modification date (optional).
  final DateTime? date;

  /// If this is a symlink, the target path (optional).
  final String? symlinkTarget;

  const FileEntry({
    required this.type,
    required this.permissions,
    required this.name,
    this.links,
    this.owner,
    this.group,
    this.size,
    this.date,
    this.symlinkTarget,
  });

  @override
  String toString() {
    return 'FileEntry(name: $name, type: $type, permissions: $permissions)';
  }
}
