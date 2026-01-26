/// Represents network information for an Android device.
class NetworkInfo {
  /// WiFi status.
  final WifiInfo? wifi;

  /// List of network interfaces with their IP addresses.
  final List<NetworkInterface> interfaces;

  const NetworkInfo({
    this.wifi,
    required this.interfaces,
  });

  @override
  String toString() {
    final wifiStatus = wifi != null ? 'connected to ${wifi!.ssid}' : 'disconnected';
    return 'NetworkInfo(wifi: $wifiStatus, interfaces: ${interfaces.length})';
  }
}

/// Represents WiFi connection information.
class WifiInfo {
  /// Network SSID (name).
  final String? ssid;

  /// WiFi signal strength in dBm.
  final int? rssi;

  /// Link speed in Mbps.
  final int? linkSpeed;

  /// IP address assigned via WiFi.
  final String? ipAddress;

  /// MAC address of the WiFi interface.
  final String? macAddress;

  const WifiInfo({
    this.ssid,
    this.rssi,
    this.linkSpeed,
    this.ipAddress,
    this.macAddress,
  });

  @override
  String toString() {
    return 'WifiInfo(ssid: $ssid, ip: $ipAddress, rssi: ${rssi}dBm)';
  }
}

/// Represents a network interface.
class NetworkInterface {
  /// Interface name (e.g., 'wlan0', 'eth0').
  final String name;

  /// IPv4 address if available.
  final String? ipv4Address;

  /// IPv6 address if available.
  final String? ipv6Address;

  /// MAC address.
  final String? macAddress;

  const NetworkInterface({
    required this.name,
    this.ipv4Address,
    this.ipv6Address,
    this.macAddress,
  });

  @override
  String toString() {
    return 'NetworkInterface(name: $name, ipv4: $ipv4Address)';
  }
}
