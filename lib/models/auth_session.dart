/// Authentication state for a Jellyfin session.
class AuthSession {
  /// Creates an authenticated session snapshot.
  const AuthSession({
    required this.accessToken,
    required this.serverUrl,
    required this.userId,
    required this.userName,
  });

  /// Active API access token.
  final String accessToken;

  /// Jellyfin server base URL.
  final String serverUrl;

  /// Jellyfin user identifier.
  final String userId;

  /// Displayable user name.
  final String userName;

  /// Restores a persisted session.
  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        accessToken: json['accessToken'] as String,
        serverUrl: json['serverUrl'] as String,
        userId: json['userId'] as String,
        userName: json['userName'] as String,
      );

  /// Serializes the session for local persistence.
  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'serverUrl': serverUrl,
        'userId': userId,
        'userName': userName,
      };
}
