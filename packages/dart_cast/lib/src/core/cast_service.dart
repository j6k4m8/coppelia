import 'dart:async';

import 'cast_device.dart';
import 'cast_session.dart';
import 'discovery_manager.dart';
import 'discovery_provider.dart';
import '../utils/logger.dart';

/// Factory function for creating protocol-specific sessions.
typedef SessionFactory = CastSession Function(CastDevice device);

/// Entry point for casting to Chromecast devices.
///
/// Provides device discovery, session management, and reconnection support.
///
/// ```dart
/// final service = CastService();
/// service.startDiscovery().listen((devices) => print(devices));
/// final session = await service.connect(devices.first);
/// await session.loadMedia(media);
/// ```
class CastService {
  final DiscoveryManager _discoveryManager;
  final SessionFactory? _sessionFactory;

  CastSession? _activeSession;
  CastDevice? _lastDevice;

  /// Creates a [CastService].
  ///
  /// [discoveryProviders] are the protocol-specific discovery providers.
  /// [sessionFactory] creates sessions — if not provided, callers must
  /// supply protocol-specific session implementations.
  CastService({
    List<DeviceDiscoveryProvider>? discoveryProviders,
    SessionFactory? sessionFactory,
  }) : _discoveryManager = DiscoveryManager(discoveryProviders ?? []),
       _sessionFactory = sessionFactory;

  /// Starts discovering cast devices on the local network.
  ///
  /// [protocols] filters which protocols to scan. Defaults to all.
  /// [timeout] controls how long discovery runs before the stream closes.
  ///
  /// Calling this while a previous discovery is active stops the previous one.
  Stream<List<CastDevice>> startDiscovery({
    Set<CastProtocol>? protocols,
    Duration timeout = const Duration(seconds: 10),
  }) {
    return _discoveryManager.startDiscovery(
      protocols: protocols,
      timeout: timeout,
    );
  }

  /// Stops any active device discovery.
  void stopDiscovery() {
    _discoveryManager.stopDiscovery();
  }

  /// Connects to a cast device, creating a protocol-specific session.
  ///
  /// If already connected to another device, the previous session is
  /// automatically disconnected first.
  ///
  /// Sets [lastDevice] to the connected device for later [reconnect].
  Future<CastSession> connect(CastDevice device) async {
    CastLogger.info(
      'CastService: connecting to ${device.name} (${device.protocol})',
    );

    // Auto-disconnect previous session
    if (_activeSession != null) {
      try {
        await _activeSession!.disconnect();
      } catch (e) {
        CastLogger.warning(
          'CastService: error disconnecting previous session: $e',
        );
      }
    }

    final session = _createSession(device);
    await session.connect();
    _activeSession = session;
    _lastDevice = device;
    CastLogger.info('CastService: connected to ${device.name}');
    return session;
  }

  /// The currently active cast session, or null if not connected.
  CastSession? get activeSession => _activeSession;

  /// The last device connected to, for [reconnect] support.
  CastDevice? get lastDevice => _lastDevice;

  /// Sets the last device for [reconnect] support.
  ///
  /// Useful for restoring a saved device from persistent storage.
  void setLastDevice(CastDevice? device) {
    _lastDevice = device;
  }

  /// Reconnects to the [lastDevice].
  ///
  /// Returns null if no [lastDevice] is set.
  Future<CastSession?> reconnect() async {
    if (_lastDevice == null) return null;
    return connect(_lastDevice!);
  }

  /// Releases all resources: stops discovery, disconnects active session,
  /// and disposes all discovery providers.
  Future<void> dispose() async {
    _discoveryManager.dispose();

    if (_activeSession != null) {
      try {
        await _activeSession!.disconnect();
      } catch (e) {
        CastLogger.warning('CastService: error during dispose disconnect: $e');
      }
      _activeSession = null;
    }
  }

  CastSession _createSession(CastDevice device) {
    if (_sessionFactory != null) {
      return _sessionFactory(device);
    }
    throw StateError(
      'No sessionFactory provided. Supply a sessionFactory in the '
      'CastService constructor or use protocol-specific session classes.',
    );
  }
}
