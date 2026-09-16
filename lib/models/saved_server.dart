/// A user-facing Jellyfin server profile without its secret token.
class SavedServer {
  /// Creates a server profile.
  const SavedServer({
    required this.id,
    required this.name,
    required this.userId,
    required this.userName,
    required this.addresses,
    required this.activeAddressId,
  });

  /// Stable local identifier used for credentials and cache scoping.
  final String id;

  /// Editable display name shown in Settings and the sidebar.
  final String name;

  /// Jellyfin user identifier associated with the saved token.
  final String userId;

  /// Jellyfin user name shown in the server list.
  final String userName;

  /// Reachable addresses for this Jellyfin server.
  final List<ServerAddress> addresses;

  /// The address used when this server is selected.
  final String activeAddressId;

  /// Currently selected address.
  ServerAddress get activeAddress => addresses.firstWhere(
        (address) => address.id == activeAddressId,
        orElse: () => addresses.first,
      );

  /// Returns a copy with selected fields replaced.
  SavedServer copyWith({
    String? name,
    List<ServerAddress>? addresses,
    String? activeAddressId,
  }) {
    return SavedServer(
      id: id,
      name: name ?? this.name,
      userId: userId,
      userName: userName,
      addresses: addresses ?? this.addresses,
      activeAddressId: activeAddressId ?? this.activeAddressId,
    );
  }

  /// Serializes non-secret server metadata.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'userId': userId,
        'userName': userName,
        'addresses': addresses.map((address) => address.toJson()).toList(),
        'activeAddressId': activeAddressId,
      };

  /// Restores non-secret server metadata.
  factory SavedServer.fromJson(Map<String, dynamic> json) {
    final addresses = (json['addresses'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((address) => ServerAddress.fromJson(
              Map<String, dynamic>.from(address),
            ))
        .toList();
    if (addresses.isEmpty) {
      throw const FormatException('Saved server has no addresses.');
    }
    final activeAddressId = json['activeAddressId'] as String?;
    return SavedServer(
      id: json['id'] as String,
      name: json['name'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      addresses: addresses,
      activeAddressId: addresses.any((address) => address.id == activeAddressId)
          ? activeAddressId!
          : addresses.first.id,
    );
  }
}

/// A labelled URL that reaches a saved Jellyfin server.
class ServerAddress {
  /// Creates a saved address.
  const ServerAddress({
    required this.id,
    required this.name,
    required this.url,
  });

  /// Stable local address identifier.
  final String id;

  /// Editable display name, such as "Home" or "Remote".
  final String name;

  /// Canonical Jellyfin base URL.
  final String url;

  /// Returns a copy with selected fields replaced.
  ServerAddress copyWith({String? name, String? url}) {
    return ServerAddress(id: id, name: name ?? this.name, url: url ?? this.url);
  }

  /// Serializes the address.
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'url': url};

  /// Restores an address.
  factory ServerAddress.fromJson(Map<String, dynamic> json) => ServerAddress(
        id: json['id'] as String,
        name: json['name'] as String,
        url: json['url'] as String,
      );
}
