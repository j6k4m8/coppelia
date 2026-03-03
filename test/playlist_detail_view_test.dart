import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coppelia/models/download_task.dart';
import 'package:coppelia/models/media_item.dart';
import 'package:coppelia/ui/widgets/playlist_detail_view.dart';

MediaItem _track(String id) {
  return MediaItem(
    id: id,
    title: 'Track $id',
    album: 'Album',
    artists: const ['Artist'],
    duration: const Duration(minutes: 3),
    imageUrl: null,
    streamUrl: 'https://example.com/audio/$id.mp3',
  );
}

void main() {
  group('derivePlaylistOfflineActionState', () {
    test('returns disabled make state for empty playlist', () {
      final state = derivePlaylistOfflineActionState(
        playlistTracks: const [],
        pinnedAudio: const {},
        downloadQueue: const [],
      );

      expect(state.canDownload, isFalse);
      expect(state.label, 'Make Available Offline');
      expect(state.tooltip, 'Make Available Offline');
      expect(state.icon, Icons.download_rounded);
    });

    test('returns pending state when a related download is queued', () {
      final track = _track('1');
      final state = derivePlaylistOfflineActionState(
        playlistTracks: [track],
        pinnedAudio: {track.streamUrl},
        downloadQueue: [
          DownloadTask(
            track: track,
            status: DownloadStatus.queued,
            queuedAt: DateTime(2026, 1, 1),
          ),
        ],
      );

      expect(state.isOfflinePending, isTrue);
      expect(state.label, 'Making Available Offline...');
      expect(state.tooltip, 'Cancel Offline Request');
      expect(state.icon, Icons.download_rounded);
    });

    test('returns retry state when related downloads are failed only', () {
      final track = _track('2');
      final state = derivePlaylistOfflineActionState(
        playlistTracks: [track],
        pinnedAudio: const {},
        downloadQueue: [
          DownloadTask(
            track: track,
            status: DownloadStatus.failed,
            queuedAt: DateTime(2026, 1, 1),
            errorMessage: 'Network error',
          ),
        ],
      );

      expect(state.hasFailedDownloads, isTrue);
      expect(state.isOfflinePending, isFalse);
      expect(state.label, 'Retry Offline Download');
      expect(state.tooltip, 'Retry Offline Download');
    });

    test('returns remove state when all tracks pinned and no downloads', () {
      final first = _track('3');
      final second = _track('4');
      final state = derivePlaylistOfflineActionState(
        playlistTracks: [first, second],
        pinnedAudio: {first.streamUrl, second.streamUrl},
        downloadQueue: const [],
      );

      expect(state.isOfflineReady, isTrue);
      expect(state.label, 'Remove from Offline');
      expect(state.tooltip, 'Remove from Offline');
      expect(state.icon, Icons.download_done_rounded);
    });

    test('ignores unrelated downloads when deriving playlist state', () {
      final playlistTrack = _track('5');
      final unrelatedTrack = _track('other');
      final state = derivePlaylistOfflineActionState(
        playlistTracks: [playlistTrack],
        pinnedAudio: const {},
        downloadQueue: [
          DownloadTask(
            track: unrelatedTrack,
            status: DownloadStatus.downloading,
            queuedAt: DateTime(2026, 1, 1),
          ),
        ],
      );

      expect(state.isOfflinePending, isFalse);
      expect(state.hasFailedDownloads, isFalse);
      expect(state.label, 'Make Available Offline');
    });
  });
}
