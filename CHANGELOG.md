## 1.1.0

### New Features
- **File System Management**: Complete file system operations support
  - List files and directories with detailed information (`listFiles`)
  - Upload files from local filesystem to device (`uploadFile`)
  - Download files from device to local filesystem (`downloadFile`)
  - Create directories on device (`createDirectory`)
  - Delete files and directories (`deleteFile`)
  - Support for app-specific private directories using `run-as`
- **Logging System**: Customizable logging with `AdbLogger` interface
  - `DefaultLogger` implementation for console output
  - Custom logger support via constructor parameter
- **Architecture Refactoring**: Service-based architecture for better maintainability
  - `AdbDeviceService` for device management
  - `AdbPackageService` for package operations
  - `AdbPropertyService` for system properties
  - `AdbLogcatService` for logcat operations
  - `AdbFileSystemService` for file system operations

### New Models
- `FileEntry`: Represents files and directories with metadata (name, type, size, permissions, date, etc.)
- `FileType`: Enumeration for file types (file, directory, symlink, unknown)

### New Exceptions
- `AdbDeviceException`: For device-related errors
- `AdbPackageException`: For package management errors
- `AdbPropertyException`: For property retrieval errors
- `AdbLogcatException`: For logcat operation errors
- `AdbInstallationException`: For APK installation failures

### Breaking Changes
- None - All existing APIs remain backward compatible

## 1.0.0

- Initial release of adb_dart
- List connected Android devices with detailed information
- Install APK files on devices
- Retrieve all installed third-party packages
- Access device system properties
- Stream logcat output with filtering options (by level and process ID)
- Clear logcat buffer
- Comprehensive error handling with custom exceptions
