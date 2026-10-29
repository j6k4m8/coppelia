import 'dart:async';
import 'dart:io';

import 'package:multicast_dns/multicast_dns.dart';

import '../core/cast_device.dart';
import 'logger.dart';

/// Represents a discovered mDNS service with its TXT records.
///
/// Chromecast mDNS service information.
class MdnsServiceInfo {
  /// The mDNS service name.
  final String name;

  /// The resolved host address.
  final String host;

  /// The service port.
  final int port;

  /// TXT record key-value pairs from the mDNS advertisement.
  final Map<String, String> txtRecords;

  const MdnsServiceInfo({
    required this.name,
    required this.host,
    required this.port,
    required this.txtRecords,
  });

  /// Human-readable device name.
  ///
  /// Uses the Chromecast `fn` TXT field if present, otherwise falls back
  /// to the mDNS service [name].
  String get friendlyName {
    if (txtRecords.containsKey('fn')) return txtRecords['fn']!;
    // Strip the mDNS service suffix from the instance name.
    final dotIndex = name.indexOf('._');
    return dotIndex > 0 ? name.substring(0, dotIndex) : name;
  }

  /// Unique device identifier.
  ///
  /// Uses the Chromecast `id` TXT field.
  String get deviceId => txtRecords['id'] ?? txtRecords['deviceid'] ?? '';

  /// Device model string.
  ///
  /// Uses the Chromecast `md` TXT field.
  String get model => txtRecords['md'] ?? txtRecords['model'] ?? '';

  /// Creates a [CastDevice] configured for the Chromecast protocol.
  CastDevice toChromecastDevice() {
    return CastDevice(
      id: deviceId,
      name: friendlyName,
      protocol: CastProtocol.chromecast,
      address: InternetAddress(host),
      port: port,
      metadata: Map<String, String>.from(txtRecords),
    );
  }
}

/// Function type for performing mDNS service discovery.
///
/// Returns a stream of [MdnsServiceInfo] entries found on the network.
typedef MdnsLookup = Stream<MdnsServiceInfo> Function(String serviceType);

/// Constants and utilities for mDNS-based device discovery.
class MdnsDiscovery {
  MdnsDiscovery._();

  /// mDNS service type for Chromecast devices.
  static const String chromecastServiceType = '_googlecast._tcp.local';

  /// Discover mDNS services of the given [serviceType] using the
  /// `multicast_dns` package.
  ///
  /// Yields [MdnsServiceInfo] entries as they are found on the local network.
  /// The stream completes after all discovered PTR records have been resolved.
  static Stream<MdnsServiceInfo> discover(String serviceType) async* {
    CastLogger.info('mDNS: starting discovery for $serviceType');
    final client = MDnsClient();
    try {
      await client.start();
      CastLogger.debug('mDNS: client started, querying PTR records');
    } catch (e) {
      CastLogger.error('mDNS discovery failed to start: $e');
      return;
    }

    try {
      const nestedTimeout = Duration(seconds: 3);
      final seenServices = <String>{};

      // Send multiple mDNS queries to catch slow-responding devices.
      // Each lookup() sends one query — devices may not respond to the first.
      for (int round = 0; round < 3; round++) {
        if (round > 0) {
          await Future<void>.delayed(const Duration(seconds: 2));
          CastLogger.debug(
            'mDNS: re-querying PTR records (round ${round + 1})',
          );
        }

        // Query for PTR records (service instances).
        await for (final PtrResourceRecord ptr in client
            .lookup<PtrResourceRecord>(
              ResourceRecordQuery.serverPointer(serviceType),
            )) {
          // Skip already-discovered services
          if (seenServices.contains(ptr.domainName)) continue;
          seenServices.add(ptr.domainName);
          try {
            // For each PTR result, look up SRV record (host + port).
            await for (final SrvResourceRecord srv in client
                .lookup<SrvResourceRecord>(
                  ResourceRecordQuery.service(ptr.domainName),
                )
                .timeout(nestedTimeout, onTimeout: (sink) => sink.close())) {
              try {
                // Look up A record (IPv4 address).
                await for (final IPAddressResourceRecord ip in client
                    .lookup<IPAddressResourceRecord>(
                      ResourceRecordQuery.addressIPv4(srv.target),
                    )
                    .timeout(
                      nestedTimeout,
                      onTimeout: (sink) => sink.close(),
                    )) {
                  // Look up TXT records (metadata key=value pairs).
                  final txtRecords = <String, String>{};
                  try {
                    await for (final TxtResourceRecord txt in client
                        .lookup<TxtResourceRecord>(
                          ResourceRecordQuery.text(ptr.domainName),
                        )
                        .timeout(
                          nestedTimeout,
                          onTimeout: (sink) => sink.close(),
                        )) {
                      // The multicast_dns package joins TXT strings with writeln(),
                      // producing newline-separated key=value pairs.
                      for (final line in txt.text.split('\n')) {
                        final trimmed = line.trim();
                        if (trimmed.isEmpty) continue;
                        final eqIndex = trimmed.indexOf('=');
                        if (eqIndex > 0) {
                          txtRecords[trimmed.substring(0, eqIndex)] = trimmed
                              .substring(eqIndex + 1);
                        }
                      }
                    }
                  } catch (_) {
                    // TXT lookup timed out — proceed with empty TXT records
                  }

                  CastLogger.info(
                    'mDNS: found service "${ptr.domainName}" at ${ip.address.address}:${srv.port}',
                  );
                  yield MdnsServiceInfo(
                    name: ptr.domainName,
                    host: ip.address.address,
                    port: srv.port,
                    txtRecords: txtRecords,
                  );
                }
              } catch (_) {
                // A record lookup timed out — skip this device
              }
            }
          } catch (_) {
            // SRV lookup timed out — skip this device
          }
        }
      } // end for round
    } finally {
      client.stop();
    }
  }
}
