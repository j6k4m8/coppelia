import 'cast_media.dart';
import 'media_proxy.dart';

/// Result of transforming media for casting.
class TransformedMedia {
  /// The proxy URL pointing to the (possibly transformed) media.
  final String proxyUrl;

  /// The effective media type after transformation.
  ///
  /// May differ from the original — e.g., `mpegTs` becomes `hls` after
  /// wrapping in an HLS playlist.
  final CastMediaType effectiveType;

  const TransformedMedia({required this.proxyUrl, required this.effectiveType});
}

/// Transforms [CastMedia] into a proxy URL ready for casting.
///
/// Implementations handle registering media with the proxy, converting formats,
/// and wrapping content as needed for the target device.
///
/// Built-in implementations:
/// - [DefaultMediaTransformer] — registers with proxy, serves local files directly
/// - [TsHlsMediaTransformer] — extends Default, wraps local TS files in HLS
///
/// To add custom logic (e.g., transcoding, custom segmentation), implement
/// this interface and pass it when creating a session.
///
/// ```dart
/// class MyTransformer implements MediaTransformer {
///   @override
///   Future<TransformedMedia> transform(CastMedia media, MediaProxy proxy) async {
///     final url = proxy.registerFile(media.url);
///     return TransformedMedia(proxyUrl: url, effectiveType: media.type);
///   }
/// }
/// ```
abstract class MediaTransformer {
  /// Transforms [media] using [proxy] and returns the result.
  ///
  /// The [proxy] is already started when this is called.
  Future<TransformedMedia> transform(CastMedia media, MediaProxy proxy);
}

/// Default transformer that handles common casting scenarios.
///
/// - Registers remote URLs and local files with the proxy
/// - Wraps remote MPEG-TS in HLS when [wrapRemoteTs] is `true`
/// - Serves local files directly (all types) via proxy
/// - Passes through other formats unchanged
///
/// For local MPEG-TS files that need HLS wrapping (e.g., Chromecast),
/// use [TsHlsMediaTransformer] instead, which extends this class and
/// adds local-TS-to-HLS conversion with keyframe-aligned segments.
class DefaultMediaTransformer implements MediaTransformer {
  /// Whether to wrap remote MPEG-TS URLs in HLS.
  ///
  /// Default `false` — remote TS is passed through unchanged.
  /// Set to `true` for devices like Chromecast that can't play raw TS at all.
  final bool wrapRemoteTs;

  const DefaultMediaTransformer({this.wrapRemoteTs = false});

  @override
  Future<TransformedMedia> transform(CastMedia media, MediaProxy proxy) async {
    // Register media with proxy
    // A caller-supplied byte source is served like a local file — same
    // route, same byte-range support — so it works on every protocol.
    final source = media.source;
    final proxyUrl =
        source != null
            ? proxy.registerSource(source, fileExtension: media.fileExtension)
            : media.isLocalFile
            ? proxy.registerFile(media.url)
            : proxy.registerMedia(media.url, headers: media.httpHeaders);

    var effectiveType = media.type;

    // Wrap remote MPEG-TS in HLS for devices that need it (like Chromecast).
    // Local files are served directly — use TsHlsMediaTransformer for
    // local TS→HLS wrapping.
    if (media.type == CastMediaType.mpegTs &&
        wrapRemoteTs &&
        !media.isLocalFile) {
      final durationSecs =
          media.duration?.inMilliseconds != null
              ? media.duration!.inMilliseconds / 1000.0
              : null;

      final hlsUrl = proxy.wrapInHlsPlaylist(proxyUrl, duration: durationSecs);
      return TransformedMedia(
        proxyUrl: hlsUrl,
        effectiveType: CastMediaType.hls,
      );
    }

    return TransformedMedia(proxyUrl: proxyUrl, effectiveType: effectiveType);
  }
}
