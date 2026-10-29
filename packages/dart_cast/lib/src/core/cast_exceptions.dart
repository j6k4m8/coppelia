import 'cast_device.dart';

/// Base exception for all casting errors.
class CastException implements Exception {
  /// Description of the error.
  final String message;

  /// Optional underlying cause.
  final Object? cause;

  /// Creates a [CastException].
  CastException(this.message, [this.cause]);

  @override
  String toString() =>
      cause != null
          ? 'CastException: $message (cause: $cause)'
          : 'CastException: $message';
}

/// Thrown when a device cannot be reached on the network.
class DeviceUnreachableException extends CastException {
  DeviceUnreachableException(super.message, [super.cause]);
}

/// Thrown when the connection to a device is lost unexpectedly.
class ConnectionLostException extends CastException {
  ConnectionLostException(super.message, [super.cause]);
}

/// Thrown when media fails to load on the cast device.
class MediaLoadFailedException extends CastException {
  MediaLoadFailedException(super.message, [super.cause]);
}

/// Thrown when the media proxy encounters an upstream error.
class ProxyUpstreamException extends CastException {
  ProxyUpstreamException(super.message, [super.cause]);
}

/// Thrown when device discovery encounters an error.
class DiscoveryException extends CastException {
  DiscoveryException(super.message, [super.cause]);
}

/// Thrown when an AirPlay device requires HAP pairing (PIN entry).
///
/// The caller should prompt the user for a PIN, then call
/// `AirPlaySession.pairSetup(pin)` to complete pairing.
class NeedsPairingException extends CastException {
  NeedsPairingException([super.message = 'Device requires HAP pairing (PIN)']);
}

/// Thrown when a device does not support the requested feature.
class UnsupportedFeatureException extends CastException {
  UnsupportedFeatureException(super.message);
}

/// Thrown when playback fails after trying all available formats.
class PlaybackException extends CastException {
  final int? statusCode;
  PlaybackException(super.message, {this.statusCode});
}

/// Thrown when a protocol-specific error occurs.
class ProtocolException extends CastException {
  /// The protocol that encountered the error.
  final CastProtocol protocol;

  ProtocolException(super.message, this.protocol, [super.cause]);

  @override
  String toString() => 'ProtocolException(${protocol.name}): $message';
}
