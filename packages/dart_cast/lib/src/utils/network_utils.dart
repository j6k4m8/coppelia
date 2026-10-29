import 'dart:io';

import '../utils/logger.dart';

/// Network utility methods for casting.
class NetworkUtils {
  NetworkUtils._();

  /// Returns the local non-loopback IPv4 address best suited for reaching
  /// [targetDeviceIp].
  ///
  /// Selection priority:
  /// 1. Interface on the **same /24 subnet** as [targetDeviceIp]
  /// 2. Any RFC 1918 private address (192.168.x, 10.x, 172.16-31.x)
  /// 3. First non-loopback IPv4 address
  ///
  /// If [targetDeviceIp] is null, skips subnet matching and falls back to
  /// the private-address / first-address heuristic.
  static Future<String?> getLocalIpAddress({String? targetDeviceIp}) async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );

    final allAddresses = <InternetAddress>[];
    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (!addr.isLoopback && !addr.isLinkLocal) {
          allAddresses.add(addr);
        }
      }
    }

    if (allAddresses.isEmpty) return null;

    // 1. Same-subnet match (compare first 3 octets = /24)
    if (targetDeviceIp != null) {
      final targetPrefix = subnetPrefix(targetDeviceIp);
      if (targetPrefix != null) {
        for (final addr in allAddresses) {
          if (subnetPrefix(addr.address) == targetPrefix) {
            CastLogger.debug(
              'NetworkUtils: picked ${addr.address} (same subnet as $targetDeviceIp)',
            );
            return addr.address;
          }
        }
        CastLogger.warning(
          'NetworkUtils: no interface on same subnet as $targetDeviceIp, '
          'falling back to private IP heuristic',
        );
      }
    }

    // 2. Prefer RFC 1918 private addresses
    for (final addr in allAddresses) {
      if (isPrivateAddress(addr.address)) {
        CastLogger.debug(
          'NetworkUtils: picked ${addr.address} (private address)',
        );
        return addr.address;
      }
    }

    // 3. First non-loopback address
    CastLogger.debug(
      'NetworkUtils: picked ${allAddresses.first.address} (first available)',
    );
    return allAddresses.first.address;
  }

  /// Returns the /24 subnet prefix (first 3 octets), or null if invalid.
  static String? subnetPrefix(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  /// Returns true if [ip] is an RFC 1918 private address.
  static bool isPrivateAddress(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a == null || b == null) return false;
    // 10.0.0.0/8
    if (a == 10) return true;
    // 172.16.0.0/12
    if (a == 172 && b >= 16 && b <= 31) return true;
    // 192.168.0.0/16
    if (a == 192 && b == 168) return true;
    return false;
  }

  /// Finds an available port by binding to port 0.
  static Future<int> findAvailablePort() async {
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    final port = server.port;
    await server.close();
    return port;
  }

  /// Formats a [Duration] as 'HH:MM:SS'.
  static String formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  /// Parses a 'HH:MM:SS' string into a [Duration].
  static Duration parseDuration(String formatted) {
    final parts = formatted.split(':');
    if (parts.length != 3) return Duration.zero;
    return Duration(
      hours: int.tryParse(parts[0]) ?? 0,
      minutes: int.tryParse(parts[1]) ?? 0,
      seconds: int.tryParse(parts[2]) ?? 0,
    );
  }
}
