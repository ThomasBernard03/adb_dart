/// Represents the type of a file system entry.
enum FileType {
  /// A regular file.
  file,

  /// A directory.
  directory,

  /// A symbolic link.
  symlink,

  /// Unknown or unrecognized file type.
  unknown,
}
