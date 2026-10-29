/// ChromecastSession — full lifecycle management for Chromecast casting.
///
/// Extends [CastSession] to manage TLS connection, receiver/media channels,
/// heartbeat keep-alive, media proxy, and playback state synchronisation.
library;

import 'dart:async';
import 'dart:convert';

import '../../core/cast_device.dart';
import '../../core/cast_exceptions.dart';
import '../../core/cast_media.dart';
import '../../core/cast_session.dart';
import '../../core/media_proxy.dart';
import '../../core/media_transformer.dart';
import '../../core/ts_hls_media_transformer.dart';
import '../../utils/logger.dart';
import 'cast_media_channel.dart';
import 'cast_receiver_channel.dart';
import 'castv2_channel.dart';
import 'proto/cast_channel.dart';

/// Strategy used for a single LOAD attempt against the Chromecast.
///
/// Iterated by [ChromecastSession._loadMediaInternal] as a bisect-style
/// retry — the leanest variant is tried first so we can see whether the
/// experimental transforms (alt-audio muxer, DVB-table stripper) are
/// actually needed for a given source.
enum _LoadMode {
  /// `registerMedia` pass-through with DVB stripper disabled and no
  /// alt-audio muxer. This is the leanest variant.
  bare('bare (no muxer, no DVB stripper)'),

  /// `registerAltAudioMuxed` (with `registerMedia` fallback if the
  /// source has no alt-audio) and the DVB stripper enabled on TS
  /// segments. This is the previous default.
  muxed('muxed alt-audio + DVB stripper');

  const _LoadMode(this.label);
  final String label;
}

/// A casting session with a Chromecast device.
///
/// Manages the full lifecycle: TLS connect, receiver LAUNCH, heartbeat,
/// media LOAD/PLAY/PAUSE/STOP/SEEK, and graceful disconnect.
class ChromecastSession extends CastSession {
  /// The sender ID used in all messages.
  static const _senderId = 'sender-0';

  /// The platform receiver destination ID.
  static const _receiverId = 'receiver-0';

  // ---------------------------------------------------------------------------
  // Dependencies (injectable for testing)
  // ---------------------------------------------------------------------------

  final _ChannelAdapter _channel;
  final MediaProxy _proxy;
  final MediaTransformer _mediaTransformer;

  // ---------------------------------------------------------------------------
  // Session state
  // ---------------------------------------------------------------------------

  final CastReceiverChannel _receiverChannel = CastReceiverChannel();
  final CastMediaChannel _mediaChannel = CastMediaChannel();

  String? _transportId;
  String? _sessionId; // Used for STOP app via receiver namespace.
  int? _mediaSessionId;
  StreamSubscription<dynamic>? _mediaStatusSubscription;

  /// Periodic timer that polls GET_STATUS on the media channel to keep
  /// the playback position up-to-date. Chromecast only pushes MEDIA_STATUS
  /// on state changes (play, pause, load) — it does NOT send periodic
  /// position updates on its own.
  Timer? _positionPollTimer;

  /// Guard to prevent overlapping GET_STATUS requests.
  bool _isPolling = false;

  /// Guard to prevent concurrent [loadMedia] calls from sending multiple LOADs.
  bool _isLoadingMedia = false;

  /// Tracks the trackId assigned to each subtitle during the current
  /// LOAD, keyed by the subtitle's upstream URL. `setSubtitle` looks up
  /// the active subtitle here to send the correct `EDIT_TRACKS_INFO`
  /// trackId — without this we'd always activate trackId=1, so any
  /// subtitle switch in the UI after LOAD would silently re-select
  /// the first subtitle on the TV.
  final Map<String, int> _subtitleTrackIds = <String, int>{};

  /// The track ids currently meant to be active on the receiver.
  ///
  /// Seeded at LOAD from [CastMedia.defaultSubtitle] and rewritten by
  /// [setSubtitle]. This is the sender's record, deliberately not mirrored
  /// from MEDIA_STATUS: the receiver never changes tracks on its own, and
  /// [_reassertActiveTracks] needs the *intended* set even at the moment
  /// the receiver has stopped honouring it.
  List<int> _activeTrackIds = const [];

  /// MediaSession IDs we've explicitly abandoned during a retry chain.
  ///
  /// When the bisect loop falls through from one attempt to the next, the
  /// failed attempt's receiver-side session is now stale — any late
  /// MEDIA_STATUS broadcasts still carrying its session id (commonly the
  /// IDLE+ERROR settle-down message arriving a few hundred ms after
  /// LOAD_FAILED) would otherwise be processed by [_handleMessage] and
  /// drag the state machine backwards while the new attempt is mid-flight.
  /// Recording the abandoned session id here lets [_handleMessage] drop
  /// those late strays without affecting the live session.
  final Set<int> _deprecatedMediaSessionIds = <int>{};

  /// When `true`, [connect] additionally subscribes to the Default Media
  /// Receiver's auxiliary debug namespaces (`com.google.cast.cac` +
  /// `com.google.cast.debugoverlay`) and the receiver-message firehose
  /// is logged at info level instead of debug.
  ///
  /// Off by default — these subscribes add a couple of extra CONNECT
  /// messages on every cast session and the firehose can be very loud
  /// during playback (every MEDIA_STATUS, every queue update, …). Flip
  /// it on when debugging LOAD_FAILED or unexpected receiver behaviour;
  /// leave it off in normal use.
  final bool enableReceiverDebugNamespaces;

  /// The current receiver session ID, if connected.
  String? get sessionId => _sessionId;
  Timer? _heartbeatTimer;
  StreamSubscription<dynamic>? _messageSubscription;

  /// Whether the heartbeat timer is currently active.
  bool get isHeartbeatActive => _heartbeatTimer?.isActive ?? false;

  /// Whether the position polling timer is currently active.
  bool get isPositionPollingActive => _positionPollTimer?.isActive ?? false;

  // ---------------------------------------------------------------------------
  // Constructors
  // ---------------------------------------------------------------------------

  /// Creates a [ChromecastSession] for the given [device].
  ///
  /// An optional [mediaTransformer] can be provided to customize how media
  /// is prepared before casting (e.g., custom segmentation, transcoding).
  /// Defaults to [TsHlsMediaTransformer] which wraps TS in HLS.
  ChromecastSession({
    required CastDevice device,
    MediaTransformer? mediaTransformer,
    this.enableReceiverDebugNamespaces = false,
  }) : _channel = _RealChannelAdapter(),
       _proxy = MediaProxy(),
       _mediaTransformer =
           mediaTransformer ?? const TsHlsMediaTransformer(wrapRemoteTs: true),
       super(device);

  /// Creates a [ChromecastSession] with mock dependencies for testing.
  ///
  /// [channel] is a mock for the TLS channel (required for unit/integration
  /// tests that avoid real TLS connections).
  /// [proxy] is an optional [MediaProxy] instance; a real [MediaProxy] is
  /// created if not provided.
  /// [mediaTransformer] is an optional transformer; defaults to
  /// [TsHlsMediaTransformer].
  ChromecastSession.withMocks({
    required CastDevice device,
    required dynamic channel,
    MediaProxy? proxy,
    MediaTransformer? mediaTransformer,
    this.enableReceiverDebugNamespaces = false,
  }) : _channel = _MockChannelAdapter(channel),
       _proxy = proxy ?? MediaProxy(),
       _mediaTransformer =
           mediaTransformer ?? const TsHlsMediaTransformer(wrapRemoteTs: true),
       super(device);

  // ---------------------------------------------------------------------------
  // Connect lifecycle
  // ---------------------------------------------------------------------------

  /// Connects to the Chromecast device and launches the Default Media Receiver.
  ///
  /// Sequence: TLS connect -> CONNECT to receiver-0 -> start heartbeat ->
  /// LAUNCH CC1AD845 -> wait for RECEIVER_STATUS -> extract transportId ->
  /// CONNECT to transportId.
  @override
  Future<void> connect() async {
    CastLogger.info(
      'Chromecast: connecting to ${device.name} at ${device.address.address}:${device.port}',
    );
    stateMachine.transitionTo(SessionState.connecting);

    // 1. TLS connect
    await _channel.connect(device.address.address, port: device.port);

    // 2. Start listening for messages
    final completer = Completer<void>();
    _messageSubscription = _channel.messageStream.listen(
      (msg) {
        _handleMessage(msg, completer);
      },
      onError: (Object error) {
        CastLogger.error('Chromecast: message stream error: $error');
        _onSocketLost();
      },
      onDone: () {
        CastLogger.warning('Chromecast: message stream closed unexpectedly');
        _onSocketLost();
      },
    );

    // 3. CONNECT to receiver-0
    _channel.sendMessage(
      namespace: CastReceiverChannel.connectionNamespace,
      sourceId: _senderId,
      destinationId: _receiverId,
      payload: CastReceiverChannel.buildConnect(),
    );

    // 4. Start heartbeat
    _startHeartbeat();

    // 5. LAUNCH Default Media Receiver
    _channel.sendMessage(
      namespace: CastReceiverChannel.receiverNamespace,
      sourceId: _senderId,
      destinationId: _receiverId,
      payload: _receiverChannel.buildLaunchWithId(),
    );

    // 6. Wait for RECEIVER_STATUS with transportId
    await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        CastLogger.error('Chromecast: connect timed out after 15s');
        stateMachine.transitionTo(SessionState.disconnected);
        throw TimeoutException('Chromecast connect timed out after 15 seconds');
      },
    );

    // 7. CONNECT to app transportId
    _channel.sendMessage(
      namespace: CastReceiverChannel.connectionNamespace,
      sourceId: _senderId,
      destinationId: _transportId!,
      payload: CastReceiverChannel.buildConnect(),
    );

    // 8. Opt-in: subscribe to receiver debug + CaC namespaces so any
    //    receiver-side LOAD_FAILED diagnostic surfaces in our message
    //    firehose (same data CaC Tool would render). Off by default —
    //    enable via [enableReceiverDebugNamespaces] when debugging.
    if (enableReceiverDebugNamespaces) {
      _subscribeReceiverDebugNamespaces();
    }

    CastLogger.info(
      'Chromecast: connected to ${device.name}, transportId=$_transportId',
    );
    stateMachine.transitionTo(SessionState.connected);
  }

  /// Subscribes (CONNECT) to the Default Media Receiver's auxiliary
  /// namespaces `urn:x-cast:com.google.cast.cac` and
  /// `urn:x-cast:com.google.cast.debugoverlay` so any messages the
  /// receiver chooses to publish there land in our message firehose.
  ///
  /// Cast V2 requires a sender to send a `CONNECT` on each namespace
  /// before the receiver routes traffic on it — otherwise events are
  /// silently dropped. The CONNECTs are cheap and harmless even when
  /// the receiver never emits on these namespaces; their value is the
  /// odd diagnostic line that does show up.
  void _subscribeReceiverDebugNamespaces() {
    if (_transportId == null) return;
    for (final ns in const [
      CastReceiverChannel.cacNamespace,
      CastReceiverChannel.debugOverlayNamespace,
    ]) {
      try {
        _channel.sendMessage(
          namespace: ns,
          sourceId: _senderId,
          destinationId: _transportId!,
          payload: CastReceiverChannel.buildConnect(),
        );
      } catch (_) {
        // Best-effort — failures here never block playback.
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Media loading
  // ---------------------------------------------------------------------------

  @override
  Future<void> loadMedia(CastMedia media) async {
    if (_transportId == null) {
      throw StateError('Not connected. Call connect() first.');
    }

    if (_isLoadingMedia) {
      CastLogger.warning(
        'Chromecast: loadMedia called while already loading — ignoring',
      );
      return;
    }
    _isLoadingMedia = true;

    try {
      await _loadMediaInternal(media);
    } finally {
      _isLoadingMedia = false;
    }
  }

  Future<void> _loadMediaInternal(CastMedia media) async {
    stateMachine.transitionTo(SessionState.loading);

    // Reset the deprecated-session tracker for this fresh LOAD. Anything
    // we accumulate during this load's retry chain is only relevant for
    // the duration of this load — the previous load's failed-attempt ids
    // don't matter anymore.
    _deprecatedMediaSessionIds.clear();

    // Start proxy
    await _proxy.start(targetDeviceIp: device.address.address);

    final isRemoteHls = media.type == CastMediaType.hls && !media.isLocalFile;

    // Non-HLS / local media — single attempt, no bisect needed.
    if (!isRemoteHls) {
      final transformed = await _mediaTransformer.transform(media, _proxy);
      await _attemptLoad(
        media: media,
        proxyUrl: transformed.proxyUrl,
        effectiveType: transformed.effectiveType,
        attemptLabel: 'standard',
      );
      return;
    }

    // Remote HLS — bisect via a two-attempt retry loop:
    //   attempt 1 (BARE) — registerMedia with the DVB-table stripper
    //     and alt-audio muxer both disabled. Pure pass-through. If the
    //     source plays fine, the experimental code is dead weight.
    //   attempt 2 (MUXED) — alt-audio muxer + DVB stripper enabled.
    //     This is the previous default; kept as the fallback for
    //     sources that genuinely need either piece.
    //
    // The retry triggers only on MediaLoadFailedException (LOAD_FAILED
    // or 15s timeout). Anything else propagates immediately.
    Object? lastError;
    StackTrace? lastStack;
    for (final mode in const [_LoadMode.bare, _LoadMode.muxed]) {
      // After a failed attempt the receiver may have flipped us to
      // IDLE — get back into LOADING so the next attempt's transitions
      // are valid (idle → loading is allowed; loading → loading is a
      // no-op the state machine ignores).
      if (stateMachine.state != SessionState.loading &&
          stateMachine.canTransitionTo(SessionState.loading)) {
        stateMachine.transitionTo(SessionState.loading);
      }
      try {
        await _attemptHlsLoad(media, mode);
        return;
      } on MediaLoadFailedException catch (e, st) {
        lastError = e;
        lastStack = st;
        CastLogger.warning(
          'Chromecast: LOAD attempt "${mode.label}" failed: $e — '
          'trying next mode',
        );
        // Mark the failed attempt's session id as deprecated so any
        // late MEDIA_STATUS messages still carrying it (notably the
        // IDLE+ERROR broadcast that follows LOAD_FAILED by a few
        // hundred ms) don't pull the state machine back to idle while
        // the next attempt is mid-flight.
        if (_mediaSessionId != null) {
          _deprecatedMediaSessionIds.add(_mediaSessionId!);
          CastLogger.debug(
            'Chromecast: deprecating mediaSessionId=${_mediaSessionId!} '
            'after failed attempt "${mode.label}"',
          );
        }
      }
    }
    if (stateMachine.canTransitionTo(SessionState.idle)) {
      stateMachine.transitionTo(SessionState.idle);
    }
    Error.throwWithStackTrace(lastError!, lastStack!);
  }

  Future<void> _attemptHlsLoad(CastMedia media, _LoadMode mode) async {
    String proxyUrl;
    switch (mode) {
      case _LoadMode.bare:
        proxyUrl = _proxy.registerMedia(
          media.url,
          headers: media.httpHeaders,
          pathExtension: 'm3u8',
          stripDvbTables: false,
        );
        CastLogger.info(
          'Chromecast: LOAD attempt BARE — no muxer, no DVB stripper, '
          'pure pass-through (url=$proxyUrl)',
        );
        break;
      case _LoadMode.muxed:
        final muxedUrl = await _proxy.registerAltAudioMuxed(
          masterUrl: media.url,
          headers: media.httpHeaders,
        );
        if (muxedUrl != null) {
          proxyUrl = muxedUrl;
          CastLogger.info(
            'Chromecast: LOAD attempt MUXED — alt-audio muxer + DVB '
            'stripper enabled (url=$proxyUrl)',
          );
        } else {
          // Source isn't alt-audio — fall back to standard registerMedia
          // but keep the DVB stripper on (still part of "muxed mode").
          proxyUrl = _proxy.registerMedia(
            media.url,
            headers: media.httpHeaders,
            pathExtension: 'm3u8',
          );
          CastLogger.info(
            'Chromecast: LOAD attempt MUXED — source has no alt-audio; '
            'using standard pass-through with DVB stripper '
            '(url=$proxyUrl)',
          );
        }
        break;
    }

    await _attemptLoad(
      media: media,
      proxyUrl: proxyUrl,
      effectiveType: CastMediaType.hls,
      attemptLabel: mode.label,
    );
  }

  Future<void> _attemptLoad({
    required CastMedia media,
    required String proxyUrl,
    required CastMediaType effectiveType,
    required String attemptLabel,
  }) async {
    // Extract token to keep across cleanup. The token is consistently
    // the second path segment regardless of route shape:
    //   /stream/<token>                 → segments[1] = "<token>"
    //   /stream/<token>/resource.vtt    → segments[1] = "<token>"
    //   /ts-stream/<token>              → segments[1] = "<token>"
    //   /alt-audio/<token>/master.m3u8  → segments[1] = "<token>"
    //   /file/<token>.ext               → segments[1] = "<token>.ext"
    final urlSegments = Uri.parse(proxyUrl).pathSegments;
    final newToken =
        urlSegments.length >= 2 ? urlSegments[1] : urlSegments.last;
    _proxy.cleanupPreviousMedia(excludeToken: newToken);

    final contentType =
        media.contentType ?? _contentTypeForMedia(effectiveType);

    CastLogger.info(
      'Chromecast: loading ${media.subtitles.length} subtitle track(s)',
    );
    final subtitles = <CastMediaTrack>[];
    _subtitleTrackIds.clear();
    for (var i = 0; i < media.subtitles.length; i++) {
      final sub = media.subtitles[i];
      final proxySubUrl = _proxy.registerSubtitle(
        sub.url,
        headers: media.httpHeaders,
      );
      final trackId = i + 1;
      _subtitleTrackIds[sub.url] = trackId;
      subtitles.add(
        CastMediaTrack(
          trackId: trackId,
          url: proxySubUrl,
          name: sub.label,
          language: sub.language,
        ),
      );
    }

    // Resolve which track starts active. No default = no subtitle shown;
    // activating subtitles[0] here is exactly the bug this replaces (the
    // track-list order chose the language on the TV).
    int? defaultTrackId;
    if (media.defaultSubtitle != null) {
      defaultTrackId = _subtitleTrackIds[media.defaultSubtitle!.url];
      if (defaultTrackId == null) {
        CastLogger.warning(
          'Chromecast: defaultSubtitle url is not in the subtitle list — '
          'starting with no active track. '
          'url=${media.defaultSubtitle!.url}',
        );
      }
    }
    _activeTrackIds = defaultTrackId != null ? [defaultTrackId] : const [];

    final loadPayload = _mediaChannel.buildLoad(
      contentId: proxyUrl,
      contentType: contentType,
      title: media.title,
      imageUrl: media.imageUrl,
      startPosition:
          media.startPosition != null
              ? media.startPosition!.inMilliseconds / 1000.0
              : null,
      autoPlay: media.autoPlay,
      subtitles: subtitles.isNotEmpty ? subtitles : null,
      activeTrackIds: defaultTrackId != null ? [defaultTrackId] : null,
    );

    final loadRequestId =
        (jsonDecode(loadPayload) as Map<String, dynamic>)['requestId'] as int;

    CastLogger.info(
      'Chromecast: LOAD contentId=$proxyUrl contentType=$contentType '
      'requestId=$loadRequestId',
    );
    CastLogger.debug(
      'Chromecast: LOAD details — '
      'attempt=$attemptLabel, '
      'subtitleTracks=${subtitles.length}, '
      'hasMetadata=${media.title != null}, '
      'hasImageUrl=${media.imageUrl != null}, '
      'startPosition=${media.startPosition?.inMilliseconds ?? 0}ms, '
      'originalMediaType=${media.type.name}, '
      'effectiveType=${effectiveType.name}',
    );
    CastLogger.debug('Chromecast: LOAD payload = $loadPayload');

    final priorMediaSessionId = _mediaSessionId;

    final completer = Completer<void>();
    _waitForMediaStatus(
      completer,
      expectedRequestId: loadRequestId,
      priorMediaSessionId: priorMediaSessionId,
    );

    final loadSentAt = DateTime.now();
    _channel.sendMessage(
      namespace: CastMediaChannel.mediaNamespace,
      sourceId: _senderId,
      destinationId: _transportId!,
      payload: loadPayload,
    );

    try {
      await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          final elapsed = DateTime.now().difference(loadSentAt);
          CastLogger.error(
            'Chromecast: loadMedia timed out after ${elapsed.inMilliseconds}ms '
            '(no playable MEDIA_STATUS received from receiver, '
            'attempt=$attemptLabel)',
          );
          _mediaStatusSubscription?.cancel();
          _mediaStatusSubscription = null;
          throw MediaLoadFailedException(
            'Chromecast loadMedia timed out after 15 seconds — '
            'receiver never reported a playable state (attempt=$attemptLabel)',
          );
        },
      );
      final elapsed = DateTime.now().difference(loadSentAt);
      CastLogger.info(
        'Chromecast: LOAD acknowledged + playable in '
        '${elapsed.inMilliseconds}ms (attempt=$attemptLabel)',
      );
    } on MediaLoadFailedException {
      // Let the bisect loop decide whether to retry — only flip to
      // `idle` once we run out of attempts.
      rethrow;
    } catch (e) {
      if (stateMachine.canTransitionTo(SessionState.idle)) {
        stateMachine.transitionTo(SessionState.idle);
      }
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Playback controls
  // ---------------------------------------------------------------------------

  @override
  Future<void> play() async {
    _requireMediaSession();
    CastLogger.info('Chromecast: PLAY');
    _sendMediaCommand(_mediaChannel.buildPlay(_mediaSessionId!));
  }

  @override
  Future<void> pause() async {
    _requireMediaSession();
    CastLogger.info('Chromecast: PAUSE');
    _sendMediaCommand(_mediaChannel.buildPause(_mediaSessionId!));
  }

  @override
  Future<void> stop() async {
    _requireMediaSession();
    CastLogger.info('Chromecast: STOP');
    _stopPositionPolling();
    _sendMediaCommand(_mediaChannel.buildStop(_mediaSessionId!));
  }

  @override
  Future<void> seek(Duration position) async {
    _requireMediaSession();
    final seconds = position.inMilliseconds / 1000.0;
    CastLogger.info(
      'Chromecast: SEEK to ${seconds.toStringAsFixed(1)}s '
      '(${position.inMinutes}:${(position.inSeconds % 60).toString().padLeft(2, '0')})',
    );
    _sendMediaCommand(_mediaChannel.buildSeek(_mediaSessionId!, seconds));
  }

  @override
  Future<void> setVolume(double volume) async {
    _requireMediaSession();
    CastLogger.info('Chromecast: SET_VOLUME ${volume.toStringAsFixed(2)}');
    // Device-level volume uses receiver namespace to receiver-0.
    // The device responds with RECEIVER_STATUS containing the actual volume,
    // which is handled in _handleMessage() to update the volume stream.
    _channel.sendMessage(
      namespace: CastReceiverChannel.receiverNamespace,
      sourceId: _senderId,
      destinationId: _receiverId,
      payload: _receiverChannel.buildSetVolumeWithId(level: volume),
    );
  }

  @override
  Future<void> setSubtitle(CastSubtitle? subtitle) async {
    _requireMediaSession();
    if (subtitle == null) {
      CastLogger.info('Chromecast: EDIT_TRACKS_INFO disable subtitles');
      _activeTrackIds = const [];
      _sendMediaCommand(
        _mediaChannel.buildEditTracksInfo(_mediaSessionId!, []),
      );
      return;
    }

    // Look up the trackId assigned at LOAD time. Without this map we'd
    // always activate trackId=1, so switching subtitles from the UI
    // would silently re-select the first track on the TV.
    final trackId = _subtitleTrackIds[subtitle.url];
    if (trackId == null) {
      CastLogger.warning(
        'Chromecast: setSubtitle called with subtitle whose URL is not '
        'in the loaded track list — falling back to trackId=1. '
        'url=${subtitle.url}, '
        'known=${_subtitleTrackIds.keys.take(4).join(", ")}'
        '${_subtitleTrackIds.length > 4 ? ", …" : ""}',
      );
      _activeTrackIds = const [1];
      _sendMediaCommand(
        _mediaChannel.buildEditTracksInfo(_mediaSessionId!, [1]),
      );
      return;
    }
    CastLogger.info(
      'Chromecast: EDIT_TRACKS_INFO activate trackId=$trackId '
      '(label="${subtitle.label}", lang=${subtitle.language})',
    );
    _activeTrackIds = [trackId];
    _sendMediaCommand(
      _mediaChannel.buildEditTracksInfo(_mediaSessionId!, [trackId]),
    );
  }

  /// Re-applies [_activeTrackIds] after a pause → resume transition.
  ///
  /// The Default Media Receiver can stop *rendering* subtitle cues after a
  /// pause/resume cycle (TV-remote pause included) while MEDIA_STATUS keeps
  /// reporting the track as active — so the sender's state looks perfectly
  /// healthy while the screen shows nothing. Changing the active track via
  /// EDIT_TRACKS_INFO re-attaches the cue renderer, which is exactly how
  /// users fix it by hand. A plain re-send of the same set risks being
  /// diffed away as a no-op, so this toggles: deactivate, then reactivate.
  /// Cues are fetched once at LOAD and cached receiver-side — the toggle
  /// costs two small messages, no network.
  void _reassertActiveTracks() {
    final sessionId = _mediaSessionId;
    if (sessionId == null || _activeTrackIds.isEmpty) return;
    CastLogger.info(
      'Chromecast: re-asserting active tracks $_activeTrackIds after resume',
    );
    _sendMediaCommand(_mediaChannel.buildEditTracksInfo(sessionId, []));
    _sendMediaCommand(
      _mediaChannel.buildEditTracksInfo(sessionId, _activeTrackIds),
    );
  }

  // ---------------------------------------------------------------------------
  // Disconnect
  // ---------------------------------------------------------------------------

  @override
  Future<void> disconnect() async {
    CastLogger.info('Chromecast: disconnecting from ${device.name}');

    // Closing the Cast transport alone leaves the Default Media Receiver
    // playing. Stop the media session first, while the media transport is
    // still available, then close the app and sender channels below.
    try {
      if (_mediaSessionId != null && _transportId != null) {
        CastLogger.info('Chromecast: STOP before disconnect');
        _sendMediaCommand(_mediaChannel.buildStop(_mediaSessionId!));
      }
    } catch (e) {
      CastLogger.warning('Chromecast: failed to stop before disconnect: $e');
    }
    _stopHeartbeat();
    _stopPositionPolling();
    _mediaStatusSubscription?.cancel();
    _mediaStatusSubscription = null;

    // Send CLOSE messages (fire-and-forget — don't wait for response)
    try {
      if (_transportId != null) {
        _channel.sendMessage(
          namespace: CastReceiverChannel.connectionNamespace,
          sourceId: _senderId,
          destinationId: _transportId!,
          payload: CastReceiverChannel.buildClose(),
        );
      }
      _channel.sendMessage(
        namespace: CastReceiverChannel.connectionNamespace,
        sourceId: _senderId,
        destinationId: _receiverId,
        payload: CastReceiverChannel.buildClose(),
      );
    } catch (e) {
      CastLogger.warning('Chromecast: error sending CLOSE messages: $e');
    }

    // Transition state immediately so the UI responds
    _transportId = null;
    _sessionId = null;
    _mediaSessionId = null;
    stateMachine.transitionTo(SessionState.disconnected);

    // Clean up socket and proxy with a timeout so we don't hang
    try {
      await Future.wait([
        _messageSubscription?.cancel() ?? Future.value(),
        _channel.close(),
        _proxy.stop(),
      ]).timeout(const Duration(seconds: 3), onTimeout: () => []);
    } catch (e) {
      CastLogger.warning('Chromecast: cleanup error during disconnect: $e');
    }
    _messageSubscription = null;
    CastLogger.info('Chromecast: disconnected from ${device.name}');
  }

  @override
  void dispose() {
    _stopHeartbeat();
    _stopPositionPolling();
    _mediaStatusSubscription?.cancel();
    unawaited(_proxy.stop());
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _requireMediaSession() {
    if (_mediaSessionId == null) {
      throw StateError('No active media session. Call loadMedia() first.');
    }
  }

  /// Called when the TLS socket drops unexpectedly (stream error or done).
  /// Cleans up timers and transitions to disconnected so the UI can react.
  void _onSocketLost() {
    if (stateMachine.state == SessionState.disconnected) return;
    CastLogger.warning(
      'Chromecast: socket lost, transitioning to disconnected',
    );
    _stopHeartbeat();
    _stopPositionPolling();
    _mediaStatusSubscription?.cancel();
    _mediaStatusSubscription = null;
    _transportId = null;
    _sessionId = null;
    _mediaSessionId = null;
    _isLoadingMedia = false;
    stateMachine.transitionTo(SessionState.disconnected);
  }

  void _sendMediaCommand(String payload) {
    _channel.sendMessage(
      namespace: CastMediaChannel.mediaNamespace,
      sourceId: _senderId,
      destinationId: _transportId!,
      payload: payload,
    );
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _channel.sendMessage(
        namespace: CastReceiverChannel.heartbeatNamespace,
        sourceId: _senderId,
        destinationId: _receiverId,
        payload: CastReceiverChannel.buildPing(),
      );
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Starts a 1-second periodic timer that sends GET_STATUS on the media
  /// channel. The response triggers [_handleMediaStatus] which updates
  /// position, duration, and state.
  void _startPositionPolling() {
    _stopPositionPolling();
    _positionPollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isPolling || _mediaSessionId == null || _transportId == null) {
        return;
      }
      _isPolling = true;
      _sendMediaCommand(_mediaChannel.buildGetStatus());
      _isPolling = false;
    });
  }

  /// Stops the position polling timer.
  void _stopPositionPolling() {
    _positionPollTimer?.cancel();
    _positionPollTimer = null;
    _isPolling = false;
  }

  void _handleMessage(dynamic msg, Completer<void> connectCompleter) {
    final namespace = _getNamespace(msg);
    final payload = _getPayload(msg);
    if (payload == null) return;

    // Receiver-bound message firehose for diagnostics. Equivalent to the
    // stream CaC Tool renders — every namespaced message the receiver
    // sends back. PING/PONG heartbeats are dropped to keep the log
    // readable. Always at debug; promoted to info only when
    // [enableReceiverDebugNamespaces] is on (the same opt-in that
    // subscribes the auxiliary debug namespaces in the first place).
    final type = payload['type'];
    final isHeartbeat =
        namespace == CastReceiverChannel.heartbeatNamespace &&
        (type == 'PING' || type == 'PONG');
    if (!isHeartbeat) {
      final line = 'Chromecast: RX ns=$namespace type=$type — $payload';
      if (enableReceiverDebugNamespaces) {
        CastLogger.info(line);
      } else {
        CastLogger.debug(line);
      }
    }

    // Handle RECEIVER_STATUS — extract volume and session info
    if (namespace == CastReceiverChannel.receiverNamespace &&
        payload['type'] == 'RECEIVER_STATUS') {
      final status = CastReceiverChannel.parseReceiverStatus(payload);
      if (status != null) {
        // Always update volume from device state
        updateVolume(status.volumeLevel);

        // Complete connection if still connecting
        if (!connectCompleter.isCompleted) {
          _transportId = status.transportId;
          _sessionId = status.sessionId;
          connectCompleter.complete();
        }
      }
    }

    // Handle MEDIA_STATUS
    if (namespace == CastMediaChannel.mediaNamespace &&
        payload['type'] == 'MEDIA_STATUS') {
      // Drop late status broadcasts from a failed retry-loop attempt.
      // See [_deprecatedMediaSessionIds] for the rationale — without
      // this filter the stale IDLE+ERROR that follows LOAD_FAILED can
      // arrive after the next attempt has already started and pull
      // the live state machine backwards.
      final parsed = CastMediaChannel.parseMediaStatus(payload);
      final sid = parsed?.mediaSessionId;
      if (sid != null && _deprecatedMediaSessionIds.contains(sid)) {
        CastLogger.debug(
          'Chromecast: dropping stale MEDIA_STATUS from deprecated '
          'mediaSessionId=$sid (playerState=${parsed!.playerState}, '
          'idleReason=${parsed.idleReason ?? "-"})',
        );
        return;
      }
      _handleMediaStatus(payload);
    }
  }

  void _handleMediaStatus(Map<String, dynamic> payload) {
    final status = CastMediaChannel.parseMediaStatus(payload);
    if (status == null) return;

    _mediaSessionId = status.mediaSessionId;

    // Update position
    updatePosition(Duration(milliseconds: (status.currentTime * 1000).round()));

    // Update duration
    if (status.duration != null) {
      updateDuration(Duration(milliseconds: (status.duration! * 1000).round()));
    }

    // Note: MEDIA_STATUS volume is the stream-level volume (usually 1.0),
    // NOT the device volume. Device volume comes from RECEIVER_STATUS
    // and is handled in _handleMessage(). Don't overwrite it here.

    // Update state machine based on playerState
    _updateState(status.playerState, status.idleReason);
  }

  void _updateState(String playerState, String? idleReason) {
    final targetState = switch (playerState) {
      'PLAYING' => SessionState.playing,
      'PAUSED' => SessionState.paused,
      'BUFFERING' => SessionState.buffering,
      'IDLE' => SessionState.idle,
      'LOADING' => SessionState.loading,
      _ => null,
    };

    // Detected here rather than in play(): resuming from the TV remote
    // never passes through play(), only through this status update.
    final resumedFromPause =
        stateMachine.state == SessionState.paused &&
        targetState == SessionState.playing;

    if (targetState != null && stateMachine.canTransitionTo(targetState)) {
      stateMachine.transitionTo(targetState);
    }

    if (resumedFromPause) {
      _reassertActiveTracks();
    }

    // Start/stop position polling based on playback state.
    // Poll during PLAYING and BUFFERING to keep the seek slider current.
    // Stop polling on IDLE to avoid sending commands after media ends.
    if (playerState == 'PLAYING' || playerState == 'BUFFERING') {
      if (_positionPollTimer == null || !_positionPollTimer!.isActive) {
        _startPositionPolling();
      }
    } else if (playerState == 'IDLE') {
      _stopPositionPolling();
    }
    // PAUSED: keep polling so seek-while-paused still updates position.
  }

  /// Waits for the receiver to report a *playable* state after LOAD.
  ///
  /// The receiver may emit several MEDIA_STATUS messages after LOAD — for
  /// example: LOADING → BUFFERING → PLAYING on success, or LOADING → IDLE
  /// with `idleReason=ERROR` on failure. The Cast protocol also has dedicated
  /// `LOAD_FAILED` / `LOAD_CANCELLED` / `INVALID_*` message types that
  /// indicate the LOAD never reached the player at all.
  ///
  /// Completion logic:
  ///   - On `LOAD_FAILED` / `LOAD_CANCELLED` / `INVALID_*`: complete with
  ///     [MediaLoadFailedException] carrying the receiver-reported detail.
  ///   - On MEDIA_STATUS with `playerState=IDLE` + `idleReason=ERROR`:
  ///     complete with [MediaLoadFailedException].
  ///   - On MEDIA_STATUS with a non-IDLE `playerState` (LOADING, BUFFERING,
  ///     PLAYING, PAUSED): complete normally — playback is underway.
  ///   - On MEDIA_STATUS with `playerState=IDLE` and no error reason: keep
  ///     waiting (this can occur briefly between LOAD and the first real
  ///     status), the surrounding `Future.timeout` is the final backstop.
  ///
  /// Also logs every relevant payload at info level for diagnostics.
  ///
  /// [expectedRequestId], when set, restricts which LOAD response
  /// messages this listener treats as "ours". Stale `LOAD_FAILED` /
  /// `LOAD_CANCELLED` from earlier LOADs on the same session (e.g.
  /// after a quick re-load) would otherwise terminate this waiter
  /// incorrectly.
  void _waitForMediaStatus(
    Completer<void> completer, {
    int? expectedRequestId,
    int? priorMediaSessionId,
  }) {
    _mediaStatusSubscription?.cancel();

    // The mediaSessionId the receiver assigned to OUR load, learned from
    // the first MEDIA_STATUS that answers [expectedRequestId]. Needed to
    // attribute *unsolicited* failure broadcasts: a LOAD that failed on a
    // previous attempt leaves a receiver-side session behind whose dying
    // IDLE+ERROR (requestId=0) can arrive milliseconds after the next
    // attempt's LOAD goes out — and must not be read as that attempt
    // failing. Seen live: the retry was declared dead 1ms after it was
    // sent, while the receiver went on to play it fine.
    int? ourMediaSessionId;

    _mediaStatusSubscription = _channel.messageStream.listen((msg) {
      final namespace = _getNamespace(msg);
      final payload = _getPayload(msg);
      if (namespace != CastMediaChannel.mediaNamespace || payload == null) {
        return;
      }

      final type = payload['type'] as String?;
      final responseRequestId = payload['requestId'];

      // Hard LOAD failure — receiver couldn't even prepare the media.
      // These messages always carry the requestId of the LOAD they refer
      // to, so when we know our own LOAD's requestId we can ignore stale
      // responses from earlier attempts.
      if (type == 'LOAD_FAILED' ||
          type == 'LOAD_CANCELLED' ||
          type == 'INVALID_PLAYER_STATE' ||
          type == 'INVALID_REQUEST' ||
          type == 'ERROR') {
        if (expectedRequestId != null &&
            responseRequestId != null &&
            responseRequestId != expectedRequestId) {
          CastLogger.debug(
            'Chromecast: ignoring stale $type '
            '(requestId=$responseRequestId, expected=$expectedRequestId)',
          );
          return;
        }

        CastLogger.error(
          'Chromecast: receiver returned $type during LOAD — payload: $payload',
        );
        if (!completer.isCompleted) {
          completer.completeError(
            MediaLoadFailedException(
              'Receiver returned $type${_formatErrorDetail(payload)}',
            ),
          );
        }
        _mediaStatusSubscription?.cancel();
        _mediaStatusSubscription = null;
        return;
      }

      if (type != 'MEDIA_STATUS') return;

      // Log the parsed status for diagnostics. MEDIA_STATUS fires on every
      // play/pause/seek and during the LOAD handshake, so log at debug —
      // the surrounding error / playable transitions are still at
      // info/error.
      final parsed = CastMediaChannel.parseMediaStatus(payload);
      if (parsed != null) {
        CastLogger.debug(
          'Chromecast: MEDIA_STATUS playerState=${parsed.playerState} '
          'idleReason=${parsed.idleReason ?? "-"} '
          'currentTime=${parsed.currentTime.toStringAsFixed(2)}s '
          'duration=${parsed.duration?.toStringAsFixed(2) ?? "-"}s '
          'volume=${parsed.volumeLevel.toStringAsFixed(2)} '
          'muted=${parsed.isMuted}',
        );
      } else {
        CastLogger.debug(
          'Chromecast: MEDIA_STATUS with no status entries — payload: $payload',
        );
      }

      // Filter out stale MEDIA_STATUS messages from a previous attempt.
      // The receiver assigns a fresh mediaSessionId for each LOAD it
      // processes, so any MEDIA_STATUS still carrying the prior
      // attempt's session id is leftover cleanup chatter and must not
      // terminate the current waiter.
      if (priorMediaSessionId != null &&
          parsed != null &&
          parsed.mediaSessionId == priorMediaSessionId) {
        CastLogger.debug(
          'Chromecast: ignoring stale MEDIA_STATUS '
          '(mediaSessionId=${parsed.mediaSessionId} '
          'matches priorMediaSessionId — leftover from previous attempt)',
        );
        return;
      }

      // A status answering our LOAD's requestId names our session.
      if (parsed != null &&
          expectedRequestId != null &&
          responseRequestId == expectedRequestId) {
        ourMediaSessionId ??= parsed.mediaSessionId;
      }

      // An IDLE+ERROR we cannot attribute to our LOAD — neither a direct
      // response to its requestId nor carrying its session id — is the
      // corpse of an earlier attempt announcing its death. Deprecate the
      // session so the main handler drops its further chatter, and keep
      // waiting: if OUR load is also doomed, its own attributed error or
      // the 15s timeout ends the wait.
      if (parsed != null &&
          parsed.playerState == 'IDLE' &&
          parsed.idleReason == 'ERROR') {
        final isOurs =
            (expectedRequestId != null &&
                responseRequestId == expectedRequestId) ||
            (ourMediaSessionId != null &&
                parsed.mediaSessionId == ourMediaSessionId);
        if (!isOurs) {
          _deprecatedMediaSessionIds.add(parsed.mediaSessionId);
          CastLogger.info(
            'Chromecast: ignoring unattributed IDLE/ERROR from '
            'mediaSessionId=${parsed.mediaSessionId} '
            '(requestId=$responseRequestId, expected=$expectedRequestId, '
            'ours=${ourMediaSessionId ?? "unknown"}) — '
            'stale corpse of a previous attempt, continuing to wait',
          );
          return;
        }
      }

      _handleMediaStatus(payload);

      if (parsed == null) {
        // Empty MEDIA_STATUS — keep waiting.
        return;
      }

      // Hard receiver-side playback failure (attributed to our LOAD above).
      if (parsed.playerState == 'IDLE' && parsed.idleReason == 'ERROR') {
        CastLogger.error(
          'Chromecast: receiver entered IDLE with idleReason=ERROR — '
          'full payload: $payload',
        );
        if (!completer.isCompleted) {
          completer.completeError(
            MediaLoadFailedException(
              'Receiver rejected media (IDLE/ERROR)'
              '${_formatErrorDetail(payload)}',
            ),
          );
        }
        _mediaStatusSubscription?.cancel();
        _mediaStatusSubscription = null;
        return;
      }

      // Playable state — LOAD succeeded.
      if (parsed.playerState != 'IDLE') {
        if (!completer.isCompleted) {
          completer.complete();
        }
        _mediaStatusSubscription?.cancel();
        _mediaStatusSubscription = null;
        return;
      }

      // playerState == IDLE without ERROR — keep waiting for the next status.
      CastLogger.debug(
        'Chromecast: MEDIA_STATUS IDLE without error reason '
        '(idleReason=${parsed.idleReason ?? "-"}) — continuing to wait',
      );
    });
  }

  /// Extracts a short human-readable error detail from an error/LOAD_FAILED
  /// payload. Cast receivers commonly include `reason`, `detailedErrorCode`,
  /// `errorMessage`, or `errorReason` fields. We pluck whichever is present.
  static String _formatErrorDetail(Map<String, dynamic> payload) {
    final parts = <String>[];
    for (final key in const [
      'reason',
      'detailedErrorCode',
      'errorCode',
      'errorMessage',
      'errorReason',
      'customData',
    ]) {
      final v = payload[key];
      if (v != null) parts.add('$key=$v');
    }
    if (parts.isEmpty) return '';
    return ' [${parts.join(', ')}]';
  }

  String? _getNamespace(dynamic msg) {
    if (msg is CastMessage) return msg.namespace_;
    // Mock message
    if (msg is Map) return msg['namespace'] as String?;
    // Dynamic mock object
    try {
      return (msg as dynamic).namespace as String?;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _getPayload(dynamic msg) {
    if (msg is CastMessage) {
      try {
        return jsonDecode(msg.payloadUtf8) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
    // Mock message
    if (msg is Map) return msg['payload'] as Map<String, dynamic>?;
    // Dynamic mock object
    try {
      return (msg as dynamic).payload as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  static String _contentTypeForMedia(CastMediaType type) {
    return switch (type) {
      CastMediaType.hls => 'application/x-mpegURL',
      CastMediaType.mp4 => 'video/mp4',
      CastMediaType.mkv => 'video/x-matroska',
      CastMediaType.mpegTs => 'video/mp2t',
      CastMediaType.audio => 'audio/mpeg',
    };
  }
}

// ---------------------------------------------------------------------------
// Adapter interfaces for testability
// ---------------------------------------------------------------------------

/// Adapter over CastV2Channel or a mock.
abstract class _ChannelAdapter {
  Future<void> connect(String host, {int port});
  Stream<dynamic> get messageStream;
  void sendMessage({
    required String namespace,
    required String sourceId,
    required String destinationId,
    required String payload,
  });
  Future<void> close();
}

// ---------------------------------------------------------------------------
// Real adapters (wrap actual implementations)
// ---------------------------------------------------------------------------

class _RealChannelAdapter implements _ChannelAdapter {
  final CastV2Channel _channel = CastV2Channel();

  @override
  Future<void> connect(String host, {int port = 8009}) =>
      _channel.connect(host, port: port);

  @override
  Stream<CastMessage> get messageStream => _channel.messageStream;

  @override
  void sendMessage({
    required String namespace,
    required String sourceId,
    required String destinationId,
    required String payload,
  }) {
    _channel.sendMessage(
      namespace: namespace,
      sourceId: sourceId,
      destinationId: destinationId,
      payload: payload,
    );
  }

  @override
  Future<void> close() => _channel.close();
}

// ---------------------------------------------------------------------------
// Mock adapters (wrap test doubles)
// ---------------------------------------------------------------------------

class _MockChannelAdapter implements _ChannelAdapter {
  final dynamic _mock;

  _MockChannelAdapter(this._mock);

  @override
  Future<void> connect(String host, {int port = 8009}) =>
      (_mock as dynamic).connect(host, port: port) as Future<void>;

  @override
  Stream<dynamic> get messageStream =>
      (_mock as dynamic).messageStream as Stream<dynamic>;

  @override
  void sendMessage({
    required String namespace,
    required String sourceId,
    required String destinationId,
    required String payload,
  }) {
    (_mock as dynamic).sendMessage(
      namespace: namespace,
      sourceId: sourceId,
      destinationId: destinationId,
      payload: payload,
    );
  }

  @override
  Future<void> close() => (_mock as dynamic).close() as Future<void>;
}
