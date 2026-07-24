/// Download task states.
enum DownloadStatus { pending, downloading, completed, failed, cancelled }

/// A download task.
class DownloadTask {
  final String id;
  final String url;
  final String title;
  final String fileName;
  final DownloadStatus status;
  final double progress;
  final String? error;
  final DateTime createdAt;
  final DateTime? completedAt;

  const DownloadTask({
    required this.id,
    required this.url,
    required this.title,
    required this.fileName,
    required this.status,
    this.progress = 0.0,
    this.error,
    required this.createdAt,
    this.completedAt,
  });

  /// Returns a copy with selected fields replaced.
  DownloadTask copyWith({
    String? id,
    String? url,
    String? title,
    String? fileName,
    DownloadStatus? status,
    double? progress,
    String? error,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      fileName: fileName ?? this.fileName,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Human-readable status text.
  String get statusText {
    switch (status) {
      case DownloadStatus.pending:
        return 'pending';
      case DownloadStatus.downloading:
        return 'downloading';
      case DownloadStatus.completed:
        return 'completed';
      case DownloadStatus.failed:
        return 'failed';
      case DownloadStatus.cancelled:
        return 'cancelled';
    }
  }

  /// Status color.
  int get statusColor {
    switch (status) {
      case DownloadStatus.pending:
        return 0xFF9E9E9E; // Gray.
      case DownloadStatus.downloading:
        return 0xFF2196F3; // Blue.
      case DownloadStatus.completed:
        return 0xFF4CAF50; // Green.
      case DownloadStatus.failed:
        return 0xFFF44336; // Red.
      case DownloadStatus.cancelled:
        return 0xFF9E9E9E; // Gray.
    }
  }

  /// Whether the task can be retried.
  bool get canRetry {
    return status == DownloadStatus.failed ||
        status == DownloadStatus.cancelled;
  }

  /// Whether the task can be cancelled.
  bool get canCancel {
    return status == DownloadStatus.pending ||
        status == DownloadStatus.downloading;
  }
}
