/// Chromecast receiver channel message builders and parsers.
///
/// Handles the `urn:x-cast:com.google.cast.receiver` namespace for
/// launching/stopping apps, querying status, and setting device volume,
/// as well as connection and heartbeat namespaces.
library;

import 'dart:convert';

/// Parsed receiver status from a RECEIVER_STATUS message.
class ReceiverStatusInfo {
  /// The transport ID used as destination for media commands.
  final String transportId;

  /// The session ID used for stopping the app.
  final String sessionId;

  /// The application ID.
  final String appId;

  /// Device volume level (0.0 to 1.0).
  final double volumeLevel;

  /// Whether the device is muted.
  final bool isMuted;

  /// Creates a [ReceiverStatusInfo].
  const ReceiverStatusInfo({
    required this.transportId,
    required this.sessionId,
    required this.appId,
    required this.volumeLevel,
    required this.isMuted,
  });
}

/// Builds and parses messages for Chromecast receiver control.
class CastReceiverChannel {
  /// Connection namespace for virtual connections.
  static const connectionNamespace = 'urn:x-cast:com.google.cast.tp.connection';

  /// Heartbeat namespace for keep-alive.
  static const heartbeatNamespace = 'urn:x-cast:com.google.cast.tp.heartbeat';

  /// Receiver namespace for app/device control.
  static const receiverNamespace = 'urn:x-cast:com.google.cast.receiver';

  /// Cast Command-and-Control namespace, used by CaC Tool. The Default
  /// Media Receiver advertises this and broadcasts debug / log events on
  /// it once a sender subscribes. We use it to surface receiver-side
  /// LOAD_FAILED detail that doesn't appear in the standard MEDIA_STATUS.
  static const cacNamespace = 'urn:x-cast:com.google.cast.cac';

  /// Receiver-side debug overlay namespace. Sending `SHOW` here makes the
  /// TV draw a debug overlay with playback errors, useful when remote
  /// debugging isn't available.
  static const debugOverlayNamespace =
      'urn:x-cast:com.google.cast.debugoverlay';

  /// Default Media Receiver app ID.
  static const defaultMediaReceiverAppId = 'CC1AD845';

  /// Auto-incrementing request ID counter.
  int _requestId = 0;

  /// Returns the next request ID.
  int nextRequestId() => ++_requestId;

  // ---------------------------------------------------------------------------
  // Static builders (no requestId needed)
  // ---------------------------------------------------------------------------

  /// Builds a CONNECT message.
  static String buildConnect() {
    return jsonEncode({'type': 'CONNECT', 'origin': {}});
  }

  /// Builds a CLOSE message.
  static String buildClose() {
    return jsonEncode({'type': 'CLOSE'});
  }

  /// Builds a PING message.
  static String buildPing() {
    return jsonEncode({'type': 'PING'});
  }

  // ---------------------------------------------------------------------------
  // Static builders with auto-generated requestId (use a shared counter)
  // ---------------------------------------------------------------------------

  static int _staticRequestId = 0;

  static int _nextStaticRequestId() => ++_staticRequestId;

  /// Builds a LAUNCH message with a static request ID.
  static String buildLaunch([String appId = defaultMediaReceiverAppId]) {
    return jsonEncode({
      'type': 'LAUNCH',
      'appId': appId,
      'requestId': _nextStaticRequestId(),
    });
  }

  /// Builds a GET_STATUS message with a static request ID.
  static String buildGetStatus() {
    return jsonEncode({
      'type': 'GET_STATUS',
      'requestId': _nextStaticRequestId(),
    });
  }

  /// Builds a STOP message with a static request ID.
  static String buildStop(String sessionId) {
    return jsonEncode({
      'type': 'STOP',
      'sessionId': sessionId,
      'requestId': _nextStaticRequestId(),
    });
  }

  /// Builds a SET_VOLUME message with a static request ID.
  static String buildSetVolume({double? level, bool? muted}) {
    final volume = <String, dynamic>{};
    if (level != null) volume['level'] = level;
    if (muted != null) volume['muted'] = muted;
    return jsonEncode({
      'type': 'SET_VOLUME',
      'volume': volume,
      'requestId': _nextStaticRequestId(),
    });
  }

  // ---------------------------------------------------------------------------
  // Instance builders (use instance requestId counter)
  // ---------------------------------------------------------------------------

  /// Builds a LAUNCH message with an instance-scoped request ID.
  String buildLaunchWithId([String appId = defaultMediaReceiverAppId]) {
    return jsonEncode({
      'type': 'LAUNCH',
      'appId': appId,
      'requestId': nextRequestId(),
    });
  }

  /// Builds a GET_STATUS message with an instance-scoped request ID.
  String buildGetStatusWithId() {
    return jsonEncode({'type': 'GET_STATUS', 'requestId': nextRequestId()});
  }

  /// Builds a STOP message with an instance-scoped request ID.
  String buildStopWithId(String sessionId) {
    return jsonEncode({
      'type': 'STOP',
      'sessionId': sessionId,
      'requestId': nextRequestId(),
    });
  }

  /// Builds a SET_VOLUME message with an instance-scoped request ID.
  String buildSetVolumeWithId({double? level, bool? muted}) {
    final volume = <String, dynamic>{};
    if (level != null) volume['level'] = level;
    if (muted != null) volume['muted'] = muted;
    return jsonEncode({
      'type': 'SET_VOLUME',
      'volume': volume,
      'requestId': nextRequestId(),
    });
  }

  // ---------------------------------------------------------------------------
  // Parsers
  // ---------------------------------------------------------------------------

  /// Parses a RECEIVER_STATUS payload and extracts app info and volume.
  ///
  /// Returns null if no applications are running.
  static ReceiverStatusInfo? parseReceiverStatus(Map<String, dynamic> json) {
    final status = json['status'] as Map<String, dynamic>?;
    if (status == null) return null;

    final apps = status['applications'] as List?;
    if (apps == null || apps.isEmpty) return null;

    final app = apps[0] as Map<String, dynamic>;
    final volume = status['volume'] as Map<String, dynamic>?;

    return ReceiverStatusInfo(
      transportId: app['transportId'] as String,
      sessionId: app['sessionId'] as String,
      appId: app['appId'] as String,
      volumeLevel: (volume?['level'] as num?)?.toDouble() ?? 1.0,
      isMuted: (volume?['muted'] as bool?) ?? false,
    );
  }

  /// Returns true if the message is a PONG heartbeat response.
  static bool isPong(Map<String, dynamic> json) {
    return json['type'] == 'PONG';
  }
}
