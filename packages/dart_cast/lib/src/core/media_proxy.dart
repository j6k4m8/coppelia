import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'hls_alt_audio_proxy.dart';
import 'hls_parser.dart';
import 'media_source.dart';
import 'hls_stream_proxy.dart';
import 'http10_file_server.dart';
import 'subtitle_converter.dart';
import '../utils/logger.dart';
import '../utils/network_utils.dart';
import 'ts_dvb_stripper.dart';
import 'ts_keyframe_scanner.dart';

/// Route type for proxy routing.
enum _RouteType { remote, localFile, source, hlsStream, altAudioMuxed }

/// Synthetic content served directly by the proxy (e.g., generated playlists).
class _SyntheticContent {
  final String content;
  final ContentType contentType;

  _SyntheticContent({required this.content, required this.contentType});
}

/// A registered proxy route.
class _ProxyRoute {
  final _RouteType type;

  /// For [_RouteType.source] routes — the caller-supplied byte source.
  final MediaSource? source;
  final String url; // remote URL or local file path
  final Map<String, String> headers;

  /// For [_RouteType.altAudioMuxed] routes — the prepared plan
  /// describing which video + audio source segments to mux for each
  /// segment index. `null` for other route types.
  final HlsAltAudioPlan? altAudioPlan;

  /// When false, MPEG-TS segments are streamed byte-for-byte from
  /// upstream without running the DVB-table stripper. Used by the
  /// bisect "bare" attempt so we can prove whether the stripper is
  /// actually load-bearing for a given source.
  final bool stripDvbTables;

  _ProxyRoute({
    required this.type,
    required this.url,
    this.source,
    this.headers = const {},
    this.altAudioPlan,
    this.stripDvbTables = true,
  });
}

/// Local HTTP proxy server for casting.
///
/// Proxies remote URLs with custom header injection and rewrites HLS playlists.
/// Also serves local files for casting downloaded content.
class MediaProxy {
  HttpServer? _server;
  HttpClient? _httpClient;
  HlsStreamHandler? _hlsStreamHandler;
  String? _baseUrl;
  final Map<String, _ProxyRoute> _routes = {};
  final Map<String, _SyntheticContent> _syntheticContent = {};
  final Random _random = Random.secure();

  /// Cached PAT+PMT packets from the TS file header.
  /// Prepended to every virtual HLS segment so the Chromecast's demuxer
  /// can initialize independently for each segment.
  Uint8List? _tsPatPmt;

  /// The base URL of the running proxy server, or null if not started.
  String? get baseUrl => _baseUrl;

  /// Sets the cached PAT+PMT packets to prepend to virtual HLS segments.
  ///
  /// Called by [TsHlsMediaTransformer] after scanning the TS file header,
  /// before calling [wrapLocalFileAsHls].
  void setPatPmt(Uint8List patPmt) {
    _tsPatPmt = patPmt;
  }

  /// Starts the proxy server bound to the local WiFi IP.
  ///
  /// An optional [port] can be provided; otherwise binds to port 0 to let the
  /// OS assign an available port, eliminating TOCTOU races.
  ///
  /// [targetDeviceIp] is the IP of the cast device we're targeting. When
  /// provided, the proxy binds to the local interface on the same subnet,
  /// which avoids picking a VPN or virtual adapter address that the cast
  /// device can't reach.
  Future<void> start({int? port, String? targetDeviceIp}) async {
    if (_server != null) return;

    _httpClient = HttpClient();
    _hlsStreamHandler = HlsStreamHandler(httpClient: _httpClient);

    final ip = await NetworkUtils.getLocalIpAddress(
      targetDeviceIp: targetDeviceIp,
    );
    final bindAddress = ip ?? '0.0.0.0';

    _server = await HttpServer.bind(bindAddress, port ?? 0);
    // Remove Dart's default security headers — DLNA renderers (especially
    // TCL Google TV) fail to play content when x-content-type-options,
    // x-frame-options, or x-xss-protection headers are present.
    _server!.defaultResponseHeaders.clear();
    final actualPort = _server!.port;
    _baseUrl = 'http://${ip ?? bindAddress}:$actualPort';

    _server!.listen(_handleRequest);
    CastLogger.info('MediaProxy: started on $_baseUrl');
  }

  /// Stops the proxy server and cleans up resources.
  Future<void> stop() async {
    if (_server != null) {
      CastLogger.info('MediaProxy: stopping');
    }
    await _server?.close(force: true);
    _server = null;
    _httpClient?.close(force: true);
    _httpClient = null;
    _hlsStreamHandler = null;
    _altAudioPlanner?.close();
    _altAudioPlanner = null;
    _altAudioMuxer = null;
    _baseUrl = null;
    _routes.clear();
    _syntheticContent.clear();
  }

  /// Registers a remote media URL for proxying.
  ///
  /// Returns a proxy URL that can be given to a cast device.
  ///
  /// [pathExtension], when set, appends a fake file segment to the proxy
  /// URL path (e.g. `pathExtension: 'vtt'` → `/stream/<token>/sub.vtt`).
  /// The token is still the first path segment so routing is unchanged;
  /// the extension only affects the cast receiver's URL-extension probe
  /// (Chromecast / Shaka consult the path extension during
  /// `MediaCapabilities.decodingInfo()` to validate the resource type).
  ///
  /// [stripDvbTables] controls whether MPEG-TS segments are filtered
  /// through [TsDvbStripper] before being served. Default `true`. The
  /// Chromecast retry loop sets this `false` for the bare attempt so we
  /// can isolate whether the stripper is actually doing useful work.
  String registerMedia(
    String url, {
    Map<String, String> headers = const {},
    String? pathExtension,
    bool stripDvbTables = true,
  }) {
    final token = _generateToken();
    _routes[token] = _ProxyRoute(
      type: _RouteType.remote,
      url: url,
      headers: headers,
      stripDvbTables: stripDvbTables,
    );
    if (pathExtension == null || pathExtension.isEmpty) {
      return '$_baseUrl/stream/$token';
    }
    return '$_baseUrl/stream/$token/resource.$pathExtension';
  }

  /// Registers a local file for serving.
  ///
  /// Returns a proxy URL that can be given to a cast device.
  String registerFile(String filePath) {
    final token = _generateToken();
    // Add file extension to the proxy URL so players/TVs can detect format.
    // Many DLNA TVs require the extension to recognize subtitle files.
    final lower = filePath.toLowerCase();
    final ext =
        lower.endsWith('.ts')
            ? '.ts'
            : lower.endsWith('.mp4')
            ? '.mp4'
            : lower.endsWith('.mkv')
            ? '.mkv'
            : lower.endsWith('.vtt')
            ? '.vtt'
            : lower.endsWith('.srt')
            ? '.srt'
            : '';
    _routes['$token$ext'] = _ProxyRoute(
      type: _RouteType.localFile,
      url: filePath,
    );
    return '$_baseUrl/file/$token$ext';
  }

  /// Registers a caller-supplied [MediaSource] for serving.
  ///
  /// Use this for content the proxy cannot open itself — Android
  /// `content://` URIs, Flutter assets, decrypted bytes, anything behind an
  /// API this package does not depend on. The application provides the bytes;
  /// the proxy handles HTTP, byte ranges and seeking.
  ///
  /// [fileExtension] is appended to the returned URL (e.g. `.mp4`). Many DLNA
  /// renderers and Chromecast sniff the extension to pick a demuxer, so supply
  /// it whenever the container is known.
  ///
  /// The returned URL is served over the same path local files use, so it
  /// works for Chromecast, DLNA and AirPlay alike.
  String registerSource(MediaSource source, {String? fileExtension}) {
    final token = _generateToken();
    final ext = _normaliseExtension(fileExtension);
    _routes['$token$ext'] = _ProxyRoute(
      type: _RouteType.source,
      url: '',
      source: source,
    );
    return '$_baseUrl/file/$token$ext';
  }

  static String _normaliseExtension(String? extension) {
    if (extension == null || extension.isEmpty) return '';
    return extension.startsWith('.') ? extension : '.$extension';
  }

  /// Wraps a media URL in a single-segment HLS playlist.
  ///
  /// [duration] is the known duration in seconds. When provided, the playlist
  /// reports the correct total duration so the cast device shows accurate
  /// progress. When null, falls back to a large placeholder value.
  ///
  /// Returns a proxy URL pointing to the generated m3u8 playlist.
  String wrapInHlsPlaylist(String mediaProxyUrl, {double? duration}) {
    final dur = duration ?? 99999.0;
    final playlistContent =
        '#EXTM3U\n'
        '#EXT-X-VERSION:3\n'
        '#EXT-X-PLAYLIST-TYPE:VOD\n'
        '#EXT-X-TARGETDURATION:${dur.ceil()}\n'
        '#EXT-X-MEDIA-SEQUENCE:0\n'
        '#EXTINF:${dur.toStringAsFixed(3)},\n'
        '$mediaProxyUrl\n'
        '#EXT-X-ENDLIST\n';

    CastLogger.debug('MediaProxy: HLS playlist content:\n$playlistContent');

    final token = _generateToken();
    _syntheticContent[token] = _SyntheticContent(
      content: playlistContent,
      contentType: ContentType('application', 'x-mpegURL'),
    );
    return '$_baseUrl/synthetic/$token';
  }

  /// Creates a fake HLS playlist that splits a local file into virtual
  /// byte-range segments of approximately [segmentSeconds] seconds each.
  ///
  /// The segments are served via `#EXT-X-BYTERANGE` so the proxy serves
  /// different byte ranges of the same file. This approach:
  /// - Reports correct playback duration to the TV
  /// - Reduces memory usage (TV loads one segment at a time)
  /// - Enables seeking to specific positions
  ///
  /// [fileProxyUrl] should be a proxy URL from [registerFile].
  /// [filePath] is the local file path (used to determine file size).
  /// [totalDuration] is the known duration in seconds (if available).
  ///   When provided, segment durations are calculated precisely.
  ///   When null, duration is estimated from file size and [estimatedBitrateMbps].
  /// Returns a proxy URL pointing to the generated m3u8 playlist.
  String wrapLocalFileAsHls(
    String fileProxyUrl,
    String filePath, {
    double segmentSeconds = 20.0,
    double? totalDuration,
    double estimatedBitrateMbps = 5.0,
  }) {
    final file = File(filePath);
    if (!file.existsSync()) return wrapInHlsPlaylist(fileProxyUrl);

    final fileSize = file.lengthSync();

    // Only byte-range split MPEG-TS files. MP4 files cannot be split at
    // arbitrary offsets — they need fMP4 with initialization segments.
    final isMpegTs =
        filePath.toLowerCase().endsWith('.ts') ||
        filePath.toLowerCase().endsWith('.mts') ||
        filePath.toLowerCase().endsWith('.m2ts');
    if (!isMpegTs) {
      CastLogger.info('MediaProxy: non-TS file, using single-segment HLS');
      return wrapInHlsPlaylist(fileProxyUrl);
    }

    // Try to get keyframes with PTS values for accurate segment durations.
    // PTS-based durations prevent subtitle desync caused by VBR content
    // where byte proportions don't match time proportions.
    final keyframesWithPts = TsKeyframeScanner.findKeyframeOffsetsWithPts(file);
    final bool usePtsDurations =
        keyframesWithPts != null && keyframesWithPts.length > 1;

    // Scan for keyframe positions — segments MUST start at keyframes
    // for the cast device to decode them independently.
    final keyframeOffsets =
        usePtsDurations
            ? keyframesWithPts.map((kf) => kf.offset).toList()
            : TsKeyframeScanner.findKeyframeOffsets(file);

    // If only 1 keyframe (or scan failed), fall back to single segment
    if (keyframeOffsets.length <= 1) {
      CastLogger.info(
        'MediaProxy: only ${keyframeOffsets.length} keyframe(s), '
        'using single-segment HLS',
      );
      return wrapInHlsPlaylist(fileProxyUrl, duration: totalDuration);
    }

    final double effectiveDuration;
    if (totalDuration != null && totalDuration > 0) {
      effectiveDuration = totalDuration;
    } else {
      final estimatedBytesPerSecond =
          (estimatedBitrateMbps * 1000000 / 8).round();
      effectiveDuration = fileSize / estimatedBytesPerSecond;
    }

    // Group keyframes into segments of ~segmentSeconds each.
    // Each segment starts at a keyframe and ends just before the next
    // segment's first keyframe.
    final segmentOffsets = <int>[0]; // First segment always at 0
    final segmentPtsValues =
        <int?>[]; // PTS at each segment start (if available)

    if (usePtsDurations) {
      segmentPtsValues.add(keyframesWithPts.first.pts);
      // Build a map from offset to PTS for quick lookup
      final offsetToPts = <int, int>{};
      for (final kf in keyframesWithPts) {
        offsetToPts[kf.offset] = kf.pts;
      }

      // Use PTS-based target duration for grouping
      final targetPtsDelta = (segmentSeconds * 90000).round();
      int lastSegmentPts = keyframesWithPts.first.pts;
      for (int i = 1; i < keyframesWithPts.length; i++) {
        final ptsDelta = keyframesWithPts[i].pts - lastSegmentPts;
        if (ptsDelta >= targetPtsDelta) {
          segmentOffsets.add(keyframesWithPts[i].offset);
          segmentPtsValues.add(keyframesWithPts[i].pts);
          lastSegmentPts = keyframesWithPts[i].pts;
        }
      }
    } else {
      final bytesPerSecond = fileSize / effectiveDuration;
      final targetBytesPerSegment = (segmentSeconds * bytesPerSecond).round();

      int lastSegmentStart = 0;
      for (int i = 1; i < keyframeOffsets.length; i++) {
        final bytesSinceLastSegment = keyframeOffsets[i] - lastSegmentStart;
        if (bytesSinceLastSegment >= targetBytesPerSegment) {
          segmentOffsets.add(keyframeOffsets[i]);
          lastSegmentStart = keyframeOffsets[i];
        }
      }
    }

    final segmentCount = segmentOffsets.length;
    final avgSegmentDuration = effectiveDuration / segmentCount;

    // Pre-compute all segment durations to find the max for TARGETDURATION.
    // RFC 8216: each segment's rounded EXTINF MUST be ≤ TARGETDURATION.
    final segmentDurations = <double>[];
    if (usePtsDurations && segmentPtsValues.length == segmentCount) {
      // Use actual PTS differences for accurate durations
      for (int i = 0; i < segmentCount; i++) {
        if (i + 1 < segmentCount) {
          final ptsDelta = segmentPtsValues[i + 1]! - segmentPtsValues[i]!;
          segmentDurations.add(ptsDelta / 90000.0);
        } else {
          // Last segment: use totalDuration or estimate from PTS
          if (totalDuration != null && totalDuration > 0) {
            // Total elapsed PTS so far
            final elapsedPts =
                (segmentPtsValues[i]! - segmentPtsValues[0]!) / 90000.0;
            segmentDurations.add(totalDuration - elapsedPts);
          } else {
            // Estimate last segment from byte proportion as fallback
            final offset = segmentOffsets[i];
            final length = fileSize - offset;
            segmentDurations.add((length / fileSize) * effectiveDuration);
          }
        }
      }
    } else {
      // Fallback: byte-proportion estimate
      for (int i = 0; i < segmentCount; i++) {
        final offset = segmentOffsets[i];
        final nextOffset =
            (i + 1 < segmentCount) ? segmentOffsets[i + 1] : fileSize;
        final length = nextOffset - offset;
        segmentDurations.add((length / fileSize) * effectiveDuration);
      }
    }
    final maxSegDuration = segmentDurations.reduce((a, b) => a > b ? a : b);

    // Use virtual segment URLs instead of EXT-X-BYTERANGE — the Chromecast
    // Default Media Receiver's MPL does not support byte-range segments.
    // Each segment URL includes start/end query params; the proxy serves
    // the corresponding byte range as a complete HTTP response.
    final buffer = StringBuffer();
    buffer.writeln('#EXTM3U');
    buffer.writeln('#EXT-X-VERSION:3');
    buffer.writeln('#EXT-X-PLAYLIST-TYPE:VOD');
    buffer.writeln('#EXT-X-TARGETDURATION:${maxSegDuration.ceil()}');
    buffer.writeln('#EXT-X-MEDIA-SEQUENCE:0');

    for (int i = 0; i < segmentCount; i++) {
      final offset = segmentOffsets[i];
      final nextOffset =
          (i + 1 < segmentCount) ? segmentOffsets[i + 1] : fileSize;

      buffer.writeln('#EXTINF:${segmentDurations[i].toStringAsFixed(3)},');
      buffer.writeln('$fileProxyUrl?start=$offset&end=${nextOffset - 1}');
    }
    buffer.writeln('#EXT-X-ENDLIST');

    final playlistContent = buffer.toString();
    CastLogger.debug('MediaProxy: HLS playlist content:\n$playlistContent');

    final token = _generateToken();
    _syntheticContent[token] = _SyntheticContent(
      content: playlistContent,
      contentType: ContentType('application', 'x-mpegURL'),
    );

    CastLogger.info(
      'MediaProxy: created HLS playlist with $segmentCount keyframe-aligned segments '
      '(~${avgSegmentDuration.toStringAsFixed(1)}s avg, '
      '~${effectiveDuration.toStringAsFixed(0)}s total, '
      '${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB, '
      '${keyframeOffsets.length} keyframes found'
      '${usePtsDurations ? ", PTS-based durations" : ", byte-estimated durations"}'
      '${totalDuration != null ? ", known duration" : ", estimated"}'
      ')',
    );

    return '$_baseUrl/synthetic/$token';
  }

  /// Registers a subtitle URL — handles both remote URLs and local file:// paths.
  ///
  /// If [urlOrPath] starts with `file://`, the subtitle is served as a local
  /// file. Otherwise it is proxied as a remote URL.
  /// Returns a proxy URL that can be given to a cast device.
  String registerSubtitle(
    String urlOrPath, {
    Map<String, String> headers = const {},
  }) {
    String proxyUrl;
    if (urlOrPath.startsWith('file://')) {
      final filePath = urlOrPath.replaceFirst('file://', '');
      proxyUrl = registerFile(filePath);
    } else {
      // Remote subtitle: hint `.vtt` in the proxy path. The proxy converts
      // SRT → VTT on the fly inside `_handleStreamRequest`, so the served
      // body is always WebVTT regardless of upstream format. Letting the
      // path end in `.vtt` keeps Chromecast/Shaka's URL-extension probe
      // happy when these URLs appear in the LOAD message's tracks array.
      proxyUrl = registerMedia(
        urlOrPath,
        headers: headers,
        pathExtension: 'vtt',
      );
    }
    return proxyUrl;
  }

  /// Registers subtitle variants in both SRT and VTT formats for DLNA.
  ///
  /// Many DLNA TVs only support one format. By serving both, the TV can
  /// pick whichever it supports. The original file is served as-is, and
  /// a converted variant is generated (VTT→SRT or SRT→VTT).
  ///
  /// Returns a list of (url, format) pairs for inclusion in DIDL-Lite.
  List<({String url, String format})> registerSubtitleVariants(
    String urlOrPath, {
    Map<String, String> headers = const {},
  }) {
    // Register the original subtitle
    final originalUrl = registerSubtitle(urlOrPath, headers: headers);

    // Read content to detect format and generate the other variant
    String? content;
    String originalPath = urlOrPath;
    if (originalPath.startsWith('file://')) {
      originalPath = originalPath.replaceFirst('file://', '');
    }

    try {
      if (File(originalPath).existsSync()) {
        content = File(originalPath).readAsStringSync();
      }
    } catch (_) {}

    if (content == null) {
      // Can't read file, just return original with guessed format
      final isVtt = urlOrPath.toLowerCase().endsWith('.vtt');
      return [(url: originalUrl, format: isVtt ? 'vtt' : 'srt')];
    }

    final isVtt = content.trimLeft().startsWith('WEBVTT');
    final isSrt = SubtitleConverter.isSrt(content);

    final variants = <({String url, String format})>[];

    if (isVtt) {
      // Original is VTT — generate SRT variant
      variants.add((url: originalUrl, format: 'vtt'));
      final srtContent = SubtitleConverter.vttToSrt(content);
      final srtToken = _generateToken();
      _syntheticContent['$srtToken.srt'] = _SyntheticContent(
        content: srtContent,
        contentType: ContentType('text', 'srt'),
      );
      variants.add((url: '$_baseUrl/synthetic/$srtToken.srt', format: 'srt'));
    } else if (isSrt) {
      // Original is SRT — generate VTT variant
      variants.add((url: originalUrl, format: 'srt'));
      final vttContent = SubtitleConverter.srtToVtt(content);
      final vttToken = _generateToken();
      _syntheticContent['$vttToken.vtt'] = _SyntheticContent(
        content: vttContent,
        contentType: ContentType('text', 'vtt'),
      );
      variants.add((url: '$_baseUrl/synthetic/$vttToken.vtt', format: 'vtt'));
    } else {
      // Unknown format, serve as-is
      variants.add((url: originalUrl, format: 'srt'));
    }

    return variants;
  }

  /// Registers an HLS stream to be served as continuous MPEG-TS.
  ///
  /// When a client (e.g. a DLNA TV) GETs the returned URL, the proxy fetches
  /// the m3u8 playlist, resolves all segments, and pipes them sequentially
  /// as a single `video/mp2t` response. This is useful for devices that do
  /// not support HLS natively.
  String registerHlsAsStream(
    String m3u8Url, {
    Map<String, String> headers = const {},
  }) {
    final token = _generateToken();
    _routes[token] = _ProxyRoute(
      type: _RouteType.hlsStream,
      url: m3u8Url,
      headers: headers,
    );
    return '$_baseUrl/ts-stream/$token';
  }

  /// Probes an HLS playlist for its total duration.
  ///
  /// Returns null for live streams or when the playlist cannot be read.
  /// Used by DLNA, which pipes HLS as a length-less TS stream and therefore
  /// cannot work out the duration by itself.
  Future<Duration?> probeHlsDuration(
    String m3u8Url, {
    Map<String, String> headers = const {},
  }) async {
    final handler = _hlsStreamHandler;
    if (handler == null) return null;
    return handler.probeDuration(m3u8Url, headers);
  }

  /// Optional planner / muxer for alt-audio routes. Created lazily on
  /// first use; closed in [stop].
  HlsAltAudioPlanner? _altAudioPlanner;
  HlsAltAudioSegmentMuxer? _altAudioMuxer;

  /// Plans and registers an alternate-audio HLS source as a *muxed*
  /// route. The proxy will fetch the upstream master, pair video +
  /// audio segments, and serve a single muxed-TS HLS stream the
  /// receiver can play without any alt-audio support.
  ///
  /// Returns a proxy URL pointing to the synthetic master playlist —
  /// give that to the cast device's LOAD message.
  ///
  /// [preferredAudioLanguage] is a string fragment matched against
  /// each rendition's NAME attribute (e.g. `"jpn"`, `"English"`).
  /// When null, the receiver's choice falls back to `DEFAULT=YES` and
  /// then to the first rendition.
  Future<String?> registerAltAudioMuxed({
    required String masterUrl,
    Map<String, String> headers = const {},
    String? preferredAudioLanguage,
  }) async {
    _altAudioPlanner ??= HlsAltAudioPlanner(httpClient: _httpClient);
    _altAudioMuxer ??= HlsAltAudioSegmentMuxer(planner: _altAudioPlanner!);

    HlsAltAudioPlan? plan;
    try {
      plan = await _altAudioPlanner!.plan(
        masterUrl: masterUrl,
        headers: headers,
        preferredAudioLanguage: preferredAudioLanguage,
      );
    } catch (e) {
      // Planning fetched the upstream master and something went wrong
      // (network error, malformed playlist, …). The caller is expected
      // to fall back to the standard pass-through route — the
      // receiver's own fetch will produce a clearer error if the
      // source is genuinely broken.
      CastLogger.debug(
        'MediaProxy.registerAltAudioMuxed: planning failed, '
        'falling back to standard route. Reason: $e',
      );
      return null;
    }
    if (plan == null) {
      // Source isn't actually alt-audio — caller should fall back to
      // the standard remote route.
      return null;
    }

    final token = _generateToken();
    _routes[token] = _ProxyRoute(
      type: _RouteType.altAudioMuxed,
      url: masterUrl,
      headers: headers,
      altAudioPlan: plan,
    );
    final masterPath = '$_baseUrl/alt-audio/$token/master.m3u8';
    CastLogger.info(
      'MediaProxy: registered alt-audio muxed route token=$token, '
      'segments=${plan.segments.length}, masterUrl=$masterPath',
    );
    return masterPath;
  }

  /// Registers a VTT subtitle file as an HLS subtitle playlist.
  ///
  /// Creates a simple HLS media playlist wrapping the VTT file so it can be
  /// referenced via `#EXT-X-MEDIA:TYPE=SUBTITLES` in a master playlist.
  /// Returns a proxy URL pointing to the generated m3u8.
  String registerSubtitlePlaylist(
    String vttUrl, {
    Map<String, String> headers = const {},
  }) {
    // First, register the VTT file itself through the proxy
    // Uses registerSubtitle to handle both file:// and http:// URLs
    final proxiedVttUrl = registerSubtitle(vttUrl, headers: headers);

    // Create a simple HLS playlist wrapping the VTT
    final playlistContent =
        '#EXTM3U\n'
        '#EXT-X-TARGETDURATION:99999\n'
        '#EXTINF:99999.0,\n'
        '$proxiedVttUrl\n'
        '#EXT-X-ENDLIST\n';

    // Register the playlist content as a synthetic route
    final token = _generateToken();
    _syntheticContent[token] = _SyntheticContent(
      content: playlistContent,
      contentType: ContentType('application', 'x-mpegURL'),
    );
    return '$_baseUrl/synthetic/$token';
  }

  /// Creates a wrapper master playlist that adds subtitle tracks to an
  /// existing HLS stream.
  ///
  /// [originalM3u8ProxyUrl] is the already-proxied URL of the original master
  /// playlist. [subtitleEntries] is a list of `(name, language, subtitleM3u8Url)`
  /// tuples, where each URL points to a subtitle HLS playlist (e.g., from
  /// [registerSubtitlePlaylist]).
  ///
  /// Returns a proxy URL for the wrapper master playlist.
  String registerSubtitleWrapper({
    required String originalM3u8ProxyUrl,
    required List<({String name, String language, String url})> subtitleEntries,
  }) {
    final buffer = StringBuffer('#EXTM3U\n');

    for (var i = 0; i < subtitleEntries.length; i++) {
      final entry = subtitleEntries[i];
      final isDefault = i == 0 ? 'YES' : 'NO';
      buffer.writeln(
        '#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",'
        'NAME="${entry.name}",DEFAULT=$isDefault,AUTOSELECT=$isDefault,'
        'LANGUAGE="${entry.language}",URI="${entry.url}"',
      );
    }

    buffer.writeln('#EXT-X-STREAM-INF:BANDWIDTH=1280000,SUBTITLES="subs"');
    buffer.writeln(originalM3u8ProxyUrl);

    final token = _generateToken();
    _syntheticContent[token] = _SyntheticContent(
      content: buffer.toString(),
      contentType: ContentType('application', 'x-mpegURL'),
    );
    return '$_baseUrl/synthetic/$token';
  }

  /// Removes all previously registered routes and synthetic content,
  /// optionally keeping [excludeToken] and anything it depends on.
  ///
  /// The token can be either a route key or a synthetic content key.
  /// If it's synthetic content (e.g. an HLS playlist), any /file/ routes
  /// referenced in that content are also preserved so segment URLs keep working.
  void cleanupPreviousMedia({String? excludeToken}) {
    if (excludeToken != null) {
      final keptRoute = _routes[excludeToken];
      final keptSynthetic = _syntheticContent[excludeToken];

      // If the excluded token is synthetic content (e.g. HLS playlist),
      // preserve any file routes it references as segment URLs.
      final referencedRoutes = <String, _ProxyRoute>{};
      if (keptSynthetic != null) {
        for (final entry in _routes.entries) {
          if (keptSynthetic.content.contains('/file/${entry.key}')) {
            referencedRoutes[entry.key] = entry.value;
          }
        }
      }

      _routes.clear();
      if (keptRoute != null) {
        _routes[excludeToken] = keptRoute;
      }
      _routes.addAll(referencedRoutes);

      _syntheticContent.clear();
      if (keptSynthetic != null) {
        _syntheticContent[excludeToken] = keptSynthetic;
      }
    } else {
      _routes.clear();
      _syntheticContent.clear();
    }
  }

  String _generateToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      16,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;
      final rangeHeader = request.headers.value('Range');

      // Log the full request including a short summary of the proxied URL
      // (the ?url= sub-resource parameter). The encoded URL itself is huge,
      // so we decode it once and trim — enough to identify which segment /
      // playlist is being fetched without flooding the log file.
      final subUrl = request.uri.queryParameters['url'];
      final subUrlSummary = subUrl == null ? '' : ' → ${_summarizeUrl(subUrl)}';
      CastLogger.debug(
        'MediaProxy: ${request.method} $path$subUrlSummary'
        '${rangeHeader != null ? ' Range: $rangeHeader' : ''}',
      );
      // Log all request headers for DLNA debugging
      final headerBuf = StringBuffer();
      request.headers.forEach((name, values) {
        headerBuf.write('  $name: ${values.join(", ")}\n');
      });
      CastLogger.debug('MediaProxy: request headers:\n$headerBuf');

      // Handle CORS preflight (OPTIONS) requests — Chromecast's HLS player
      // sends these before fetching segments from a different origin/path.
      if (request.method == 'OPTIONS') {
        _addCorsHeaders(request.response, request.headers.value('Origin'));
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return;
      }

      // Route: /ts-stream/<token> — HLS-to-MPEG-TS streaming
      if (path.startsWith('/ts-stream/')) {
        final token = path.substring('/ts-stream/'.length);
        await _handleHlsStreamRequest(request, token);
        return;
      }

      // Route: /alt-audio/<token>/(master.m3u8|variant.m3u8|seg<N>.ts)
      // — synthesised single-stream HLS that merges alt-audio source.
      if (path.startsWith('/alt-audio/')) {
        await _handleAltAudioRequest(request);
        return;
      }

      // Route: /stream/<token>[/anything] — remote proxy (direct or
      // sub-resource via ?url=). The token is the first path segment after
      // `/stream/`; anything after (e.g. `/seg42.ts`) is a hint for the
      // receiver's URL-extension probe and is ignored for routing.
      if (path.startsWith('/stream/')) {
        final rest = path.substring('/stream/'.length);
        final slashIdx = rest.indexOf('/');
        final token = slashIdx < 0 ? rest : rest.substring(0, slashIdx);
        await _handleStreamRequest(request, token);
        return;
      }

      // Route: /synthetic/<token> — generated content (subtitle playlists, wrappers)
      if (path.startsWith('/synthetic/')) {
        final token = path.substring('/synthetic/'.length);
        await _handleSyntheticRequest(request, token);
        return;
      }

      // Route: /file/<token> — local file serving
      if (path.startsWith('/file/')) {
        final token = path.substring('/file/'.length);
        await _handleFileRequest(request, token);
        return;
      }

      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    } catch (e) {
      CastLogger.error('MediaProxy: request handler error: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {
        // Response may already be closed
      }
    }
  }

  Future<void> _handleSyntheticRequest(
    HttpRequest request,
    String token,
  ) async {
    final synthetic = _syntheticContent[token];
    if (synthetic == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    CastLogger.debug(
      'MediaProxy: serving synthetic content token=$token '
      'contentType=${synthetic.contentType} '
      'size=${synthetic.content.length} chars',
    );

    final encoded = utf8.encode(synthetic.content);

    // Serve via HTTP/1.0 for DLNA compatibility (same as file serving)
    final socket = await request.response.detachSocket(writeHeaders: false);
    try {
      final headers = StringBuffer();
      headers.write('HTTP/1.0 200 OK\r\n');
      headers.write('Content-Type: ${synthetic.contentType.mimeType}\r\n');
      headers.write('Content-Length: ${encoded.length}\r\n');
      headers.write('\r\n');
      socket.add(utf8.encode(headers.toString()));
      if (request.method != 'HEAD') {
        socket.add(encoded);
      }
    } finally {
      await socket.close();
    }
  }

  /// Handles `/alt-audio/<token>/(master.m3u8|variant.m3u8|seg<N>.ts)`
  /// requests for the muxed alt-audio HLS pipeline.
  Future<void> _handleAltAudioRequest(HttpRequest request) async {
    final segments = request.uri.pathSegments;
    // Expected layout: ["alt-audio", "<token>", "<filename>"]
    if (segments.length < 3) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final token = segments[1];
    final filename = segments[2];
    final route = _routes[token];
    final plan = route?.altAudioPlan;
    if (route == null ||
        route.type != _RouteType.altAudioMuxed ||
        plan == null) {
      CastLogger.warning(
        'MediaProxy: alt-audio route not found — token=$token '
        '(filename=$filename, registered tokens: '
        '${_routes.keys.take(8).join(", ")}'
        '${_routes.length > 8 ? ", …" : ""})',
      );
      request.response.statusCode = HttpStatus.notFound;
      _addCorsHeaders(request.response, request.headers.value('Origin'));
      await request.response.close();
      return;
    }

    // master.m3u8 → synthetic master pointing at our variant URL.
    if (filename == 'master.m3u8') {
      final variantUrl = '$_baseUrl/alt-audio/$token/variant.m3u8';
      final text = HlsAltAudioPlaylistRenderer.renderMaster(
        plan: plan,
        variantPlaylistUrl: variantUrl,
      );
      final encoded = utf8.encode(text);
      CastLogger.debug(
        'MediaProxy: alt-audio master.m3u8 → ${encoded.length}b\n$text',
      );
      _addCorsHeaders(request.response, request.headers.value('Origin'));
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType(
        'application',
        'x-mpegURL',
      );
      request.response.headers.set('Content-Length', encoded.length.toString());
      request.response.add(encoded);
      await request.response.close();
      return;
    }

    // variant.m3u8 → synthetic variant listing muxed segment URLs.
    if (filename == 'variant.m3u8') {
      final text = HlsAltAudioPlaylistRenderer.renderVariant(
        plan: plan,
        muxedSegmentUrlFor: (i) => '$_baseUrl/alt-audio/$token/seg$i.ts',
      );
      final encoded = utf8.encode(text);
      CastLogger.debug(
        'MediaProxy: alt-audio variant.m3u8 → ${encoded.length}b '
        '(${plan.segments.length} segments)',
      );
      _addCorsHeaders(request.response, request.headers.value('Origin'));
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType(
        'application',
        'x-mpegURL',
      );
      request.response.headers.set('Content-Length', encoded.length.toString());
      request.response.add(encoded);
      await request.response.close();
      return;
    }

    // seg<N>.ts → mux source pair and stream.
    final segMatch = RegExp(r'^seg(\d+)\.ts$').firstMatch(filename);
    if (segMatch != null) {
      final index = int.parse(segMatch.group(1)!);
      if (_altAudioMuxer == null) {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
        return;
      }
      try {
        final muxed = await _altAudioMuxer!.muxSegment(
          plan: plan,
          segmentIndex: index,
        );
        CastLogger.debug(
          'MediaProxy: alt-audio seg$index.ts → ${muxed.bytes.length}b '
          '(packets=${muxed.packetCount}, video=${muxed.videoPacketsCopied}, '
          'audio=${muxed.audioPacketsCopied}, dropped=${muxed.packetsDropped})',
        );
        _addCorsHeaders(request.response, request.headers.value('Origin'));
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType('video', 'mp2t');
        request.response.headers.set(
          'Content-Length',
          muxed.bytes.length.toString(),
        );
        request.response.add(muxed.bytes);
        await request.response.close();
        return;
      } catch (e, stack) {
        CastLogger.error(
          'MediaProxy: alt-audio segment $index mux failed: $e\n$stack',
        );
        try {
          request.response.statusCode = HttpStatus.badGateway;
          await request.response.close();
        } catch (_) {}
        return;
      }
    }

    request.response.statusCode = HttpStatus.notFound;
    _addCorsHeaders(request.response, request.headers.value('Origin'));
    await request.response.close();
  }

  Future<void> _handleHlsStreamRequest(
    HttpRequest request,
    String token,
  ) async {
    if (_hlsStreamHandler == null) {
      request.response
        ..statusCode = HttpStatus.serviceUnavailable
        ..close();
      return;
    }

    final route = _routes[token];
    if (route == null || route.type != _RouteType.hlsStream) {
      request.response.statusCode = HttpStatus.notFound;
      _addCorsHeaders(request.response, request.headers.value('Origin'));
      await request.response.close();
      return;
    }

    // DLNA renderers seek a non-seekable stream with TimeSeekRange.dlna.org
    // rather than a byte Range. Honour it by restarting the pipe at the
    // segment covering that offset.
    final seekHeader =
        request.headers.value('TimeSeekRange.dlna.org') ??
        request.headers.value('X-Seek-Range');
    var startAt = parseTimeSeekRange(seekHeader);

    // Renderers that only ever ask for `Range: bytes=0-` cannot express a
    // time seek at all. For those the sender re-points them at the same route
    // with `?t=<seconds>`, which restarts the pipe at that offset.
    if (startAt == Duration.zero) {
      final t = request.uri.queryParameters['t'];
      final seconds = t == null ? null : double.tryParse(t);
      if (seconds != null && seconds > 0) {
        startAt = Duration(milliseconds: (seconds * 1000).round());
      }
    }
    CastLogger.info(
      'MediaProxy: ts-stream request '
      '(TimeSeekRange=${seekHeader ?? 'none'}, '
      'Range=${request.headers.value('Range') ?? 'none'}, '
      'startAt=${startAt.inSeconds}s)',
    );

    await _hlsStreamHandler!.streamAsTransportStream(
      route.url,
      route.headers,
      request.response,
      startAt: startAt,
    );
  }

  /// Parses a DLNA `TimeSeekRange.dlna.org` header value into a start offset.
  ///
  /// Accepts the normal-play-time forms DLNA senders use, e.g.
  /// `npt=120.5-`, `npt=120.5-300.0` and `npt=0:02:00.500-`. Returns
  /// [Duration.zero] when the header is absent or unparseable, which makes the
  /// stream behave exactly as it did before time seeking existed.
  static Duration parseTimeSeekRange(String? value) {
    if (value == null || value.isEmpty) return Duration.zero;

    final match = RegExp(
      r'npt\s*=\s*([^-\s]+)',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) return Duration.zero;

    final start = match.group(1)!;

    // Plain seconds, possibly fractional.
    final asSeconds = double.tryParse(start);
    if (asSeconds != null) {
      if (asSeconds <= 0) return Duration.zero;
      return Duration(milliseconds: (asSeconds * 1000).round());
    }

    // hh:mm:ss(.fff) form.
    final parts = start.split(':');
    if (parts.length < 2 || parts.length > 3) return Duration.zero;
    var seconds = 0.0;
    for (final part in parts) {
      final v = double.tryParse(part);
      if (v == null) return Duration.zero;
      seconds = seconds * 60 + v;
    }
    if (seconds <= 0) return Duration.zero;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  Future<void> _handleStreamRequest(HttpRequest request, String token) async {
    final route = _routes[token];
    if (route == null || route.type != _RouteType.remote) {
      request.response.statusCode = HttpStatus.notFound;
      _addCorsHeaders(request.response, request.headers.value('Origin'));
      await request.response.close();
      return;
    }

    // Determine the actual URL to fetch:
    // If ?url= query param is present, use that (sub-resource from rewritten m3u8).
    // Otherwise, use the registered URL directly.
    final urlParam = request.uri.queryParameters['url'];
    final targetUrl = urlParam ?? route.url;

    // Fetch upstream
    final upstreamUri = Uri.parse(targetUrl);
    final upstreamRequest = await _httpClient!.openUrl('GET', upstreamUri);

    // Inject registered headers
    for (final entry in route.headers.entries) {
      upstreamRequest.headers.set(entry.key, entry.value);
    }

    // Forward Range header if present
    final rangeHeader = request.headers.value('Range');
    if (rangeHeader != null) {
      upstreamRequest.headers.set('Range', rangeHeader);
    }

    final upstreamResponse = await upstreamRequest.close();

    // Set response status
    request.response.statusCode = upstreamResponse.statusCode;
    _addCorsHeaders(request.response, request.headers.value('Origin'));

    // Forward relevant headers
    final upstreamContentType = upstreamResponse.headers.contentType;
    final upstreamLen = upstreamResponse.headers.value('Content-Length');

    // Diagnostic: log every proxied fetch's outcome with upstream URL summary,
    // upstream status, and Content-Type. This is the only place we can see
    // what the segment server actually returned for each segment request.
    CastLogger.debug(
      'MediaProxy: upstream ${upstreamResponse.statusCode} '
      'type=${upstreamContentType?.toString() ?? "-"} '
      'len=${upstreamLen ?? "-"} '
      'url=${_summarizeUrl(targetUrl)}',
    );

    // Override `image/*` content-types on proxied media segments.
    // Some streaming sources obfuscate segment URLs with image extensions
    // (e.g. `.jpg`) — the upstream extractor often returns `image/jpeg` to
    // match, even though the bytes are raw MPEG-TS. Chromecast / Shaka
    // refuses to feed `image/*` responses into the demuxer, so playback
    // never starts (the receiver fetches playlists but no segments). For
    // anything served via `/stream/<token>?url=...` that comes back as an
    // image type, force `video/mp2t` so the receiver treats it as TS.
    // The override is intentionally narrow: only when the upstream looks
    // like an image AND the proxied URL is a sub-resource fetch.
    var effectiveContentType = upstreamContentType;
    final isSubresource = request.uri.queryParameters['url'] != null;
    if (isSubresource &&
        upstreamContentType != null &&
        upstreamContentType.primaryType.toLowerCase() == 'image') {
      effectiveContentType = ContentType('video', 'mp2t');
      CastLogger.warning(
        'MediaProxy: upstream returned $upstreamContentType for a media '
        'segment — rewriting Content-Type to video/mp2t. url='
        '${_summarizeUrl(targetUrl)}',
      );
    }

    if (effectiveContentType != null) {
      request.response.headers.contentType = effectiveContentType;
    }

    final contentRange = upstreamResponse.headers.value('Content-Range');
    if (contentRange != null) {
      request.response.headers.set('Content-Range', contentRange);
      request.response.headers.set('Accept-Ranges', 'bytes');
    }

    // Forward Content-Length ONLY when we're going to stream the body
    // through unchanged. If the response will be rewritten (HLS
    // playlist rewrite branch below) or filtered (DVB-table stripper —
    // see the video/mp2t check that creates `stripper` further down),
    // the final body length differs from upstream and pinning
    // Content-Length here causes Dart's HttpResponse to raise an
    // exception mid-stream once the body falls short. We pre-compute
    // here whether the body will be mutated and only forward
    // Content-Length when it's truly safe. When `route.stripDvbTables`
    // is false, mp2t bodies pass through unchanged so Content-Length
    // is safe to forward.
    final willStripMp2t =
        effectiveContentType?.primaryType.toLowerCase() == 'video' &&
        effectiveContentType?.subType.toLowerCase() == 'mp2t' &&
        route.stripDvbTables;
    final willMutateBody =
        _isSubtitleResponse(targetUrl, upstreamContentType) ||
        _isHlsResponse(targetUrl, upstreamContentType) ||
        willStripMp2t;
    final contentLength = upstreamResponse.headers.value('Content-Length');
    if (contentLength != null && !willMutateBody) {
      request.response.headers.set('Content-Length', contentLength);
    }

    // Auto-convert SRT subtitle responses to VTT and strip X-TIMESTAMP-MAP
    if (_isSubtitleResponse(targetUrl, upstreamContentType) &&
        upstreamResponse.statusCode == HttpStatus.ok) {
      final body = await upstreamResponse.fold<List<int>>(
        <int>[],
        (prev, chunk) => prev..addAll(chunk),
      );
      var content = utf8.decode(body);

      CastLogger.debug(
        'MediaProxy: subtitle response (${content.length} chars, '
        'isSrt=${SubtitleConverter.isSrt(content)}, '
        'hasTimestampMap=${content.contains('X-TIMESTAMP-MAP')})',
      );
      CastLogger.debug(
        'MediaProxy: subtitle content (first 500 chars):\n'
        '${content.substring(0, content.length > 500 ? 500 : content.length)}',
      );

      if (SubtitleConverter.isSrt(content)) {
        content = SubtitleConverter.srtToVtt(content);
        CastLogger.debug('MediaProxy: converted SRT → VTT');
      }

      // Strip X-TIMESTAMP-MAP from VTT — this header is for HLS subtitle
      // segments and causes cast devices to apply an incorrect PTS offset
      // when the VTT is served as a sidecar track.
      if (content.contains('X-TIMESTAMP-MAP')) {
        CastLogger.debug('MediaProxy: stripping X-TIMESTAMP-MAP from VTT');
        content = SubtitleConverter.stripTimestampMap(content);
      }

      final encoded = utf8.encode(content);
      request.response.headers.contentType = ContentType('text', 'vtt');
      request.response.headers.set('Content-Length', encoded.length.toString());
      request.response.add(encoded);
      await request.response.close();
      return;
    }

    // Check if this is an HLS playlist that needs rewriting
    if (_isHlsResponse(targetUrl, upstreamContentType) &&
        upstreamResponse.statusCode == HttpStatus.ok) {
      // Buffer the playlist content for rewriting
      final body = await upstreamResponse.fold<List<int>>(
        <int>[],
        (prev, chunk) => prev..addAll(chunk),
      );
      final content = utf8.decode(body);

      if (content.trimLeft().startsWith('#EXTM3U')) {
        final rewritten = HlsParser.rewritePlaylist(
          content,
          targetUrl,
          _baseUrl!,
          token,
        );

        CastLogger.info(
          'MediaProxy: rewritten HLS playlist (${rewritten.length} chars)',
        );
        CastLogger.debug('MediaProxy: rewritten HLS playlist:\n$rewritten');

        // Override content type and length for rewritten playlist
        final encoded = utf8.encode(rewritten);
        request.response.headers.contentType = ContentType(
          'application',
          'x-mpegURL',
        );
        request.response.headers.set(
          'Content-Length',
          encoded.length.toString(),
        );
        request.response.add(encoded);
        await request.response.close();
        return;
      }

      // Not actually a valid m3u8 — send the body as-is
      request.response.add(body);
      await request.response.close();
      return;
    }

    // Stream non-playlist content. For MPEG-TS responses (real or
    // overridden from image/*), run the byte stream through a DVB-table
    // stripper — providers sometimes emit segments whose leading packets
    // are DVB tables (SDT on 0x0011, NIT, EIT, …) instead of the PAT
    // that strict TS demuxers (Chromecast / Shaka) expect to see first.
    // The stripper drops only DVB-only PIDs; PAT, PMT, audio, and video
    // packets pass through untouched. For non-TS responses we stream
    // bytes through unchanged.
    //
    // The stripper can be disabled per-route via `stripDvbTables: false`
    // on `registerMedia` — the Chromecast retry loop's "bare" attempt
    // uses this to test whether the stripper is actually load-bearing.
    final isMp2t =
        effectiveContentType?.primaryType.toLowerCase() == 'video' &&
        effectiveContentType?.subType.toLowerCase() == 'mp2t';
    final stripper = (isMp2t && route.stripDvbTables) ? TsDvbStripper() : null;

    var isFirstChunk = true;
    await for (final chunk in upstreamResponse) {
      if (isFirstChunk && chunk.isNotEmpty) {
        isFirstChunk = false;
        final preview = chunk
            .take(16)
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' ');
        final kind = _identifyByteSignature(chunk);
        CastLogger.debug(
          'MediaProxy: first bytes of $kind body — $preview '
          '(${chunk.length}b in chunk) url=${_summarizeUrl(targetUrl)}',
        );
      }
      if (stripper != null) {
        final filtered = stripper.process(chunk);
        if (filtered.isNotEmpty) {
          request.response.add(filtered);
        }
      } else {
        request.response.add(chunk);
      }
    }
    if (stripper != null) {
      final tail = stripper.flush();
      if (tail.isNotEmpty) {
        request.response.add(tail);
      }
      // Log TS structure at debug — fires per segment so info would be
      // very loud during playback. PID histogram + arrival order help
      // diagnose missing-PAT / DVB-table-first situations when needed.
      // Promote to warning when packets were actually dropped — that's
      // the case where the stripper is doing visible work.
      final arrival = stripper.pidArrivalOrder
          .take(16)
          .map(
            (p) =>
                '0x${p.toRadixString(16).padLeft(4, '0')}'
                '×${stripper.pidCounts[p]}',
          )
          .join(' ');
      final hasPat = stripper.pidCounts.containsKey(0x0000);
      final line =
          'MediaProxy: TS stripper '
          'kept=${stripper.packetsKept} dropped=${stripper.packetsDropped} '
          'hasPAT=$hasPat '
          'firstPids=[$arrival] '
          'url=${_summarizeUrl(targetUrl)}';
      if (stripper.packetsDropped > 0) {
        CastLogger.info(line);
      } else {
        CastLogger.debug(line);
      }
    }
    await request.response.close();
  }

  /// Identifies common media container signatures from the first few bytes.
  /// Helps diagnose Content-Type vs actual-data mismatches when the
  /// upstream extractor lies about what it serves.
  static String _identifyByteSignature(List<int> chunk) {
    if (chunk.isEmpty) return 'empty';
    final b0 = chunk[0];
    // MPEG-TS sync byte
    if (b0 == 0x47) return 'mpeg-ts (0x47)';
    // ADTS AAC starts with 0xFFF
    if (chunk.length >= 2 && b0 == 0xFF && (chunk[1] & 0xF0) == 0xF0) {
      return 'aac-adts (0xFFFx)';
    }
    // fMP4 — ftyp box near start (0x66 0x74 0x79 0x70 = 'ftyp')
    if (chunk.length >= 8 &&
        chunk[4] == 0x66 &&
        chunk[5] == 0x74 &&
        chunk[6] == 0x79 &&
        chunk[7] == 0x70) {
      return 'fmp4 (ftyp)';
    }
    // JPEG
    if (chunk.length >= 2 && b0 == 0xFF && chunk[1] == 0xD8) {
      return 'jpeg (real)';
    }
    // PNG
    if (chunk.length >= 4 &&
        b0 == 0x89 &&
        chunk[1] == 0x50 &&
        chunk[2] == 0x4E &&
        chunk[3] == 0x47) {
      return 'png';
    }
    return 'unknown (0x${b0.toRadixString(16).padLeft(2, '0')})';
  }

  Future<void> _handleFileRequest(HttpRequest request, String token) async {
    final route = _routes[token];

    // Caller-supplied byte sources share this route so they get the same
    // HTTP/1.0 framing and byte-range handling local files get — that is what
    // DLNA renderers need, and Chromecast and AirPlay accept it too.
    if (route != null && route.type == _RouteType.source) {
      final socket = await request.response.detachSocket(writeHeaders: false);
      try {
        await Http10FileServer.serveSource(socket, route.source!, request);
      } catch (e) {
        final message = e.toString();
        final clientAborted =
            message.contains('Connection reset by peer') ||
            message.contains('Broken pipe');
        if (clientAborted) {
          CastLogger.debug('MediaProxy: client closed the connection: $e');
        } else {
          CastLogger.error('MediaProxy: source serve error: $e');
        }
      } finally {
        try {
          await socket.close();
        } catch (_) {}
      }
      return;
    }

    if (route == null || route.type != _RouteType.localFile) {
      request.response.statusCode = HttpStatus.notFound;
      _addCorsHeaders(request.response, request.headers.value('Origin'));
      await request.response.close();
      return;
    }

    final file = File(route.url);
    if (!await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      _addCorsHeaders(request.response, request.headers.value('Origin'));
      await request.response.close();
      return;
    }

    // For subtitle files served to Chromecast (via HLS), convert SRT→VTT.
    // For DLNA, serve as-is (DLNA TVs handle SRT/VTT natively).
    // Detection: Chromecast requests come via /stream/ routes with HLS,
    // while DLNA requests come via /file/ routes. Since we're in the
    // /file/ handler, check if this is a subtitle and serve it raw via
    // HTTP/1.0 for DLNA compatibility. Non-subtitle files fall through
    // to the HTTP/1.0 file server below.
    if (_isSubtitleFile(route.url)) {
      var content = await file.readAsString();

      CastLogger.debug(
        'MediaProxy: local subtitle file (${content.length} chars, '
        'isSrt=${SubtitleConverter.isSrt(content)})',
      );

      // Convert SRT→VTT for non-DLNA consumers (Chromecast needs VTT)
      if (SubtitleConverter.isSrt(content)) {
        content = SubtitleConverter.srtToVtt(content);
        CastLogger.debug('MediaProxy: converted local SRT → VTT');
      }

      if (content.contains('X-TIMESTAMP-MAP')) {
        content = SubtitleConverter.stripTimestampMap(content);
      }

      // Serve subtitles via HTTP/1.1 with CORS — Chromecast's Shaka Player
      // requires Access-Control-Allow-Origin. DLNA TVs don't fetch subtitles
      // via sidecar URLs anyway, so HTTP/1.1 is fine here.
      final encoded = utf8.encode(content);
      final isVtt = content.trimLeft().startsWith('WEBVTT');
      _addCorsHeaders(request.response, request.headers.value('Origin'));
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType(
        'text',
        isVtt ? 'vtt' : 'srt',
      );
      request.response.contentLength = encoded.length;
      if (request.method != 'HEAD') {
        request.response.add(encoded);
      }
      await request.response.close();
      return;
    }

    final contentType = _contentTypeForPath(route.url);

    // Handle virtual segment requests (?start=X&end=Y) from HLS playlists.
    // These use Dart's normal HTTP/1.1 response (Chromecast handles it fine).
    final startParam = request.uri.queryParameters['start'];
    final endParam = request.uri.queryParameters['end'];
    if (startParam != null && endParam != null) {
      final start = int.parse(startParam);
      final end = int.parse(endParam);
      final segmentLength = end - start + 1;

      final patPmt = (start > 0) ? _tsPatPmt : null;
      final patPmtLength = patPmt?.length ?? 0;
      final totalLength = segmentLength + patPmtLength;

      CastLogger.debug(
        'MediaProxy: serving virtual segment bytes $start-$end '
        '($segmentLength bytes${patPmtLength > 0 ? ' + ${patPmtLength}B PAT/PMT' : ''})',
      );

      request.response.statusCode = HttpStatus.ok;
      request.response.contentLength = totalLength;

      if (patPmt != null) {
        request.response.add(patPmt);
      }

      final raf = await file.open();
      try {
        await raf.setPosition(start);
        final bytes = await raf.read(segmentLength);
        request.response.add(bytes);
      } finally {
        await raf.close();
      }
      await request.response.close();
      return;
    }

    // For all other file requests (DLNA, direct play), use raw HTTP/1.0
    // response. Some DLNA renderers (TCL Google TV) reject HTTP/1.1.
    // Detach the socket from Dart's HttpServer and write HTTP/1.0 manually.
    final socket = await request.response.detachSocket(writeHeaders: false);
    try {
      await Http10FileServer.serve(
        socket,
        file,
        request,
        contentType: contentType,
      );
    } catch (e) {
      // A renderer that seeks, buffers ahead or opens several connections
      // routinely abandons one mid-body. "Connection reset by peer" and
      // "Broken pipe" are that, not a server fault — logging them as errors
      // buries real failures under noise during normal playback.
      final message = e.toString();
      final clientAborted =
          message.contains('Connection reset by peer') ||
          message.contains('Broken pipe');
      if (clientAborted) {
        CastLogger.debug('MediaProxy: client closed the connection: $e');
      } else {
        CastLogger.error('MediaProxy: raw socket file serve error: $e');
      }
    } finally {
      await socket.close();
    }
  }

  bool _isSubtitleFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.srt') || lower.endsWith('.vtt');
  }

  bool _isSubtitleResponse(String url, ContentType? contentType) {
    final lower = url.toLowerCase();
    if (lower.contains('.srt') || lower.contains('.vtt')) return true;
    if (contentType != null) {
      final mimeType =
          '${contentType.primaryType}/${contentType.subType}'.toLowerCase();
      if (mimeType.contains('subrip') || mimeType == 'text/vtt') return true;
    }
    return false;
  }

  bool _isHlsResponse(String url, ContentType? contentType) {
    // Check URL extension
    if (url.contains('.m3u8') || url.contains('.m3u')) return true;

    // Check content type
    if (contentType != null) {
      final mimeType =
          '${contentType.primaryType}/${contentType.subType}'.toLowerCase();
      if (mimeType.contains('mpegurl') || mimeType.contains('x-mpegurl')) {
        return true;
      }
    }

    return false;
  }

  ContentType _contentTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.m3u8') || lower.endsWith('.m3u')) {
      return ContentType('application', 'x-mpegURL');
    }
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.m4s')) {
      return ContentType('video', 'mp4');
    }
    if (lower.endsWith('.ts')) {
      return ContentType('video', 'mp2t');
    }
    if (lower.endsWith('.mkv')) {
      return ContentType('video', 'x-matroska');
    }
    if (lower.endsWith('.vtt')) {
      return ContentType('text', 'vtt');
    }
    if (lower.endsWith('.srt')) {
      return ContentType('application', 'x-subrip');
    }
    if (lower.endsWith('.aac')) {
      return ContentType('audio', 'aac');
    }
    return ContentType('application', 'octet-stream');
  }

  /// Returns a short, log-friendly summary of a (possibly nested) proxied
  /// URL. Strips query strings, base64-looking blobs, and trims the result
  /// so a single log line stays readable.
  static String _summarizeUrl(String url) {
    try {
      final decoded = Uri.decodeFull(url);
      // Strip query string — segment URLs from upstream extractors often
      // embed a base64 header bundle that adds 600+ chars of noise.
      final qIdx = decoded.indexOf('?');
      final stripped = qIdx > 0 ? decoded.substring(0, qIdx) : decoded;
      return stripped.length > 160
          ? '${stripped.substring(0, 160)}…'
          : stripped;
    } catch (_) {
      return url.length > 160 ? '${url.substring(0, 160)}…' : url;
    }
  }

  /// Adds CORS headers to a response. When [requestOrigin] is provided the
  /// header `Access-Control-Allow-Origin` echoes it back instead of `*` —
  /// the Cast Application Framework rejects wildcard ACAO when the LOAD
  /// includes `tracks` (subtitles), so echoing the receiver's Origin is
  /// required for any HLS response, segment, or subtitle that may be
  /// fetched while subtitles are present in the LOAD message.
  ///
  /// Reference: developers.google.com/cast/docs/web_sender/advanced —
  /// CORS section requires specific origin (not *), and:
  ///   - Allow-Headers must include `Content-Type, Accept-Encoding, Range`
  ///   - Allow-Methods must include `GET, POST, OPTIONS`
  ///   - Expose-Headers must include `Content-Length, Content-Range`
  void _addCorsHeaders(HttpResponse response, [String? requestOrigin]) {
    response.headers.set(
      'Access-Control-Allow-Origin',
      (requestOrigin != null && requestOrigin.isNotEmpty) ? requestOrigin : '*',
    );
    response.headers.set('Vary', 'Origin');
    response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, POST, HEAD, OPTIONS',
    );
    response.headers.set(
      'Access-Control-Allow-Headers',
      'Range, Content-Type, Accept, Accept-Encoding, Origin',
    );
    response.headers.set(
      'Access-Control-Expose-Headers',
      'Content-Length, Content-Range, Accept-Ranges',
    );
  }
}
