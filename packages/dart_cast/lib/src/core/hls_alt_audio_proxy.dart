/// HLS layer on top of [TsAltAudioRemuxer].
///
/// Builds synthetic master + variant playlists that look like a plain
/// muxed-audio HLS stream to a Cast receiver, while internally pairing
/// each segment with its matching audio rendition segment and remuxing
/// the two on the fly.
///
/// Architecture:
///   - On registration we fetch the upstream master playlist, pick one
///     video variant (highest bandwidth) and one audio rendition
///     (caller-chosen by language, fallback DEFAULT=YES, fallback first).
///   - We then fetch the *variant* playlist and the *audio rendition*
///     playlist and extract their segment URLs in parallel order. HLS
///     guarantees synchronised segment timing across renditions of the
///     same group (RFC 8216 §6.2.4), so segment N of the video stream
///     pairs with segment N of the audio stream by index.
///   - The synthetic master we serve to the receiver has a single
///     `EXT-X-STREAM-INF` declaring both codecs, no `EXT-X-MEDIA AUDIO`,
///     pointing to a synthetic variant playlist URL.
///   - The synthetic variant playlist has one `EXTINF`/URI pair per
///     segment, pointing to a `/muxed-seg/<token>/<index>.ts` URL.
///   - When the receiver fetches a muxed-segment URL, the proxy fetches
///     both the video and audio source segments and runs them through
///     [TsAltAudioRemuxer].
///
/// All HTTP fetching uses the registered upstream headers (Origin,
/// Referer, User-Agent etc.) so authorised CDN sources keep working.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'hls_parser.dart';
import 'ts_alt_audio_remuxer.dart';
import '../utils/logger.dart';

/// Snapshot of the upstream HLS structure captured at registration
/// time. Owned by a [MediaProxy] route; the proxy uses this to answer
/// playlist + muxed-segment fetches from the receiver.
class HlsAltAudioPlan {
  /// Original upstream master playlist URL (kept for debugging).
  final String upstreamMasterUrl;

  /// Headers to send to upstream fetches.
  final Map<String, String> upstreamHeaders;

  /// CODECS attribute to advertise to the receiver. We keep both video
  /// and audio codecs from the variant's CODECS attribute (e.g.
  /// `"avc1.4D4828,mp4a.40.2"`).
  final String codecs;

  /// Optional resolution to advertise (`WIDTHxHEIGHT`).
  final String? resolution;

  /// Bandwidth to advertise.
  final int bandwidth;

  /// Ordered list of (video segment URL, audio segment URL, duration sec).
  final List<HlsAltAudioSegmentPair> segments;

  const HlsAltAudioPlan({
    required this.upstreamMasterUrl,
    required this.upstreamHeaders,
    required this.codecs,
    required this.resolution,
    required this.bandwidth,
    required this.segments,
  });
}

class HlsAltAudioSegmentPair {
  final String videoUrl;
  final String audioUrl;
  final double durationSec;

  const HlsAltAudioSegmentPair({
    required this.videoUrl,
    required this.audioUrl,
    required this.durationSec,
  });
}

/// Builder that fetches an upstream master + chosen variant/rendition
/// playlists, then produces an [HlsAltAudioPlan].
class HlsAltAudioPlanner {
  final HttpClient _http;

  HlsAltAudioPlanner({HttpClient? httpClient})
    : _http = httpClient ?? HttpClient();

  /// Fetches and analyses the upstream master at [masterUrl]. Picks the
  /// highest-bandwidth video variant. Picks audio rendition matching
  /// [preferredAudioLanguage] (BCP-47 / common language code), falling
  /// back to `DEFAULT=YES` rendition, then to the first one.
  ///
  /// Returns null if the master doesn't describe an alternate-audio
  /// HLS layout we can handle (e.g. media playlist, no AUDIO group).
  Future<HlsAltAudioPlan?> plan({
    required String masterUrl,
    required Map<String, String> headers,
    String? preferredAudioLanguage,
  }) async {
    final masterContent = await _fetchString(masterUrl, headers);
    if (!HlsParser.isMasterPlaylist(masterContent)) {
      CastLogger.debug(
        'HlsAltAudioPlanner: $masterUrl is not a master playlist — '
        'alt-audio remuxer skipped',
      );
      return null;
    }

    final variants = HlsParser.extractVariants(masterContent, masterUrl);
    if (variants.isEmpty) {
      CastLogger.debug('HlsAltAudioPlanner: no variants in master — skipped');
      return null;
    }

    final variant = variants.first; // highest bandwidth (already sorted)
    final audioGroup = variant.audioGroup;
    if (audioGroup == null || audioGroup.isEmpty) {
      CastLogger.debug(
        'HlsAltAudioPlanner: variant has no AUDIO group — not alt-audio HLS',
      );
      return null;
    }

    final renditions = HlsParser.extractAudioRenditions(
      masterContent,
      masterUrl,
    );
    final usableRenditions =
        renditions
            .where((r) => r.groupId == audioGroup && r.uri != null)
            .toList();
    if (usableRenditions.isEmpty) {
      CastLogger.debug(
        'HlsAltAudioPlanner: AUDIO group "$audioGroup" has no renditions '
        'with URIs — not alt-audio HLS',
      );
      return null;
    }

    final pickedRendition = _pickRendition(
      usableRenditions,
      preferredAudioLanguage,
    );
    CastLogger.debug(
      'HlsAltAudioPlanner: picked variant bandwidth=${variant.bandwidth} '
      '+ audio rendition "${pickedRendition.name}" '
      '(group=${pickedRendition.groupId})',
    );

    // Fetch the two playlists in parallel.
    final variantUrl = variant.url;
    final audioUrl = pickedRendition.uri!;
    final results = await Future.wait([
      _fetchString(variantUrl, headers),
      _fetchString(audioUrl, headers),
    ]);
    final videoSegments = HlsParser.extractSegmentUrls(results[0], variantUrl);
    final audioSegments = HlsParser.extractSegmentUrls(results[1], audioUrl);

    if (videoSegments.isEmpty) {
      CastLogger.warning(
        'HlsAltAudioPlanner: variant playlist has 0 segments — abort',
      );
      return null;
    }
    if (audioSegments.length != videoSegments.length) {
      CastLogger.warning(
        'HlsAltAudioPlanner: audio rendition has ${audioSegments.length} '
        'segments but video has ${videoSegments.length} — segments will '
        'be paired by index (mismatch may cause AV drift)',
      );
    }

    // Parse durations from the variant playlist's #EXTINF lines.
    final durations = _extractDurations(results[0]);

    final pairs = <HlsAltAudioSegmentPair>[];
    for (var i = 0; i < videoSegments.length; i++) {
      pairs.add(
        HlsAltAudioSegmentPair(
          videoUrl: videoSegments[i],
          audioUrl:
              i < audioSegments.length ? audioSegments[i] : audioSegments.last,
          durationSec: i < durations.length ? durations[i] : 6.0,
        ),
      );
    }

    // CODECS — keep whatever the master advertised. The synthesised
    // single muxed stream genuinely carries both codecs, so this is
    // accurate.
    final codecs = _extractCodecs(masterContent) ?? 'avc1.4D4028,mp4a.40.2';
    final resolution = _extractResolution(masterContent);

    return HlsAltAudioPlan(
      upstreamMasterUrl: masterUrl,
      upstreamHeaders: headers,
      codecs: codecs,
      resolution: resolution,
      bandwidth: variant.bandwidth,
      segments: pairs,
    );
  }

  static ({String groupId, String name, String? uri, bool isDefault})
  _pickRendition(
    List<({String groupId, String name, String? uri, bool isDefault})>
    renditions,
    String? preferredLanguage,
  ) {
    if (preferredLanguage != null && preferredLanguage.isNotEmpty) {
      final lower = preferredLanguage.toLowerCase();
      for (final r in renditions) {
        if (r.name.toLowerCase().contains(lower)) return r;
      }
    }
    for (final r in renditions) {
      if (r.isDefault) return r;
    }
    return renditions.first;
  }

  static List<double> _extractDurations(String mediaPlaylist) {
    final out = <double>[];
    final re = RegExp(r'^#EXTINF:([0-9]+(?:\.[0-9]+)?)', multiLine: true);
    for (final m in re.allMatches(mediaPlaylist)) {
      out.add(double.tryParse(m.group(1)!) ?? 6.0);
    }
    return out;
  }

  static String? _extractCodecs(String masterPlaylist) {
    final re = RegExp(r'CODECS="([^"]*)"');
    final m = re.firstMatch(masterPlaylist);
    return m?.group(1);
  }

  static String? _extractResolution(String masterPlaylist) {
    final re = RegExp(r'RESOLUTION=(\d+x\d+)');
    final m = re.firstMatch(masterPlaylist);
    return m?.group(1);
  }

  Future<String> _fetchString(String url, Map<String, String> headers) async {
    final req = await _http.openUrl('GET', Uri.parse(url));
    for (final e in headers.entries) {
      req.headers.set(e.key, e.value);
    }
    final res = await req.close();
    final bytes = await res.fold<List<int>>(<int>[], (a, c) => a..addAll(c));
    return utf8.decode(bytes);
  }

  Future<List<int>> _fetchBytes(String url, Map<String, String> headers) async {
    final req = await _http.openUrl('GET', Uri.parse(url));
    for (final e in headers.entries) {
      req.headers.set(e.key, e.value);
    }
    final res = await req.close();
    final out = <int>[];
    await for (final chunk in res) {
      out.addAll(chunk);
    }
    return out;
  }

  /// Public byte-fetch helper used by the proxy when assembling muxed
  /// segments. Re-uses the planner's HttpClient + header propagation.
  Future<List<int>> fetchSegmentBytes(
    String url,
    Map<String, String> headers,
  ) => _fetchBytes(url, headers);

  /// Closes the underlying HttpClient — call once the muxed route is
  /// torn down.
  void close() {
    _http.close(force: true);
  }
}

/// Synthesised HLS playlist text built from a [HlsAltAudioPlan].
class HlsAltAudioPlaylistRenderer {
  /// Synthetic master that the receiver loads first. Single variant,
  /// no alt-audio, accurate `CODECS`. The variant URL points to the
  /// proxy's synthetic variant playlist.
  static String renderMaster({
    required HlsAltAudioPlan plan,
    required String variantPlaylistUrl,
  }) {
    final resolution =
        plan.resolution != null ? ',RESOLUTION=${plan.resolution}' : '';
    return '#EXTM3U\n'
        '#EXT-X-VERSION:3\n'
        '#EXT-X-INDEPENDENT-SEGMENTS\n'
        '#EXT-X-STREAM-INF:BANDWIDTH=${plan.bandwidth},'
        'CODECS="${plan.codecs}"$resolution\n'
        '$variantPlaylistUrl\n';
  }

  /// Synthetic variant playlist whose segments are the proxy's
  /// per-segment muxed endpoints, one per source video/audio pair.
  static String renderVariant({
    required HlsAltAudioPlan plan,
    required String Function(int segmentIndex) muxedSegmentUrlFor,
  }) {
    final buf =
        StringBuffer()
          ..writeln('#EXTM3U')
          ..writeln('#EXT-X-VERSION:3')
          ..writeln('#EXT-X-PLAYLIST-TYPE:VOD');
    final maxTarget = plan.segments
        .map((s) => s.durationSec.ceil())
        .fold<int>(0, (a, b) => b > a ? b : a);
    buf.writeln('#EXT-X-TARGETDURATION:${maxTarget == 0 ? 6 : maxTarget}');
    buf.writeln('#EXT-X-MEDIA-SEQUENCE:0');
    for (var i = 0; i < plan.segments.length; i++) {
      buf.writeln('#EXTINF:${plan.segments[i].durationSec},');
      buf.writeln(muxedSegmentUrlFor(i));
    }
    buf.writeln('#EXT-X-ENDLIST');
    return buf.toString();
  }
}

/// Fetches one source segment pair, remuxes via [TsAltAudioRemuxer],
/// returns the combined bytes ready for streaming back to the receiver.
class HlsAltAudioSegmentMuxer {
  final HlsAltAudioPlanner _planner;

  HlsAltAudioSegmentMuxer({required HlsAltAudioPlanner planner})
    : _planner = planner;

  Future<RemuxedSegment> muxSegment({
    required HlsAltAudioPlan plan,
    required int segmentIndex,
  }) async {
    if (segmentIndex < 0 || segmentIndex >= plan.segments.length) {
      throw RangeError(
        'segmentIndex $segmentIndex out of range '
        '(0..${plan.segments.length - 1})',
      );
    }
    final pair = plan.segments[segmentIndex];

    // Fetch both source segments in parallel.
    final byteResults = await Future.wait([
      _planner.fetchSegmentBytes(pair.videoUrl, plan.upstreamHeaders),
      _planner.fetchSegmentBytes(pair.audioUrl, plan.upstreamHeaders),
    ]);

    final muxed = TsAltAudioRemuxer.mux(
      videoSegment: byteResults[0],
      audioSegment: byteResults[1],
    );
    CastLogger.debug(
      'HlsAltAudioSegmentMuxer: segment $segmentIndex muxed → $muxed',
    );
    return muxed;
  }
}
