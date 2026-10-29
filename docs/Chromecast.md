# Chromecast

Coppelia supports Chromecast audio casting on Android, iOS, macOS, Linux, and
Windows.

## Desktop implementation

Desktop platforms use the vendored `dart_cast` package for:

- `_googlecast._tcp` mDNS discovery
- CASTV2 TLS/protobuf transport
- Receiver control and media status updates
- The local HTTP media proxy

macOS, Linux, and Windows therefore use the same Dart implementation. The
operating system firewall must allow Coppelia to send multicast discovery
traffic and accept HTTP connections from the Chromecast receiver.

## Media sources

When a cached local audio file is available, Coppelia serves it from its local
HTTP proxy. The receiver never receives a local filesystem path. The proxy
binds to the desktop machine's LAN address and provides a tokenized URL.

For remote Jellyfin media, Coppelia requests an AAC HLS stream and the proxy
forwards the playlist and segments. The Chromecast must be able to reach the
desktop machine's LAN address.

## Playback handoff

- Playing, paused, and stopped tracks can be transferred.
- The current position is included in the Cast `LOAD` request.
- While casting, receiver position/state updates drive the player UI.
- Seek, play/pause, next, previous, and queue selection control the receiver.
- Disconnecting restores the current track, position, and play/pause state to
  the local player.

## Troubleshooting

If receivers are not found, verify that the desktop and Chromecast are on the
same network and that multicast DNS is not blocked by a guest-network or VLAN
policy. If a receiver is found but playback fails, verify that it can reach
the desktop proxy URL and that the desktop firewall permits inbound traffic.
