import 'media_item.dart';

/// Status for an in-progress or queued download.
enum DownloadStatus {
  /// Waiting to be downloaded.
  queued,

  /// Blocked by Wi-Fi-only rules.
  waitingForWifi,

  /// Currently downloading.
  downloading,

  /// Download failed.
  failed,
}

/// Represents a queued audio download with progress metadata.
class DownloadTask {
  /// Creates a download task.
  const DownloadTask({
    required this.track,
    required this.status,
    required this.queuedAt,
    this.requiresWifi = false,
    this.progress,
    this.totalBytes,
    this.downloadedBytes,
    this.errorMessage,
  });

  /// Track to download.
  final MediaItem track;

  /// Current status.
  final DownloadStatus status;

  /// Download progress from 0-1, when available.
  final double? progress;

  /// Total bytes for the download, when known.
  final int? totalBytes;

  /// Bytes downloaded so far, when known.
  final int? downloadedBytes;

  /// Optional error message.
  final String? errorMessage;

  /// Timestamp when the task was enqueued.
  final DateTime queuedAt;

  /// True when this task can only run on Wi-Fi.
  final bool requiresWifi;

  /// Returns a copy with updated values.
  DownloadTask copyWith({
    DownloadStatus? status,
    double? progress,
    int? totalBytes,
    int? downloadedBytes,
    String? errorMessage,
    bool? requiresWifi,
  }) {
    return DownloadTask(
      track: track,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      errorMessage: errorMessage ?? this.errorMessage,
      queuedAt: queuedAt,
      requiresWifi: requiresWifi ?? this.requiresWifi,
    );
  }
}
