/// Chromecast media channel message builders and parsers.
///
/// Handles the `urn:x-cast:com.google.cast.media` namespace for
/// media playback control: load, play, pause, stop, seek, volume,
/// subtitle track selection, and status parsing.
library;

import 'dart:convert';

/// Represents a subtitle track for Chromecast LOAD commands.
class CastMediaTrack {
  /// Unique track identifier (must be > 0).
  final int trackId;

  /// URL of the track content (e.g., WebVTT file).
  final String url;

  /// Human-readable track name.
  final String name;

  /// BCP-47 language code.
  final String language;

  /// Creates a [CastMediaTrack].
  const CastMediaTrack({
    required this.trackId,
    required this.url,
    required this.name,
    required this.language,
  });

  /// Converts to a Chromecast track JSON object.
  Map<String, dynamic> toJson() => {
    'trackId': trackId,
    'type': 'TEXT',
    'subtype': 'SUBTITLES',
    'trackContentId': url,
    'trackContentType': 'text/vtt',
    'name': name,
    'language': language,
  };
}

/// Parsed media status from a MEDIA_STATUS message.
class MediaStatusInfo {
  /// The media session ID for subsequent commands.
  final int mediaSessionId;

  /// Current player state: IDLE, BUFFERING, PLAYING, PAUSED, LOADING.
  final String playerState;

  /// Current playback position in seconds.
  final double currentTime;

  /// Media duration in seconds, or null for live streams.
  final double? duration;

  /// Volume level (0.0 to 1.0).
  final double volumeLevel;

  /// Whether the media stream is muted.
  final bool isMuted;

  /// Reason for IDLE state (FINISHED, CANCELLED, INTERRUPTED, ERROR).
  final String? idleReason;

  /// Creates a [MediaStatusInfo].
  const MediaStatusInfo({
    required this.mediaSessionId,
    required this.playerState,
    required this.currentTime,
    this.duration,
    this.volumeLevel = 1.0,
    this.isMuted = false,
    this.idleReason,
  });
}

/// Builds and parses messages for Chromecast media control.
class CastMediaChannel {
  /// Media namespace.
  static const mediaNamespace = 'urn:x-cast:com.google.cast.media';

  /// Auto-incrementing request ID counter.
  int _requestId = 0;

  /// Returns the next request ID.
  int nextRequestId() => ++_requestId;

  // ---------------------------------------------------------------------------
  // Builders
  // ---------------------------------------------------------------------------

  /// Builds a LOAD command.
  ///
  /// [activeTrackIds] names the tracks that start active. Null or empty
  /// means playback starts with no subtitle shown. This used to default to
  /// the first subtitle track, which let the track-list order pick the
  /// language on the TV — the caller decides now.
  String buildLoad({
    required String contentId,
    required String contentType,
    String? title,
    String? imageUrl,
    double? startPosition,
    bool autoPlay = true,
    List<CastMediaTrack>? subtitles,
    List<int>? activeTrackIds,
    String streamType = 'BUFFERED',
  }) {
    final media = <String, dynamic>{
      'contentId': contentId,
      'contentType': contentType,
      'streamType': streamType,
    };

    // Metadata
    final metadata = <String, dynamic>{'metadataType': 0};
    if (title != null) metadata['title'] = title;
    if (imageUrl != null) {
      metadata['images'] = [
        {'url': imageUrl},
      ];
    }
    media['metadata'] = metadata;

    // Subtitle tracks
    if (subtitles != null && subtitles.isNotEmpty) {
      media['tracks'] = subtitles.map((t) => t.toJson()).toList();
    }

    final payload = <String, dynamic>{
      'type': 'LOAD',
      'requestId': nextRequestId(),
      'media': media,
      'autoplay': autoPlay,
      'currentTime': startPosition ?? 0,
    };

    if (activeTrackIds != null && activeTrackIds.isNotEmpty) {
      payload['activeTrackIds'] = activeTrackIds;
    }

    return jsonEncode(payload);
  }

  /// Builds a PLAY command.
  String buildPlay(int mediaSessionId) {
    return jsonEncode({
      'type': 'PLAY',
      'mediaSessionId': mediaSessionId,
      'requestId': nextRequestId(),
    });
  }

  /// Builds a PAUSE command.
  String buildPause(int mediaSessionId) {
    return jsonEncode({
      'type': 'PAUSE',
      'mediaSessionId': mediaSessionId,
      'requestId': nextRequestId(),
    });
  }

  /// Builds a STOP command (stops media, does not close the app).
  String buildStop(int mediaSessionId) {
    return jsonEncode({
      'type': 'STOP',
      'mediaSessionId': mediaSessionId,
      'requestId': nextRequestId(),
    });
  }

  /// Builds a SEEK command.
  String buildSeek(int mediaSessionId, double position) {
    return jsonEncode({
      'type': 'SEEK',
      'mediaSessionId': mediaSessionId,
      'currentTime': position,
      'requestId': nextRequestId(),
    });
  }

  /// Builds a SET_VOLUME command for the media stream.
  String buildSetVolume(int mediaSessionId, {double? level, bool? muted}) {
    final volume = <String, dynamic>{};
    if (level != null) volume['level'] = level;
    if (muted != null) volume['muted'] = muted;
    return jsonEncode({
      'type': 'SET_VOLUME',
      'mediaSessionId': mediaSessionId,
      'volume': volume,
      'requestId': nextRequestId(),
    });
  }

  /// Builds a GET_STATUS command.
  String buildGetStatus() {
    return jsonEncode({'type': 'GET_STATUS', 'requestId': nextRequestId()});
  }

  /// Builds an EDIT_TRACKS_INFO command for subtitle switching.
  String buildEditTracksInfo(int mediaSessionId, List<int> activeTrackIds) {
    return jsonEncode({
      'type': 'EDIT_TRACKS_INFO',
      'mediaSessionId': mediaSessionId,
      'activeTrackIds': activeTrackIds,
      'requestId': nextRequestId(),
    });
  }

  // ---------------------------------------------------------------------------
  // Parsers
  // ---------------------------------------------------------------------------

  /// Parses a MEDIA_STATUS payload.
  ///
  /// Returns null if no status entries are present.
  static MediaStatusInfo? parseMediaStatus(Map<String, dynamic> json) {
    final statusList = json['status'] as List?;
    if (statusList == null || statusList.isEmpty) return null;

    final status = statusList[0] as Map<String, dynamic>;
    final volume = status['volume'] as Map<String, dynamic>?;
    final media = status['media'] as Map<String, dynamic>?;

    return MediaStatusInfo(
      mediaSessionId: status['mediaSessionId'] as int,
      playerState: status['playerState'] as String,
      currentTime: (status['currentTime'] as num?)?.toDouble() ?? 0.0,
      duration: (media?['duration'] as num?)?.toDouble(),
      volumeLevel: (volume?['level'] as num?)?.toDouble() ?? 1.0,
      isMuted: (volume?['muted'] as bool?) ?? false,
      idleReason: status['idleReason'] as String?,
    );
  }
}
