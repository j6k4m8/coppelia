import 'dart:io';
import 'dart:async';

import 'package:dart_cast/dart_cast.dart' as dart_cast;
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../models/media_item.dart';

/// Google Cast integration for Android, iOS, and desktop platforms.
///
/// The default Cast receiver fetches the media URL itself, so callers must
/// provide a URL that is usable from the local network. Jellyfin URLs are
/// signed by [AppState] with the `api_key` query parameter before they reach
/// this service.
class ChromecastService {
  ChromecastService._();

  static final ChromecastService instance = ChromecastService._();

  static bool get isSupported =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isWindows ||
      Platform.isLinux;

  bool _initialized = false;
  dart_cast.CastService? _desktopService;
  dart_cast.CastSession? _desktopSession;
  final Set<dart_cast.CastSession> _desktopSessions = {};
  StreamController<List<ChromecastReceiver>>? _desktopController;
  List<ChromecastReceiver> _lastDevices = [];

  Future<void> initialize() async {
    if (!isSupported || _initialized) return;
    const appId = GoogleCastDiscoveryCriteria.kDefaultApplicationId;
    final options = Platform.isIOS
        ? IOSGoogleCastOptions(
            GoogleCastDiscoveryCriteriaInitialize.initWithApplicationID(appId),
          )
        : GoogleCastOptionsAndroid(appId: appId);
    await GoogleCastContext.instance.setSharedInstanceWithOptions(options);
    GoogleCastDiscoveryManager.instance.startDiscovery();
    _initialized = true;
  }

  Stream<List<ChromecastReceiver>> get devicesStream {
    if (_isDesktop) {
      return _getDesktopDevicesStream();
    }
    return GoogleCastDiscoveryManager.instance.devicesStream.map(
      (devices) => devices
          .map(
            (device) => ChromecastReceiver(
              id: device.deviceID,
              name: device.friendlyName,
              model: device.modelName,
              nativeDevice: device,
            ),
          )
          .toList(),
    );
  }

  GoogleCastConnectState get connectionState =>
      GoogleCastSessionManager.instance.connectionState;

  bool get isConnected => _isDesktop
      ? _desktopSession != null
      : connectionState == GoogleCastConnectState.connected;

  Stream<Duration>? get positionStream => _desktopSession?.positionStream;
  Stream<Duration>? get durationStream => _desktopSession?.durationStream;
  Stream<bool>? get playingStream => _desktopSession?.stateStream.map(
        (state) =>
            state == dart_cast.SessionState.playing ||
            state == dart_cast.SessionState.buffering,
      );
  Duration get remotePosition => _desktopSession?.position ?? Duration.zero;
  bool get remotePlaying =>
      _desktopSession?.state == dart_cast.SessionState.playing ||
      _desktopSession?.state == dart_cast.SessionState.buffering;

  Future<void> connect(ChromecastReceiver receiver) async {
    if (_isDesktop) {
      final service = _desktopService;
      final device = receiver.desktopDevice;
      if (service == null || device == null) {
        throw StateError('Chromecast discovery has not started.');
      }
      try {
        _desktopSession = await service.connect(device);
      } catch (_) {
        _desktopSession = null;
        await _closeDesktopSessions();
        rethrow;
      }
      return;
    }
    await initialize();
    await GoogleCastSessionManager.instance.startSessionWithDevice(
      receiver.nativeDevice!,
    );
  }

  Future<void> cast(
    MediaItem item, {
    String? streamUrl,
    String? localFilePath,
    Map<String, String>? httpHeaders,
    Duration startPosition = Duration.zero,
    bool autoPlay = true,
  }) async {
    if (!isSupported) {
      throw UnsupportedError(
        'Chromecast is available on Android, iOS, Windows, macOS, and Linux.',
      );
    }
    if (_isDesktop) {
      final session = _desktopSession;
      if (session == null) {
        throw StateError('Connect to a Chromecast receiver first.');
      }
      final media = localFilePath == null
          ? dart_cast.CastMedia(
              url: streamUrl ?? (throw StateError('A stream URL is required.')),
              type: dart_cast.CastMediaType.hls,
              httpHeaders: httpHeaders ?? const {},
              title: item.title,
              imageUrl: item.imageUrl,
              startPosition: startPosition,
              autoPlay: autoPlay,
              duration: item.duration,
            )
          : dart_cast.CastMedia.file(
              filePath: localFilePath,
              type: dart_cast.CastMediaType.audio,
              title: item.title,
              imageUrl: item.imageUrl,
              startPosition: startPosition,
              autoPlay: autoPlay,
              duration: item.duration,
              fileExtension: _fileExtension(localFilePath),
              contentType: _audioContentType(localFilePath, item),
            );
      await session.loadMedia(
        media,
      );
      return;
    }
    await initialize();
    if (streamUrl == null) {
      throw StateError('A remote stream URL is required on mobile Cast.');
    }
    if (!isConnected) {
      throw StateError('Connect to a Chromecast receiver first.');
    }

    final media = GoogleCastMediaInformation(
      contentId: item.id,
      streamType: CastMediaStreamType.buffered,
      contentUrl: Uri.parse(streamUrl),
      contentType: _contentType(item),
      duration: item.duration,
      metadata: GoogleCastMusicMediaMetadata(
        title: item.title,
        albumName: item.album,
        artist: item.artists.join(', '),
        albumArtist: item.artists.join(', '),
        images: item.imageUrl == null
            ? null
            : [
                GoogleCastImage(
                  url: Uri.parse(item.imageUrl!),
                  height: 512,
                  width: 512,
                ),
              ],
      ),
    );
    await GoogleCastRemoteMediaClient.instance.loadMedia(
      media,
      autoPlay: autoPlay,
      playPosition: startPosition,
    );
  }

  Future<void> pause() => _isDesktop
      ? _desktopSession!.pause()
      : GoogleCastRemoteMediaClient.instance.pause();

  Future<void> play() => _isDesktop
      ? _desktopSession!.play()
      : GoogleCastRemoteMediaClient.instance.play();

  Future<void> stop() => _isDesktop
      ? _desktopSession!.stop()
      : GoogleCastRemoteMediaClient.instance.stop();

  Future<void> seek(Duration position) => _isDesktop
      ? _desktopSession!.seek(position)
      : GoogleCastRemoteMediaClient.instance.seek(
          GoogleCastMediaSeekOption(position: position),
        );

  Future<void> disconnect() async {
    if (_isDesktop) {
      await _desktopSession?.disconnect();
      _desktopSession = null;
      await _closeDesktopSessions();
      return;
    }
    // Ending a Cast session does not necessarily stop the media receiver.
    // Stop the active media session explicitly before closing the sender
    // connection so playback cannot continue after disconnecting.
    try {
      await GoogleCastRemoteMediaClient.instance.stop();
    } catch (_) {
      // There may be no active media session; ending the Cast session is still
      // the correct cleanup operation.
    }
    await GoogleCastSessionManager.instance.endSessionAndStopCasting();
  }

  Stream<List<ChromecastReceiver>> _getDesktopDevicesStream() {
    _desktopController ??= StreamController<List<ChromecastReceiver>>.broadcast(
      onListen: () {
        if (_desktopService != null) {
          // Discovery is already running. Emit the cached state so the
          // new subscriber doesn't have to wait for the next pulse.
          if (_lastDevices.isNotEmpty) {
            _desktopController?.add(_lastDevices);
          }
          return;
        }
        _desktopService = dart_cast.CastService(
          discoveryProviders: [
            dart_cast.ChromecastDiscoveryProvider(),
          ],
          sessionFactory: (device) {
            final session = dart_cast.ChromecastSession(device: device);
            _desktopSessions.add(session);
            return session;
          },
        );
        _desktopService!
            .startDiscovery(
          timeout: const Duration(hours: 24),
        )
            .listen(
          (devices) {
            _lastDevices = devices
                .map(
                  (device) => ChromecastReceiver(
                    id: device.id,
                    name: device.name,
                    model: 'Chromecast',
                    desktopDevice: device,
                  ),
                )
                .toList();
            _desktopController?.add(_lastDevices);
          },
          onError: _desktopController!.addError,
        );
      },
    );
    return _desktopController!.stream;
  }

  Future<void> _closeDesktopSessions() async {
    final sessions = _desktopSessions.toList();
    _desktopSessions.clear();
    for (final session in sessions) {
      try {
        await session.disconnect();
      } catch (_) {
        // Best effort cleanup after failed or completed Cast sessions.
      }
    }
  }

  bool get _isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  String _contentType(MediaItem item) {
    final codec = (item.codec ?? item.container ?? '').toLowerCase();
    if (codec.contains('flac')) return 'audio/flac';
    if (codec.contains('aac') || codec.contains('m4a')) return 'audio/aac';
    if (codec.contains('wav')) return 'audio/wav';
    if (codec.contains('ogg') || codec.contains('opus')) return 'audio/ogg';
    return 'audio/mpeg';
  }

  String _fileExtension(String path) {
    final dot = path.lastIndexOf('.');
    return dot == -1 ? 'mp3' : path.substring(dot + 1).toLowerCase();
  }

  String _audioContentType(String path, MediaItem item) {
    final value =
        '${item.codec ?? ''} ${item.container ?? ''} ${path.toLowerCase()}';
    if (value.contains('flac')) return 'audio/flac';
    if (value.contains('aac') || value.contains('m4a')) return 'audio/aac';
    if (value.contains('wav')) return 'audio/wav';
    if (value.contains('ogg') || value.contains('opus')) return 'audio/ogg';
    return 'audio/mpeg';
  }
}

/// Platform-neutral receiver model used by the picker UI.
class ChromecastReceiver {
  const ChromecastReceiver({
    required this.id,
    required this.name,
    this.model,
    this.nativeDevice,
    this.desktopDevice,
  });

  final String id;
  final String name;
  final String? model;
  final GoogleCastDevice? nativeDevice;
  final dart_cast.CastDevice? desktopDevice;
}
