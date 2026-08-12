import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:coppelia/models/auth_session.dart';
import 'package:coppelia/models/saved_server.dart';
import 'package:coppelia/services/server_store.dart';
import 'package:coppelia/services/settings_store.dart';
import 'package:coppelia/state/sidebar_item.dart';

const _legacySession = AuthSession(
  accessToken: 'secret-access-token',
  serverUrl: 'https://music.example.com',
  userId: 'user-1',
  userName: 'Jordan',
);

Map<String, dynamic> _legacySessionJson() => {
      'accessToken': _legacySession.accessToken,
      'serverUrl': _legacySession.serverUrl,
      'userId': _legacySession.userId,
      'userName': _legacySession.userName,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migrates the single session into per-server storage', () async {
    SharedPreferences.setMockInitialValues({
      'auth_session': jsonEncode(_legacySessionJson()),
    });
    final store = ServerStore();

    final result = await store.bootstrap();
    final preferences = await SharedPreferences.getInstance();
    final metadata = preferences.getString('saved_jellyfin_servers');
    final sessions = preferences.getString('saved_jellyfin_server_sessions');

    expect(result.servers, hasLength(1));
    expect(result.active?.session.accessToken, _legacySession.accessToken);
    expect(result.active?.session.serverUrl, _legacySession.serverUrl);
    expect(result.active?.session.userId, _legacySession.userId);
    expect(result.migratedServerId, result.servers.single.id);
    expect(preferences.getString('auth_session'), isNull);
    expect(metadata, isNotNull);
    expect(metadata, isNot(contains(_legacySession.accessToken)));
    expect(sessions, contains(_legacySession.accessToken));
  });

  test('retires the single-session entry after migration', () async {
    const server = SavedServer(
      id: 'server-1',
      name: 'Music',
      userId: 'user-1',
      userName: 'Jordan',
      addresses: [
        ServerAddress(
          id: 'address-1',
          name: 'Music',
          url: 'https://music.example.com',
        ),
      ],
      activeAddressId: 'address-1',
    );
    SharedPreferences.setMockInitialValues({
      'auth_session': jsonEncode(_legacySessionJson()),
      'saved_jellyfin_servers': jsonEncode([server.toJson()]),
      'saved_jellyfin_server_sessions': jsonEncode({
        server.id: _legacySessionJson(),
      }),
      'active_jellyfin_server': server.id,
    });
    final store = ServerStore();

    final result = await store.bootstrap();
    final preferences = await SharedPreferences.getInstance();

    expect(result.migratedServerId, server.id);
    expect(result.active?.server.id, server.id);
    expect(preferences.getString('auth_session'), isNull);
  });

  test('keeps a legacy device-data migration pending until it completes',
      () async {
    SharedPreferences.setMockInitialValues({
      'auth_session': jsonEncode(_legacySessionJson()),
    });

    final initial = await ServerStore().bootstrap();
    final serverId = initial.migratedServerId;
    expect(serverId, isNotNull);

    final restarted = await ServerStore().bootstrap();
    expect(restarted.migratedServerId, serverId);

    await ServerStore().completeLegacyDataMigration(serverId!);
    final completed = await ServerStore().bootstrap();
    expect(completed.migratedServerId, isNull);
  });

  test('keeps access tokens separate from profile metadata and removes them',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = ServerStore();

    final saved = await store.addAuthenticatedServer(_legacySession);
    final preferences = await SharedPreferences.getInstance();
    final metadata = preferences.getString('saved_jellyfin_servers');
    final sessions = preferences.getString('saved_jellyfin_server_sessions');

    expect(metadata, isNot(contains(_legacySession.accessToken)));
    expect(sessions, contains(_legacySession.accessToken));

    await store.removeServer(saved.server.id);

    expect(preferences.getString('saved_jellyfin_server_sessions'), isNull);
    expect(await store.loadServers(), isEmpty);
  });

  test('address labels are persisted without changing the server identity',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = ServerStore();
    final saved = await store.addAuthenticatedServer(_legacySession);

    final updated = await store.addAddress(
      saved.server.id,
      name: 'Remote',
      url: 'music.example.com:8920',
    );

    expect(updated.single.id, saved.server.id);
    expect(updated.single.addresses, hasLength(2));
    expect(updated.single.addresses.last.name, 'Remote');
    expect(updated.single.addresses.last.url, 'https://music.example.com:8920');
  });

  test('reuses an existing profile when the same login signs in again',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = ServerStore();
    final first = await store.addAuthenticatedServer(_legacySession);
    const refreshedSession = AuthSession(
      accessToken: 'new-token',
      serverUrl: 'https://music.example.com',
      userId: 'user-1',
      userName: 'Jordan',
    );

    final second = await store.addAuthenticatedServer(refreshedSession);

    expect(second.server.id, first.server.id);
    expect(await store.loadServers(), hasLength(1));
    expect(second.session.accessToken, refreshedSession.accessToken);
  });

  test('restores a saved session and reuses it for an alias', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ServerStore();
    final saved = await store.addAuthenticatedServer(_legacySession);
    final servers = await store.addAddress(
      saved.server.id,
      name: 'Remote',
      url: 'https://remote.music.example.com',
    );
    final alias = servers.single.addresses.last;

    final restartedStore = ServerStore();
    final restored = await restartedStore.bootstrap();
    expect(restored.active?.session.accessToken, _legacySession.accessToken);
    expect(restored.active?.session.serverUrl, _legacySession.serverUrl);

    final aliased = await restartedStore.activate(
      saved.server.id,
      addressId: alias.id,
    );
    expect(aliased?.session.accessToken, _legacySession.accessToken);
    expect(aliased?.session.serverUrl, alias.url);
  });

  test('removing the active server selects another saved server', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ServerStore();
    final first = await store.addAuthenticatedServer(_legacySession);
    const secondSession = AuthSession(
      accessToken: 'remote-token',
      serverUrl: 'https://remote.example.com',
      userId: 'remote-user',
      userName: 'Remote User',
    );
    final second = await store.addAuthenticatedServer(secondSession);

    final next = await store.removeServer(second.server.id);

    expect(next?.server.id, first.server.id);
    expect(next?.session.accessToken, _legacySession.accessToken);
  });

  test('records server data cleanup until the app finishes removal', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ServerStore();
    final saved = await store.addAuthenticatedServer(_legacySession);

    await store.removeServer(saved.server.id);

    expect(await store.pendingServerRemovals(), [saved.server.id]);
    await store.completeServerRemoval(saved.server.id);
    expect(await store.pendingServerRemovals(), isEmpty);
  });

  test('finishes an interrupted server removal during bootstrap', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ServerStore();
    final saved = await store.addAuthenticatedServer(_legacySession);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      'pending_jellyfin_server_removals',
      [saved.server.id],
    );

    final restored = await ServerStore().bootstrap();

    expect(restored.servers, isEmpty);
    expect(restored.active, isNull);
    expect(preferences.getString('saved_jellyfin_server_sessions'), isNull);
    expect(await store.pendingServerRemovals(), [saved.server.id]);
  });

  test('keeps valid sessions when another saved session is malformed',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = ServerStore();
    final first = await store.addAuthenticatedServer(_legacySession);
    final second = await store.addAuthenticatedServer(
      const AuthSession(
        accessToken: 'remote-token',
        serverUrl: 'https://remote.example.com',
        userId: 'remote-user',
        userName: 'Remote User',
      ),
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'saved_jellyfin_server_sessions',
      jsonEncode({
        first.server.id: _legacySessionJson(),
        second.server.id: {'accessToken': 1},
      }),
    );

    final restored = await ServerStore().activate(first.server.id);

    expect(restored?.session.accessToken, _legacySession.accessToken);
  });

  test('the sidebar server switcher has a dynamic default and saved override',
      () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsStore();

    final defaults = await settings.loadSidebarVisibility();
    expect(defaults.containsKey(SidebarItem.servers), isFalse);

    await settings.saveSidebarVisibility({
      ...defaults,
      SidebarItem.servers: false,
    });
    final restored = await settings.loadSidebarVisibility();
    expect(restored[SidebarItem.servers], isFalse);
  });
}
