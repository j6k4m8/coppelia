import 'dart:io';

/// Protocol types supported for casting.
enum CastProtocol { chromecast }

/// Represents a discovered cast-capable device on the network.
class CastDevice {
  /// Unique identifier for this device.
  final String id;

  /// Human-readable name of the device.
  final String name;

  /// The casting protocol this device supports.
  final CastProtocol protocol;

  /// Network address of the device.
  final InternetAddress address;

  /// Port number for the casting service.
  final int port;

  /// Additional metadata about the device.
  final Map<String, String> metadata;

  /// Creates a [CastDevice].
  CastDevice({
    required this.id,
    required this.name,
    required this.protocol,
    required this.address,
    required this.port,
    this.metadata = const {},
  });

  /// Serializes this device to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'protocol': protocol.name,
    'address': address.address,
    'port': port,
    'metadata': metadata,
  };

  /// Creates a [CastDevice] from a JSON map.
  factory CastDevice.fromJson(Map<String, dynamic> json) {
    return CastDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      protocol: CastProtocol.values.byName(json['protocol'] as String),
      address: InternetAddress(json['address'] as String),
      port: json['port'] as int,
      metadata:
          (json['metadata'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ??
          const {},
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CastDevice && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CastDevice($name, $protocol, ${address.address}:$port)';
}
