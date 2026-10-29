import 'cast_device.dart';

/// Abstract interface for protocol-specific device discovery.
///
/// Chromecast implements this interface to provide mDNS discovery.
abstract class DeviceDiscoveryProvider {
  /// The protocol this provider discovers devices for.
  CastProtocol get protocol;

  /// Starts discovering devices, emitting updated lists as devices appear.
  ///
  /// The [timeout] controls how long discovery runs before the stream closes.
  Stream<List<CastDevice>> startDiscovery({Duration timeout});

  /// Stops an active discovery scan.
  void stopDiscovery();

  /// Releases all resources held by this provider.
  void dispose();
}
