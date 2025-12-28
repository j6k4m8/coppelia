import 'media_item.dart';

/// Snapshot of playback for resuming later.
class PlaybackResumeState {
  /// Creates a playback resume snapshot.
  const PlaybackResumeState({
    required this.track,
    required this.position,
  });

  /// Track that was last playing.
  final MediaItem track;

  /// Last known playback position.
  final Duration position;

  /// Serializes the resume snapshot.
  Map<String, dynamic> toJson() => {
        'track': track.toJson(),
        'positionMs': position.inMilliseconds,
      };

  /// Restores a resume snapshot from JSON.
  static PlaybackResumeState? fromJson(Map<String, dynamic> json) {
    final trackJson = json['track'] as Map<String, dynamic>?;
    if (trackJson == null) {
      return null;
    }
    final positionMs = json['positionMs'] as int? ?? 0;
    return PlaybackResumeState(
      track: MediaItem.fromJson(trackJson),
      position: Duration(milliseconds: positionMs),
    );
  }
}
