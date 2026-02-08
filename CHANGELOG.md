## 1.2.3

### Bug Fixes
- **File System Service**: Fixed directory creation and file upload issues with private app directories
  - Fixed `createDirectory()` to allow creating directories at the root (empty path) when using `packageName`
  - Fixed `uploadFile()` to properly handle filenames containing spaces when using `packageName`
  - Added proper shell escaping for file paths in `run-as` commands

## 1.2.2

### Fixes
- **Package Publishing**: Fixed package distribution to exclude large binary files
  - Added `.pubignore` to prevent ADB binary from being included in published package
  - Reduced package size from 6 MB to 21 KB

## 1.2.1

### Bug Fixes
- **File Upload to Private Directories**: Fixed issue with uploading files to app-specific private directories
  - Changed temporary storage location from `/sdcard/` to `/data/local/tmp/` for better reliability
  - Improved path handling for destination paths when using `packageName` parameter
  - Fixed path resolution logic for `privatePath.subPath` to properly handle directory paths ending with `/`

## 1.2.0

### New Features
- **System Information**: Retrieve detailed device information
  - `getBatteryInfo()` - Battery level, status, health, temperature, voltage
  - `getStorageInfo()` - Storage usage for all mount points
  - `getDisplayInfo()` - Screen resolution and density
  - `getNetworkInfo()` - WiFi status, IP addresses, network interfaces
- **App Management**: Control applications on the device
  - `launchApp()` - Launch an app by package name
  - `startActivity()` - Start a specific activity with extras, action, and data
  - `forceStopApp()` - Force stop a running application
  - `clearAppData()` - Clear all data for an application
  - `uninstallApplication()` - Uninstall an app with optional data preservation

### New Models
- `BatteryInfo` - Battery status with level, health, temperature, charging state
- `BatteryStatus` - Enumeration of battery states (charging, discharging, full, etc.)
- `BatteryHealth` - Enumeration of battery health states
- `PlugType` - Enumeration of power sources (ac, usb, wireless)
- `StorageInfo` - Storage mount information with size and usage
- `DisplayInfo` - Display resolution and density
- `NetworkInfo` - Network status with WiFi and interfaces
- `WifiInfo` - WiFi connection details
- `NetworkInterface` - Network interface with IP addresses

### New Services
- `AdbSystemService` - Service for system information retrieval

### Breaking Changes
- None - All existing APIs remain backward compatible

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
