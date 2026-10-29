import 'dart:io';

import 'cast_media.dart';
import 'media_proxy.dart';
import 'media_transformer.dart';
import 'ts_keyframe_scanner.dart';

/// Media transformer that wraps local MPEG-TS files in HLS playlists.
///
/// Extends [DefaultMediaTransformer] to add local-TS-to-HLS conversion,
/// which is needed for Chromecast (its Default Media Receiver cannot play
/// raw TS). Remote media and non-TS local files are delegated to the
/// parent class unchanged.
///
/// ## Known limitations
///
/// - **Per-segment buffering:** The Chromecast buffers each virtual HLS
///   segment independently, which can cause brief pauses at segment
///   boundaries on slow storage or high-bitrate files.
///
/// - **Subtitle drift:** VBR content may accumulate small timing errors
///   between PTS-based segment durations and actual subtitle timestamps,
///   especially in long files (>2 hours).
///
/// - **Slow seeking:** Seeking to a position far from the current one
///   requires the Chromecast to download and parse all intervening
///   segment headers, which can take several seconds on large files.
///
/// - **PTS offset sensitivity:** TS files with non-zero starting PTS
///   (common in broadcast recordings) rely on accurate PTS extraction.
///   If the first video PES packet is damaged or uses an unusual stream
///   ID, the offset may be wrong, causing A/V desync.
///
/// - **HEVC incompatibility:** The Chromecast Default Media Receiver does
///   not support HEVC (H.265) in HLS. Files encoded with HEVC will fail
///   to play even after wrapping. Use H.264 for local TS casting.
class TsHlsMediaTransformer extends DefaultMediaTransformer {
  /// Creates a [TsHlsMediaTransformer].
  ///
  /// [wrapRemoteTs] controls whether remote TS URLs are also wrapped in
  /// HLS (passed to [DefaultMediaTransformer]). Defaults to `true`.
  const TsHlsMediaTransformer({super.wrapRemoteTs = true});

  @override
  Future<TransformedMedia> transform(CastMedia media, MediaProxy proxy) async {
    // Only handle local MPEG-TS files; delegate everything else to super.
    if (!media.isLocalFile || media.type != CastMediaType.mpegTs) {
      return super.transform(media, proxy);
    }

    // Register the local file with the proxy.
    final fileProxyUrl = proxy.registerFile(media.url);
    final file = File(media.url);

    // Extract PAT/PMT packets so the proxy can prepend them to each
    // virtual HLS segment (required for Chromecast's TS demuxer).
    final patPmt = TsKeyframeScanner.extractPatPmt(file);
    if (patPmt != null) {
      proxy.setPatPmt(patPmt);
    }

    final durationSecs =
        media.duration?.inMilliseconds != null
            ? media.duration!.inMilliseconds / 1000.0
            : null;

    // Always use chunked HLS with keyframe-aligned segments.
    // Falls back to single-segment if the file has ≤1 keyframe.
    final proxyUrl = proxy.wrapLocalFileAsHls(
      fileProxyUrl,
      media.url,
      totalDuration: durationSecs,
    );

    return TransformedMedia(
      proxyUrl: proxyUrl,
      effectiveType: CastMediaType.hls,
    );
  }
}
