import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';

/// Persists Jellyfin authentication state.
class SessionStore {
  /// Creates a session store.
  SessionStore();

  static const _sessionKey = 'auth_session';

  /// Loads a cached session, if available.
  Future<AuthSession?> loadSession() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_sessionKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Saves a session or clears it when null.
  Future<void> saveSession(AuthSession? session) async {
    final preferences = await SharedPreferences.getInstance();
    if (session == null) {
      await preferences.remove(_sessionKey);
      return;
    }
    await preferences.setString(_sessionKey, jsonEncode(session.toJson()));
  }
}
