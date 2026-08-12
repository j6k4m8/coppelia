import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';
import '../models/saved_server.dart';
import 'jellyfin_client.dart';

/// Couples a saved server profile with its persisted session.
class StoredServerSession {
  /// Creates a restored server session.
  const StoredServerSession({required this.server, required this.session});

  /// Saved server metadata.
  final SavedServer server;

  /// Runtime session used for authenticated requests.
  final AuthSession session;
}

/// Result of loading saved servers at startup.
class ServerBootstrapResult {
  /// Creates the startup result.
  const ServerBootstrapResult({
    required this.servers,
    required this.active,
    this.migratedServerId,
  });

  /// All valid saved servers.
  final List<SavedServer> servers;

  /// Restored active server, when a saved session is available.
  final StoredServerSession? active;

  /// The server whose legacy device data still needs migrating.
  final String? migratedServerId;
}

/// Stores saved server profiles and their independent local sessions.
class ServerStore {
  /// Creates a server store.
  ServerStore();

  static const _serversKey = 'saved_jellyfin_servers';
  static const _sessionsKey = 'saved_jellyfin_server_sessions';
  static const _activeServerIdKey = 'active_jellyfin_server';
  static const _legacySessionKey = 'auth_session';
  static const _pendingLegacyDataMigrationKey =
      'pending_jellyfin_legacy_data_migration';
  static const _pendingRemovalKey = 'pending_jellyfin_server_removals';

  /// Loads all saved server metadata.
  Future<List<SavedServer>> loadServers() async {
    final preferences = await SharedPreferences.getInstance();
    return _loadServers(preferences);
  }

  /// Restores the active server, migrating the old single-session storage first.
  Future<ServerBootstrapResult> bootstrap() async {
    final preferences = await SharedPreferences.getInstance();
    var servers = await _loadServers(preferences);
    var sessions = _loadSessions(preferences);
    final pendingRemovals =
        preferences.getStringList(_pendingRemovalKey) ?? const [];
    if (pendingRemovals.isNotEmpty) {
      final removedIds = pendingRemovals.toSet();
      servers =
          servers.where((server) => !removedIds.contains(server.id)).toList();
      sessions = {
        for (final entry in sessions.entries)
          if (!removedIds.contains(entry.key)) entry.key: entry.value,
      };
      await _saveServers(preferences, servers);
      await _saveSessions(preferences, sessions);
    }

    final serverIds = servers.map((server) => server.id).toSet();
    final knownSessions = {
      for (final entry in sessions.entries)
        if (serverIds.contains(entry.key)) entry.key: entry.value,
    };
    if (knownSessions.length != sessions.length) {
      sessions = knownSessions;
      await _saveSessions(preferences, sessions);
    }

    final legacy = _loadLegacySession(preferences);
    if (legacy != null) {
      final legacyUrl = JellyfinClient.normalizeServerUrl(legacy.serverUrl);
      final matching = servers
          .where(
            (server) =>
                server.userId == legacy.userId &&
                server.addresses.any((address) => address.url == legacyUrl),
          )
          .firstOrNull;
      final server = matching ?? _serverFromSession(legacy);
      if (matching == null) {
        servers = [...servers, server];
      }
      if (!sessions.containsKey(server.id)) {
        sessions = {...sessions, server.id: legacy};
      }

      // Keep the original single-session entry until the replacement data is
      // persisted, then retire it to prevent it drifting from the profile.
      await _saveServers(preferences, servers);
      await _saveSessions(preferences, sessions);
      await preferences.setString(_activeServerIdKey, server.id);
      await preferences.setString(_pendingLegacyDataMigrationKey, server.id);
      await preferences.remove(_legacySessionKey);
    }

    if (servers.isEmpty) {
      return const ServerBootstrapResult(servers: [], active: null);
    }

    final activeId = preferences.getString(_activeServerIdKey);
    final activeServer = servers.firstWhere(
      (server) => server.id == activeId,
      orElse: () => servers.first,
    );
    if (activeId != activeServer.id) {
      await preferences.setString(_activeServerIdKey, activeServer.id);
    }
    final active = _sessionFor(activeServer, sessions);
    return ServerBootstrapResult(
      servers: servers,
      active: active,
      migratedServerId: preferences.getString(_pendingLegacyDataMigrationKey),
    );
  }

  /// Saves a newly authenticated server and makes it active.
  Future<StoredServerSession> addAuthenticatedServer(
    AuthSession session, {
    String? name,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final servers = await _loadServers(preferences);
    final sessions = _loadSessions(preferences);
    final normalizedUrl = JellyfinClient.normalizeServerUrl(session.serverUrl);
    SavedServer? existing;
    for (final server in servers) {
      if (server.userId == session.userId &&
          server.addresses.any((address) => address.url == normalizedUrl)) {
        existing = server;
        break;
      }
    }
    if (existing != null) {
      final existingServer = existing;
      final address = existingServer.addresses.firstWhere(
        (entry) => entry.url == normalizedUrl,
      );
      final activeServer = existingServer.copyWith(activeAddressId: address.id);
      await _saveServers(
        preferences,
        servers
            .map(
              (server) =>
                  server.id == existingServer.id ? activeServer : server,
            )
            .toList(),
      );
      await _saveSessions(
        preferences,
        {...sessions, existingServer.id: session},
      );
      await preferences.setString(_activeServerIdKey, existingServer.id);
      return StoredServerSession(
        server: activeServer,
        session: AuthSession(
          accessToken: session.accessToken,
          serverUrl: address.url,
          userId: existingServer.userId,
          userName: existingServer.userName,
        ),
      );
    }

    final server = _serverFromSession(session, name: name);
    await _saveServers(preferences, [...servers, server]);
    await _saveSessions(preferences, {...sessions, server.id: session});
    await preferences.setString(_activeServerIdKey, server.id);
    return StoredServerSession(server: server, session: session);
  }

  /// Makes a saved server address active and returns its runtime session.
  Future<StoredServerSession?> activate(
    String serverId, {
    String? addressId,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final servers = await _loadServers(preferences);
    final sessions = _loadSessions(preferences);
    final index = servers.indexWhere((server) => server.id == serverId);
    if (index == -1) {
      return null;
    }
    var server = servers[index];
    if (addressId != null &&
        server.addresses.any((address) => address.id == addressId)) {
      server = server.copyWith(activeAddressId: addressId);
      servers[index] = server;
      await _saveServers(preferences, servers);
    }
    await preferences.setString(_activeServerIdKey, server.id);
    return _sessionFor(server, sessions);
  }

  /// Changes a server's user-facing name.
  Future<List<SavedServer>> renameServer(String serverId, String name) async {
    final preferences = await SharedPreferences.getInstance();
    final servers = await _loadServers(preferences);
    final nextName = name.trim();
    final updated = servers
        .map((server) => server.id == serverId && nextName.isNotEmpty
            ? server.copyWith(name: nextName)
            : server)
        .toList();
    await _saveServers(preferences, updated);
    return updated;
  }

  /// Adds a verified address to a saved server.
  Future<List<SavedServer>> addAddress(
    String serverId, {
    required String name,
    required String url,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final servers = await _loadServers(preferences);
    final index = servers.indexWhere((server) => server.id == serverId);
    if (index == -1) {
      throw StateError('Saved server was not found.');
    }
    final server = servers[index];
    final address = ServerAddress(
      id: _newId(),
      name: name.trim().isEmpty ? _nameFromUrl(url) : name.trim(),
      url: JellyfinClient.normalizeServerUrl(url),
    );
    if (server.addresses.any((existing) => existing.url == address.url)) {
      throw StateError('That address is already saved.');
    }
    servers[index] = server.copyWith(addresses: [...server.addresses, address]);
    await _saveServers(preferences, servers);
    return servers;
  }

  /// Updates an existing address label and URL.
  Future<List<SavedServer>> updateAddress(
    String serverId,
    String addressId, {
    required String name,
    required String url,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final servers = await _loadServers(preferences);
    final index = servers.indexWhere((server) => server.id == serverId);
    if (index == -1) {
      throw StateError('Saved server was not found.');
    }
    final server = servers[index];
    final normalizedUrl = JellyfinClient.normalizeServerUrl(url);
    if (server.addresses.any(
      (address) => address.id != addressId && address.url == normalizedUrl,
    )) {
      throw StateError('That address is already saved.');
    }
    final addresses = server.addresses
        .map(
          (address) => address.id == addressId
              ? address.copyWith(
                  name: name.trim().isEmpty
                      ? _nameFromUrl(normalizedUrl)
                      : name.trim(),
                  url: normalizedUrl,
                )
              : address,
        )
        .toList();
    servers[index] = server.copyWith(addresses: addresses);
    await _saveServers(preferences, servers);
    return servers;
  }

  /// Removes a non-active address from a saved server.
  Future<List<SavedServer>> removeAddress(
      String serverId, String addressId) async {
    final preferences = await SharedPreferences.getInstance();
    final servers = await _loadServers(preferences);
    final index = servers.indexWhere((server) => server.id == serverId);
    if (index == -1) {
      throw StateError('Saved server was not found.');
    }
    final server = servers[index];
    if (server.addresses.length == 1) {
      throw StateError('A server needs at least one address.');
    }
    final addresses =
        server.addresses.where((address) => address.id != addressId).toList();
    if (addresses.length == server.addresses.length) {
      return servers;
    }
    servers[index] = server.copyWith(
      addresses: addresses,
      activeAddressId: server.activeAddressId == addressId
          ? addresses.first.id
          : server.activeAddressId,
    );
    await _saveServers(preferences, servers);
    return servers;
  }

  /// Removes a server and its local session, returning the next active server.
  Future<StoredServerSession?> removeServer(String serverId) async {
    final preferences = await SharedPreferences.getInstance();
    final servers = await _loadServers(preferences);
    final sessions = _loadSessions(preferences);
    final removed =
        servers.where((server) => server.id == serverId).firstOrNull;
    if (removed == null) {
      return null;
    }
    final remaining = servers.where((server) => server.id != serverId).toList();
    final previousActiveId = preferences.getString(_activeServerIdKey);
    final next = remaining.isEmpty
        ? null
        : remaining.firstWhere(
            (server) => server.id == previousActiveId,
            orElse: () => remaining.first,
          );

    // The tombstone is written first. If the app stops at any later point,
    // bootstrap finishes deleting both the profile and its session.
    await _addPendingRemoval(preferences, serverId);
    final remainingSessions = {...sessions}..remove(serverId);
    await _saveSessions(preferences, remainingSessions);
    await _saveServers(preferences, remaining);
    if (next == null) {
      await preferences.remove(_activeServerIdKey);
    } else {
      await preferences.setString(_activeServerIdKey, next.id);
    }
    if (remaining.isEmpty) {
      return null;
    }
    return _sessionFor(next!, remainingSessions);
  }

  /// Returns server IDs whose isolated device data still needs deleting.
  Future<List<String>> pendingServerRemovals() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_pendingRemovalKey) ?? const [];
  }

  /// Marks a profile's scoped device data as deleted.
  Future<void> completeServerRemoval(String serverId) async {
    final preferences = await SharedPreferences.getInstance();
    await _removePendingRemoval(preferences, serverId);
  }

  /// Marks a completed migration of device data from the single-session era.
  Future<void> completeLegacyDataMigration(String serverId) async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getString(_pendingLegacyDataMigrationKey) == serverId) {
      await preferences.remove(_pendingLegacyDataMigrationKey);
    }
  }

  /// Gets the stored session for a specific saved address.
  Future<StoredServerSession?> sessionFor(
    SavedServer server, {
    String? addressId,
  }) async {
    final active = addressId == null
        ? server.activeAddress
        : server.addresses.firstWhere((address) => address.id == addressId);
    final preferences = await SharedPreferences.getInstance();
    return _sessionFor(
      server.copyWith(activeAddressId: active.id),
      _loadSessions(preferences),
    );
  }

  StoredServerSession? _sessionFor(
    SavedServer server,
    Map<String, AuthSession> sessions,
  ) {
    final storedSession = sessions[server.id];
    if (storedSession == null || storedSession.accessToken.isEmpty) {
      return null;
    }
    return StoredServerSession(
      server: server,
      session: AuthSession(
        accessToken: storedSession.accessToken,
        serverUrl: server.activeAddress.url,
        userId: server.userId,
        userName: server.userName,
      ),
    );
  }

  Future<List<SavedServer>> _loadServers(SharedPreferences preferences) async {
    final raw = preferences.getString(_serversKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map>()
          .map((json) => SavedServer.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _addPendingRemoval(
    SharedPreferences preferences,
    String serverId,
  ) async {
    final pending = preferences.getStringList(_pendingRemovalKey) ?? const [];
    if (pending.contains(serverId)) {
      return;
    }
    await preferences.setStringList(_pendingRemovalKey, [...pending, serverId]);
  }

  Future<void> _removePendingRemoval(
    SharedPreferences preferences,
    String serverId,
  ) async {
    final pending = preferences.getStringList(_pendingRemovalKey) ?? const [];
    final remaining = pending.where((id) => id != serverId).toList();
    if (remaining.isEmpty) {
      await preferences.remove(_pendingRemovalKey);
    } else {
      await preferences.setStringList(_pendingRemovalKey, remaining);
    }
  }

  Future<void> _saveServers(
    SharedPreferences preferences,
    List<SavedServer> servers,
  ) async {
    await preferences.setString(
      _serversKey,
      jsonEncode(servers.map((server) => server.toJson()).toList()),
    );
  }

  Map<String, AuthSession> _loadSessions(SharedPreferences preferences) {
    final raw = preferences.getString(_sessionsKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return {};
    }
    if (decoded is! Map) {
      return {};
    }
    final sessions = <String, AuthSession>{};
    for (final entry in decoded.entries) {
      if (entry.key is! String || entry.value is! Map) {
        continue;
      }
      try {
        sessions[entry.key as String] =
            AuthSession.fromJson(Map<String, dynamic>.from(entry.value as Map));
      } catch (_) {
        // One malformed profile must not discard the other saved sessions.
      }
    }
    return sessions;
  }

  Future<void> _saveSessions(
    SharedPreferences preferences,
    Map<String, AuthSession> sessions,
  ) async {
    if (sessions.isEmpty) {
      await preferences.remove(_sessionsKey);
      return;
    }
    await preferences.setString(
      _sessionsKey,
      jsonEncode(
        sessions
            .map((serverId, session) => MapEntry(serverId, session.toJson())),
      ),
    );
  }

  AuthSession? _loadLegacySession(SharedPreferences preferences) {
    final raw = preferences.getString(_legacySessionKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return AuthSession.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  SavedServer _serverFromSession(AuthSession session, {String? name}) {
    final serverName = name?.trim();
    final address = ServerAddress(
      id: _newId(),
      name: _nameFromUrl(session.serverUrl),
      url: JellyfinClient.normalizeServerUrl(session.serverUrl),
    );
    return SavedServer(
      id: _newId(),
      name: serverName == null || serverName.isEmpty
          ? _nameFromUrl(session.serverUrl)
          : serverName,
      userId: session.userId,
      userName: session.userName,
      addresses: [address],
      activeAddressId: address.id,
    );
  }

  String _nameFromUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri?.host.isNotEmpty == true ? uri!.host : url;
  }

  String _newId() {
    final random = Random.secure();
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final entropy = List<int>.generate(16, (_) => random.nextInt(256))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '$timestamp-$entropy';
  }
}
