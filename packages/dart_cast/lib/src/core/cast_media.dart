import 'media_source.dart';

/// Media type for casting.
enum CastMediaType {
  /// HTTP Live Streaming (m3u8 playlist with TS/fMP4 segments).
  hls,

  /// MP4 container (H.264/AAC). Best Chromecast compatibility.
  mp4,

  /// Matroska container. Supports embedded SRT/ASS subtitle tracks.
  /// Recommended for DLNA casting with subtitles.
  mkv,

  /// Raw MPEG Transport Stream.
  mpegTs,

  /// Audio-only media such as MP3, AAC, FLAC, or WAV.
  audio,
}

/// Represents a subtitle track for cast media.
class CastSubtitle {
  /// URL of the subtitle file.
  final String url;

  /// Human-readable label (e.g., "English").
  final String label;

  /// Language code (e.g., "en").
  final String language;

  /// Subtitle format (e.g., "vtt", "srt").
  final String format;

  /// Creates a [CastSubtitle].
  const CastSubtitle({
    required this.url,
    required this.label,
    required this.language,
    required this.format,
  });
}

/// Represents media to be cast to a device.
class CastMedia {
  /// URL of the media content (HTTP URL or local file path).
  ///
  /// For local files, [isLocalFile] will be `true` and the URL will be
  /// the absolute file path without any `file://` prefix.
  final String url;

  /// Type of the media content.
  final CastMediaType type;

  /// Whether this media is a local file (vs. a remote HTTP URL).
  final bool isLocalFile;

  /// Extension appended to the served URL for [CastMedia.source], e.g. `.mp4`.
  final String? fileExtension;

  /// Optional MIME type override for the receiver.
  final String? contentType;

  /// Bytes supplied by the application rather than read from [url].
  ///
  /// Set by [CastMedia.source] for content this package cannot open itself —
  /// Android `content://` URIs, Flutter assets, decrypted bytes. When present
  /// the proxy serves these bytes and [url] is ignored.
  final MediaSource? source;

  /// HTTP headers to include when fetching the media (remote URLs only).
  final Map<String, String> httpHeaders;

  /// Optional title for the media.
  final String? title;

  /// Optional image/thumbnail URL.
  final String? imageUrl;

  /// Optional start position for playback.
  final Duration? startPosition;

  /// Optional known duration of the media.
  ///
  /// For local files, providing this enables accurate HLS segment splitting
  /// so the cast device reports correct playback progress.
  final Duration? duration;

  /// Whether the receiver should begin playback immediately after loading.
  final bool autoPlay;

  /// Subtitle tracks for this media.
  final List<CastSubtitle> subtitles;

  /// The subtitle track to start active, or null for no subtitles.
  ///
  /// Match one of [subtitles] by URL. Receivers used to activate the FIRST
  /// track when none was named, which silently made the track-list *order*
  /// choose the on-screen language — a French-first list produced French
  /// subtitles on a TV whose user wanted English. No default means no
  /// track is activated.
  final CastSubtitle? defaultSubtitle;

  /// Creates a [CastMedia] for a remote URL.
  const CastMedia({
    required this.url,
    required this.type,
    this.httpHeaders = const {},
    this.title,
    this.imageUrl,
    this.startPosition,
    this.duration,
    this.autoPlay = true,
    this.subtitles = const [],
    this.defaultSubtitle,
    this.contentType,
  }) : isLocalFile = false,
       source = null,
       fileExtension = null;

  /// Creates a [CastMedia] for a local file.
  ///
  /// [filePath] should be the absolute path to the file (e.g., `/path/to/video.ts`).
  /// [duration] should be provided if known — it enables accurate HLS segmentation.
  /// The proxy will serve it over HTTP so the cast device can access it.
  const CastMedia.file({
    required String filePath,
    required this.type,
    this.title,
    this.imageUrl,
    this.startPosition,
    this.duration,
    this.autoPlay = true,
    this.subtitles = const [],
    this.defaultSubtitle,
    this.fileExtension,
    this.contentType,
  }) : url = filePath,
       isLocalFile = true,
       source = null,
       httpHeaders = const {};

  /// Creates a [CastMedia] backed by application-supplied bytes.
  ///
  /// Use for content the package cannot open itself — an Android
  /// `content://` URI, a Flutter asset, decrypted bytes. The proxy serves
  /// [source] with byte-range support, so seeking works exactly as it does
  /// for a local file, on Chromecast, DLNA and AirPlay alike.
  ///
  /// [fileExtension] is appended to the served URL (e.g. `.mp4`); many
  /// renderers sniff it to choose a demuxer, so supply it when known.
  const CastMedia.source(
    MediaSource this.source, {
    required this.type,
    this.fileExtension,
    this.title,
    this.imageUrl,
    this.startPosition,
    this.duration,
    this.autoPlay = true,
    this.subtitles = const [],
    this.defaultSubtitle,
    this.contentType,
  }) : url = '',
       isLocalFile = false,
       httpHeaders = const {};
}
