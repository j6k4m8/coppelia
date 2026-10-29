import 'dart:async';

import 'cast_device.dart';
import 'discovery_provider.dart';
import '../utils/network_utils.dart';
import '../utils/logger.dart';

/// Manages device discovery across multiple protocol providers.
///
/// Merges device lists from all active providers, deduplicates by device ID,
/// filters out the local device, and emits a combined list as devices appear
/// or disappear.
class DiscoveryManager {
  final List<DeviceDiscoveryProvider> _providers;
  final List<StreamSubscription<List<CastDevice>>> _subscriptions = [];
  final Set<DeviceDiscoveryProvider> _activeProviders = {};
  StreamController<List<CastDevice>>? _outputController;
  Timer? _timeoutTimer;
  String? _localAddress;

  /// Per-provider device lists, keyed by provider index.
  final Map<int, List<CastDevice>> _providerDevices = {};

  /// Creates a [DiscoveryManager] with the given discovery [providers].
  DiscoveryManager(List<DeviceDiscoveryProvider> providers)
    : _providers = List.unmodifiable(providers);

  /// Starts discovery on matching providers and returns a merged stream.
  ///
  /// [protocols] filters which providers to start. Defaults to all.
  /// [timeout] controls how long discovery runs before the stream closes.
  Stream<List<CastDevice>> startDiscovery({
    Set<CastProtocol>? protocols,
    Duration timeout = const Duration(seconds: 10),
  }) {
    assert(
      _providers.isNotEmpty,
      'No discovery providers registered. Pass providers to DiscoveryManager or CastService.',
    );

    // Stop any previous discovery
    stopDiscovery();

    _outputController = StreamController<List<CastDevice>>.broadcast();
    _providerDevices.clear();

    // Detect local IP to filter out self-discovery
    _detectLocalAddress().catchError((_) {});

    final matchingProviders =
        protocols == null
            ? _providers
            : _providers.where((p) => protocols.contains(p.protocol)).toList();

    CastLogger.info(
      'Discovery: starting with ${matchingProviders.length} provider(s), '
      'timeout=${timeout.inSeconds}s',
    );

    for (var i = 0; i < matchingProviders.length; i++) {
      final provider = matchingProviders[i];
      final providerIndex = i;

      _activeProviders.add(provider);
      final stream = provider.startDiscovery(timeout: timeout);
      final subscription = stream.listen(
        (devices) {
          _providerDevices[providerIndex] = devices;
          _emitCombined();
        },
        onDone: () {
          // Check if all providers are done
          _checkCompletion(matchingProviders.length);
        },
        onError: (Object error) {
          CastLogger.warning(
            'Discovery: provider ${provider.protocol} error: $error',
          );
        },
      );
      _subscriptions.add(subscription);
    }

    // Set up timeout
    _timeoutTimer = Timer(timeout, () {
      stopDiscovery();
    });

    // If no matching providers, close immediately
    if (matchingProviders.isEmpty) {
      _outputController?.close();
    }

    return _outputController!.stream;
  }

  Future<void> _detectLocalAddress() async {
    _localAddress = await NetworkUtils.getLocalIpAddress();
  }

  void _emitCombined() {
    final seen = <String>{};
    final combined = <CastDevice>[];

    for (final devices in _providerDevices.values) {
      for (final device in devices) {
        if (!seen.add(device.id)) continue;
        if (_shouldFilter(device)) continue;
        combined.add(device);
      }
    }

    if (_outputController?.isClosed == false) {
      _outputController!.add(combined);
    }
  }

  /// Filter out devices that are not useful cast targets.
  bool _shouldFilter(CastDevice device) {
    // Filter out self (same IP as this device)
    if (_localAddress != null && device.address.address == _localAddress) {
      CastLogger.debug(
        'Filtering self-device: ${device.name} (${device.address.address})',
      );
      return true;
    }

    return false;
  }

  void _checkCompletion(int totalProviders) {
    // This is called when a provider's stream completes.
    // We don't close the output stream here — let the timeout handle it,
    // or let stopDiscovery close it.
  }

  /// Stops all active discovery scans.
  void stopDiscovery() {
    if (_activeProviders.isNotEmpty) {
      CastLogger.info('Discovery: stopping');
    }
    _timeoutTimer?.cancel();
    _timeoutTimer = null;

    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    for (final provider in _activeProviders) {
      provider.stopDiscovery();
    }
    _activeProviders.clear();

    if (_outputController?.isClosed == false) {
      _outputController?.close();
    }
    _outputController = null;
  }

  /// Disposes all providers and releases resources.
  void dispose() {
    stopDiscovery();
    for (final provider in _providers) {
      provider.dispose();
    }
  }
}
