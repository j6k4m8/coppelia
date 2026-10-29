/// HLS playlist parser with URL rewriting for proxy support.
///
/// Handles both master (multivariant) and media playlists per RFC 8216.
class HlsParser {
  HlsParser._();

  /// Tags where the URI appears on the next line (Pattern A).
  static const _nextLineUriTags = ['#EXT-X-STREAM-INF:', '#EXTINF:'];

  /// Tags where the URI is a quoted attribute (Pattern B).
  static const _attributeUriTags = [
    '#EXT-X-KEY:',
    '#EXT-X-MAP:',
    '#EXT-X-MEDIA:',
    '#EXT-X-I-FRAME-STREAM-INF:',
    '#EXT-X-SESSION-KEY:',
    '#EXT-X-SESSION-DATA:',
  ];

  /// Regex matching `URI="<value>"` attribute in a tag line.
  static final _uriAttributeRegex = RegExp(r'URI="([^"]*)"');

  /// Detects whether [content] is a master (multivariant) playlist.
  ///
  /// Returns true if it contains `#EXT-X-STREAM-INF` or
  /// `#EXT-X-I-FRAME-STREAM-INF`.
  static bool isMasterPlaylist(String content) {
    return content.contains('#EXT-X-STREAM-INF') ||
        content.contains('#EXT-X-I-FRAME-STREAM-INF');
  }

  /// Resolves [url] against [baseUrl] per RFC 3986.
  ///
  /// Handles absolute URLs, protocol-relative, absolute-path, and
  /// relative-path references.
  static String resolveUrl(String url, String baseUrl) {
    // Absolute URL — has scheme
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    final base = Uri.parse(baseUrl);

    // Protocol-relative
    if (url.startsWith('//')) {
      return '${base.scheme}:$url';
    }

    // Absolute path
    if (url.startsWith('/')) {
      return '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}$url';
    }

    // Relative path — resolve against base
    return base.resolve(url).toString();
  }

  /// Rewrites all URLs in an HLS playlist to go through the proxy.
  ///
  /// [content] is the raw m3u8 text.
  /// [baseUrl] is the URL from which the playlist was fetched.
  /// [proxyBaseUrl] is the proxy server's base URL (e.g. `http://192.168.1.5:8234`).
  /// [token] is the proxy route token for this media session.
  ///
  /// ## URL extension hinting
  ///
  /// The Chromecast Default Media Receiver / Shaka Player consults the URL
  /// *path extension* during `MediaCapabilities.decodingInfo()` probing —
  /// not just the response `Content-Type`. Sources whose segment URLs end
  /// in something other than `.ts` (e.g. `.jpg`-obfuscated TS) silently
  /// fail the probe and trigger `LOAD_FAILED` with no diagnostic detail.
  ///
  /// To work around that, segment URLs (next-line URIs after `#EXTINF`) are
  /// rewritten to `/stream/<token>/seg<n>.ts?url=…`. The fake `.ts` segment
  /// in the path satisfies the receiver's extension probe; the upstream
  /// URL is preserved in the `?url=` query string. Variant playlist URIs
  /// (next-line URIs after `#EXT-X-STREAM-INF`) and attribute-style URIs
  /// (`URI="…"` on `#EXT-X-MEDIA`, etc.) keep the plain
  /// `/stream/<token>?url=…` form because their extension shouldn't
  /// affect playback.
  static String rewritePlaylist(
    String content,
    String baseUrl,
    String proxyBaseUrl,
    String token,
  ) {
    final lines = content.split('\n');
    final result = <String>[];
    var expectUri = false;
    var expectSegment = false; // true between #EXTINF and its URI
    var segmentIndex = 0;

    for (final line in lines) {
      // Empty lines pass through
      if (line.trim().isEmpty) {
        result.add(line);
        continue;
      }

      // Check Pattern A: tags where next line is the URI
      if (_isNextLineUriTag(line)) {
        result.add(line);
        expectUri = true;
        expectSegment = line.startsWith('#EXTINF:');
        continue;
      }

      // #EXT-X-BYTERANGE can appear between #EXTINF and the segment URI
      if (line.startsWith('#EXT-X-BYTERANGE:') && expectUri) {
        result.add(line);
        continue;
      }

      // Check Pattern B: tags with URI="..." attribute
      if (_isAttributeUriTag(line)) {
        result.add(_rewriteUriAttribute(line, baseUrl, proxyBaseUrl, token));
        continue;
      }

      // Non-tag, non-empty line while expecting URI — this is a segment/variant URI
      if (expectUri && !line.startsWith('#')) {
        final resolved = resolveUrl(line.trim(), baseUrl);
        if (expectSegment) {
          segmentIndex++;
          result.add(
            _buildSegmentProxyUrl(proxyBaseUrl, token, resolved, segmentIndex),
          );
        } else {
          result.add(_buildProxyUrl(proxyBaseUrl, token, resolved));
        }
        expectUri = false;
        expectSegment = false;
        continue;
      }

      // Any other line (tags, comments)
      result.add(line);
      expectUri = false;
      expectSegment = false;
    }

    return result.join('\n');
  }

  static bool _isNextLineUriTag(String line) {
    for (final tag in _nextLineUriTags) {
      if (line.startsWith(tag)) return true;
    }
    return false;
  }

  static bool _isAttributeUriTag(String line) {
    for (final tag in _attributeUriTags) {
      if (line.startsWith(tag)) return true;
    }
    return false;
  }

  /// Rewrites the `URI="..."` attribute in a tag line.
  static String _rewriteUriAttribute(
    String line,
    String baseUrl,
    String proxyBaseUrl,
    String token,
  ) {
    final match = _uriAttributeRegex.firstMatch(line);
    if (match == null) {
      return line; // No URI attribute (e.g. #EXT-X-MEDIA without URI)
    }

    final originalUri = match.group(1)!;
    final resolved = resolveUrl(originalUri, baseUrl);
    final proxied = _buildProxyUrl(proxyBaseUrl, token, resolved);
    return line.replaceFirst('URI="$originalUri"', 'URI="$proxied"');
  }

  /// Extract segment URLs from a media playlist.
  ///
  /// Parses `#EXTINF` lines and collects the next-line URIs,
  /// resolving them against [baseUrl].
  static List<String> extractSegmentUrls(String content, String baseUrl) {
    final lines = content.split('\n');
    final segments = <String>[];
    var expectUri = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('#EXTINF:')) {
        expectUri = true;
        continue;
      }

      // #EXT-X-BYTERANGE can appear between #EXTINF and the segment URI
      if (trimmed.startsWith('#EXT-X-BYTERANGE:') && expectUri) {
        continue;
      }

      if (expectUri && !trimmed.startsWith('#')) {
        segments.add(resolveUrl(trimmed, baseUrl));
        expectUri = false;
        continue;
      }

      if (trimmed.startsWith('#')) {
        // Other tags reset expectUri unless it's a byterange
        if (!trimmed.startsWith('#EXT-X-BYTERANGE:')) {
          expectUri = false;
        }
        continue;
      }

      expectUri = false;
    }

    return segments;
  }

  /// Extracts segment URLs together with their `#EXTINF` durations.
  ///
  /// Same parsing rules as [extractSegmentUrls], but each entry also carries
  /// the segment's declared duration in seconds. A segment whose `#EXTINF`
  /// cannot be parsed gets `0.0`, which keeps the list aligned with
  /// [extractSegmentUrls] rather than silently dropping entries.
  static List<({String url, double duration})> extractSegments(
    String content,
    String baseUrl,
  ) {
    final lines = content.split('\n');
    final segments = <({String url, double duration})>[];
    var expectUri = false;
    var pendingDuration = 0.0;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('#EXTINF:')) {
        expectUri = true;
        // "#EXTINF:10.5,title" — the duration ends at the comma.
        final value = trimmed.substring('#EXTINF:'.length).split(',').first;
        pendingDuration = double.tryParse(value.trim()) ?? 0.0;
        continue;
      }

      if (trimmed.startsWith('#EXT-X-BYTERANGE:') && expectUri) {
        continue;
      }

      if (expectUri && !trimmed.startsWith('#')) {
        segments.add((
          url: resolveUrl(trimmed, baseUrl),
          duration: pendingDuration,
        ));
        expectUri = false;
        pendingDuration = 0.0;
        continue;
      }

      if (trimmed.startsWith('#')) {
        if (!trimmed.startsWith('#EXT-X-BYTERANGE:')) {
          expectUri = false;
        }
        continue;
      }

      expectUri = false;
    }

    return segments;
  }

  /// Whether [content] is a complete (VOD) playlist rather than a live one.
  ///
  /// Only a playlist ending in `#EXT-X-ENDLIST` has a total duration that
  /// will not change, so only those can be advertised to a renderer.
  static bool isCompletePlaylist(String content) =>
      content.contains('#EXT-X-ENDLIST');

  /// Total duration of a media playlist, or null when it cannot be trusted.
  ///
  /// Returns null for live playlists (no `#EXT-X-ENDLIST`) and for playlists
  /// with no parseable `#EXTINF` durations. DLNA renderers use this to show a
  /// scrub bar; advertising a duration that later changes is worse than
  /// advertising none.
  static Duration? totalDuration(String content) {
    if (!isCompletePlaylist(content)) return null;

    var seconds = 0.0;
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('#EXTINF:')) continue;
      final value = trimmed.substring('#EXTINF:'.length).split(',').first;
      seconds += double.tryParse(value.trim()) ?? 0.0;
    }

    if (seconds <= 0) return null;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  /// Given a master playlist, extract variant playlist URLs sorted by
  /// bandwidth (highest first).
  ///
  /// Each variant also carries the `AUDIO="<group-id>"` attribute when
  /// present — that's the link to a separate audio rendition declared via
  /// `EXT-X-MEDIA:TYPE=AUDIO`. A non-null `audioGroup` means the variant
  /// playlist is video-only and audio lives in a separate playlist.
  static List<({String url, int bandwidth, String? audioGroup})>
  extractVariants(String content, String baseUrl) {
    final lines = content.split('\n');
    final variants = <({String url, int bandwidth, String? audioGroup})>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        // Extract BANDWIDTH
        final bwMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
        final bandwidth = bwMatch != null ? int.parse(bwMatch.group(1)!) : 0;

        // Extract AUDIO group reference, if present.
        final audioMatch = RegExp(r'AUDIO="([^"]*)"').firstMatch(line);
        final audioGroup = audioMatch?.group(1);

        // Next non-empty, non-comment line is the URI
        for (var j = i + 1; j < lines.length; j++) {
          final nextLine = lines[j].trim();
          if (nextLine.isEmpty) continue;
          if (nextLine.startsWith('#')) continue;
          variants.add((
            url: resolveUrl(nextLine, baseUrl),
            bandwidth: bandwidth,
            audioGroup: audioGroup,
          ));
          break;
        }
      }
    }

    // Sort by bandwidth descending (highest quality first)
    variants.sort((a, b) => b.bandwidth.compareTo(a.bandwidth));
    return variants;
  }

  /// Parsed alternate audio rendition (`EXT-X-MEDIA:TYPE=AUDIO`).
  ///
  /// Multiple renditions can share a `groupId` (e.g. one per language)
  /// and the variant in `EXT-X-STREAM-INF` selects which group plays via
  /// its `AUDIO=` attribute.
  static List<({String groupId, String name, String? uri, bool isDefault})>
  extractAudioRenditions(String content, String baseUrl) {
    final renditions =
        <({String groupId, String name, String? uri, bool isDefault})>[];

    final groupRe = RegExp(r'GROUP-ID="([^"]*)"');
    final nameRe = RegExp(r'NAME="([^"]*)"');
    final defaultRe = RegExp(r'DEFAULT=(YES|NO)');

    for (final raw in content.split('\n')) {
      final line = raw.trim();
      if (!line.startsWith('#EXT-X-MEDIA:')) continue;
      if (!line.contains('TYPE=AUDIO')) continue;

      final groupId = groupRe.firstMatch(line)?.group(1);
      final name = nameRe.firstMatch(line)?.group(1);
      final uriMatch = _uriAttributeRegex.firstMatch(line);
      final uri =
          uriMatch != null ? resolveUrl(uriMatch.group(1)!, baseUrl) : null;
      final isDefault = defaultRe.firstMatch(line)?.group(1) == 'YES';

      renditions.add((
        groupId: groupId ?? '',
        name: name ?? '',
        uri: uri,
        isDefault: isDefault,
      ));
    }

    return renditions;
  }

  /// Constructs a proxy URL for the given original URL.
  static String _buildProxyUrl(
    String proxyBaseUrl,
    String token,
    String originalUrl,
  ) {
    return '$proxyBaseUrl/stream/$token?url=${Uri.encodeComponent(originalUrl)}';
  }

  /// Constructs a segment proxy URL whose *path* ends in `.ts`, satisfying
  /// the Chromecast / Shaka URL-extension capability probe even when the
  /// upstream URL ends in `.jpg`, `.bin`, or another non-media extension.
  static String _buildSegmentProxyUrl(
    String proxyBaseUrl,
    String token,
    String originalUrl,
    int segmentIndex,
  ) {
    return '$proxyBaseUrl/stream/$token/seg$segmentIndex.ts'
        '?url=${Uri.encodeComponent(originalUrl)}';
  }
}
