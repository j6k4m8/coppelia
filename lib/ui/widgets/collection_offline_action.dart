import 'package:flutter/material.dart';

import '../../models/download_task.dart';
import '../../models/media_item.dart';

/// Offline action shared by album, artist, and playlist headers.
class CollectionOfflineActionState {
  const CollectionOfflineActionState({
    required this.canDownload,
    required this.isOfflineReady,
    required this.isOfflinePending,
    required this.hasFailedDownloads,
  });

  factory CollectionOfflineActionState.forTracks({
    required List<MediaItem> tracks,
    required bool Function(MediaItem track) isTrackPinned,
    required List<DownloadTask> downloadQueue,
  }) {
    final urls = tracks.map((track) => track.streamUrl).toSet();
    final downloads = downloadQueue
        .where((task) => urls.contains(task.track.streamUrl))
        .toList();
    return CollectionOfflineActionState(
      canDownload: tracks.isNotEmpty,
      isOfflineReady:
          tracks.isNotEmpty && tracks.every(isTrackPinned) && downloads.isEmpty,
      isOfflinePending:
          downloads.any((task) => task.status != DownloadStatus.failed),
      hasFailedDownloads:
          downloads.any((task) => task.status == DownloadStatus.failed),
    );
  }

  final bool canDownload;
  final bool isOfflineReady;
  final bool isOfflinePending;
  final bool hasFailedDownloads;

  String get label =>
      isOfflinePending ? 'Making Available Offline...' : tooltip;

  String get tooltip => isOfflinePending
      ? 'Cancel Offline Request'
      : isOfflineReady
          ? 'Remove from Offline'
          : hasFailedDownloads
              ? 'Retry Offline Download'
              : 'Make Available Offline';

  IconData get icon =>
      isOfflineReady ? Icons.download_done_rounded : Icons.download_rounded;
}
