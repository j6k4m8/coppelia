import 'dart:convert';
import 'dart:io';

import 'hls_alt_audio_proxy.dart';
import 'hls_parser.dart';
import 'ts_alt_audio_remuxer.dart';
import '../utils/logger.dart';

/// Handles fetching an HLS playlist and streaming its segments as a
/// continuous MPEG-TS byte stream.
///
/// Used by DLNA renderers that do not understand HLS — instead of
/// pointing the TV at an m3u8 URL, we resolve segments server-side and
/// concatenate them into a single `video/mp2t` response.
///
/// ## Alternate audio renditions
///
/// Sources whose master playlist declares `EXT-X-MEDIA:TYPE=AUDIO` with
/// matching variant `AUDIO="<group>"` reference are handled by routing
/// through [HlsAltAudioPlanner] + [TsAltAudioRemuxer]: each video
/// segment is fetched together with the chosen audio rendition's
/// segment, the pair is remuxed into a single TS, and the muxed bytes
/// are written to the response. The TV sees one continuous TS with
/// both streams just like a legacy muxed HLS source.
class HlsStreamHandler {
  final HttpClient _httpClient;

  /// Creates an [HlsStreamHandler] with an optional [HttpClient].
  HlsStreamHandler({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  /// Fetches the HLS playlist at [m3u8Url], resolves segments, and streams
  /// them sequentially into [response].
  ///
  /// If the playlist is a master playlist, the highest-bandwidth variant is
  /// selected automatically.
  ///
  /// [headers] are forwarded to all upstream requests (playlist + segments).
  ///
  /// [preferredAudioLanguage] is matched (case-insensitive substring)
  /// against each `EXT-X-MEDIA:TYPE=AUDIO` rendition's `NAME` attribute
  /// when the source uses alt-audio, falling back to `DEFAULT=YES` then
  /// the first rendition.
  /// Resolves [m3u8Url] and returns the total duration of the media it
  /// describes, or null when that cannot be determined.
  ///
  /// A DLNA renderer fed a piped TS has no way to work out how long the
  /// content is — there is no container header and no `Content-Length` — so it
  /// shows `00:00:01` and refuses to draw a scrub bar. Probing the playlist
  /// here lets the caller advertise the real duration in DIDL-Lite.
  ///
  /// Returns null for live playlists, whose duration is not fixed.
  Future<Duration?> probeDuration(
    String m3u8Url,
    Map<String, String> headers,
  ) async {
    try {
      var content = await _fetchString(m3u8Url, headers);

      if (HlsParser.isMasterPlaylist(content)) {
        final variants = HlsParser.extractVariants(content, m3u8Url);
        if (variants.isEmpty) return null;
        content = await _fetchString(variants.first.url, headers);
      }

      return HlsParser.totalDuration(content);
    } catch (e) {
      CastLogger.debug('HlsStreamHandler: duration probe failed: $e');
      return null;
    }
  }

  Future<void> streamAsTransportStream(
    String m3u8Url,
    Map<String, String> headers,
    HttpResponse response, {
    String? preferredAudioLanguage,
    Duration startAt = Duration.zero,
  }) async {
    try {
      final playlistContent = await _fetchString(m3u8Url, headers);

      // Alt-audio HLS — mux video + audio per segment, concatenate.
      if (HlsParser.isMasterPlaylist(playlistContent)) {
        final variants = HlsParser.extractVariants(playlistContent, m3u8Url);
        if (variants.isEmpty) {
          response.statusCode = HttpStatus.badGateway;
          await response.close();
          return;
        }

        final picked = variants.first;
        final audioGroup = picked.audioGroup;
        if (audioGroup != null && audioGroup.isNotEmpty) {
          final audioRenditions = HlsParser.extractAudioRenditions(
            playlistContent,
            m3u8Url,
          );
          final hasMatchingAudioPlaylist = audioRenditions.any(
            (r) => r.groupId == audioGroup && r.uri != null,
          );
          if (hasMatchingAudioPlaylist) {
            await _streamMuxedAltAudio(
              m3u8Url: m3u8Url,
              headers: headers,
              response: response,
              preferredAudioLanguage: preferredAudioLanguage,
            );
            return;
          }
        }

        // Single-stream master — fetch the chosen variant playlist and
        // fall through to the legacy concat path below.
        final mediaPlaylistContent = await _fetchString(picked.url, headers);
        await _streamConcatenated(
          mediaPlaylistUrl: picked.url,
          mediaPlaylistContent: mediaPlaylistContent,
          headers: headers,
          response: response,
          startAt: startAt,
        );
        return;
      }

      // Media playlist directly — concat its segments.
      await _streamConcatenated(
        mediaPlaylistUrl: m3u8Url,
        mediaPlaylistContent: playlistContent,
        headers: headers,
        response: response,
        startAt: startAt,
      );
    } catch (e, stack) {
      CastLogger.error(
        'HlsStreamHandler: failed to stream TS playlist: $e\n$stack',
      );
      try {
        response.statusCode = HttpStatus.badGateway;
        await response.close();
      } catch (_) {
        // Response may already be closed.
      }
    }
  }

  /// Concatenates a media playlist's segments to [response] as a single
  /// `video/mp2t` body. Used for the simple "all-muxed segments" case.
  Future<void> _streamConcatenated({
    required String mediaPlaylistUrl,
    required String mediaPlaylistContent,
    required Map<String, String> headers,
    required HttpResponse response,
    Duration startAt = Duration.zero,
  }) async {
    final segments = HlsParser.extractSegments(
      mediaPlaylistContent,
      mediaPlaylistUrl,
    );
    if (segments.isEmpty) {
      response.statusCode = HttpStatus.badGateway;
      await response.close();
      return;
    }

    // Seeking a piped TS is done by dropping whole segments: find the first
    // segment whose time range covers the requested offset and start there.
    // Byte ranges are meaningless here — the body is generated on the fly and
    // its length is not known in advance.
    final total = HlsParser.totalDuration(mediaPlaylistContent);
    var skipped = 0;
    var startSeconds = 0.0;
    if (startAt > Duration.zero) {
      final target = startAt.inMilliseconds / 1000.0;
      var elapsed = 0.0;
      for (final segment in segments) {
        if (elapsed + segment.duration > target) break;
        elapsed += segment.duration;
        skipped++;
      }
      startSeconds = elapsed;
      if (skipped >= segments.length) {
        // Seek past the end — nothing left to send.
        response.statusCode = HttpStatus.ok;
        response.headers.contentType = ContentType('video', 'mp2t');
        await response.close();
        return;
      }
      CastLogger.info(
        'HlsStreamHandler: time seek to ${target.toStringAsFixed(1)}s — '
        'skipping $skipped/${segments.length} segments, starting at '
        '${startSeconds.toStringAsFixed(1)}s',
      );
    }

    final segmentUrls = segments.skip(skipped).map((s) => s.url);

    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType('video', 'mp2t');
    // The stream is generated on demand: byte ranges cannot be honoured, but
    // time-based seeking can, so advertise exactly that.
    response.headers.set('Accept-Ranges', 'none');
    response.headers.set('Access-Control-Allow-Origin', '*');
    if (total != null) {
      final totalSeconds = total.inMilliseconds / 1000.0;
      response.headers.set(
        'TimeSeekRange.dlna.org',
        'npt=${startSeconds.toStringAsFixed(3)}-'
            '${totalSeconds.toStringAsFixed(3)}/'
            '${totalSeconds.toStringAsFixed(3)}',
      );
      response.headers.set(
        'X-Seek-Range',
        'npt=${startSeconds.toStringAsFixed(3)}-'
            '${totalSeconds.toStringAsFixed(3)}',
      );
    }

    for (final segmentUrl in segmentUrls) {
      try {
        final segUri = Uri.parse(segmentUrl);
        final segRequest = await _httpClient.openUrl('GET', segUri);
        for (final entry in headers.entries) {
          segRequest.headers.set(entry.key, entry.value);
        }
        final segResponse = await segRequest.close();
        if (segResponse.statusCode == HttpStatus.ok) {
          await for (final chunk in segResponse) {
            response.add(chunk);
          }
        } else {
          await segResponse.drain<void>();
        }
      } catch (_) {
        // Skip segments that fail to fetch.
      }
    }
    await response.close();
  }

  /// Fetches an alt-audio HLS plan, mux-then-writes each segment pair
  /// to [response] sequentially. The TV receives one continuous TS
  /// stream with both video and audio.
  Future<void> _streamMuxedAltAudio({
    required String m3u8Url,
    required Map<String, String> headers,
    required HttpResponse response,
    String? preferredAudioLanguage,
  }) async {
    final planner = HlsAltAudioPlanner(httpClient: _httpClient);
    final plan = await planner.plan(
      masterUrl: m3u8Url,
      headers: headers,
      preferredAudioLanguage: preferredAudioLanguage,
    );
    if (plan == null) {
      // Shouldn't happen — caller already verified alt-audio — but
      // handle defensively.
      response.statusCode = HttpStatus.badGateway;
      await response.close();
      return;
    }
    CastLogger.info(
      'HlsStreamHandler: streaming ${plan.segments.length} alt-audio '
      'segments as concatenated muxed TS',
    );

    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType('video', 'mp2t');
    response.headers.set('Accept-Ranges', 'none');
    response.headers.set('Access-Control-Allow-Origin', '*');

    final muxer = HlsAltAudioSegmentMuxer(planner: planner);
    for (var i = 0; i < plan.segments.length; i++) {
      try {
        final muxed = await muxer.muxSegment(plan: plan, segmentIndex: i);
        response.add(muxed.bytes);
      } catch (e) {
        CastLogger.warning(
          'HlsStreamHandler: skipping segment $i — mux failed: $e',
        );
        // Skip the segment rather than abort the whole response —
        // matches the behaviour of [_streamConcatenated].
      }
    }
    await response.close();
  }

  /// Fetches a URL and returns the body as a string.
  Future<String> _fetchString(String url, Map<String, String> headers) async {
    final uri = Uri.parse(url);
    final request = await _httpClient.openUrl('GET', uri);
    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
    final response = await request.close();
    final bytes = await response.fold<List<int>>(
      <int>[],
      (prev, chunk) => prev..addAll(chunk),
    );
    return utf8.decode(bytes);
  }

  /// Closes the underlying HTTP client.
  void close() {
    _httpClient.close(force: true);
  }
}
