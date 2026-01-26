/// Represents the battery status of an Android device.
class BatteryInfo {
  /// Battery level as a percentage (0-100).
  final int level;

  /// Current battery status.
  final BatteryStatus status;

  /// Battery health status.
  final BatteryHealth health;

  /// Whether the device is plugged in.
  final bool isPlugged;

  /// Type of power source if plugged in.
  final PlugType? plugType;

  /// Battery temperature in degrees Celsius.
  final double temperature;

  /// Battery voltage in millivolts.
  final int voltage;

  /// Battery technology (e.g., 'Li-ion').
  final String? technology;

  const BatteryInfo({
    required this.level,
    required this.status,
    required this.health,
    required this.isPlugged,
    this.plugType,
    required this.temperature,
    required this.voltage,
    this.technology,
  });

  @override
  String toString() {
    return 'BatteryInfo(level: $level%, status: ${status.name}, health: ${health.name}, temp: $temperature°C)';
  }
}

/// Battery charging status.
enum BatteryStatus {
  unknown,
  charging,
  discharging,
  notCharging,
  full,
}

/// Battery health status.
enum BatteryHealth {
  unknown,
  good,
  overheat,
  dead,
  overVoltage,
  unspecifiedFailure,
  cold,
}

/// Type of power source.
enum PlugType {
  ac,
  usb,
  wireless,
}
