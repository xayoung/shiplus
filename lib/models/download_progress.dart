class DownloadProgress {
  final String type; // 'video', 'audio', 'muxing', 'cleaning', 'done'
  final String quality; // For example, '1920x1080' or 'English | eng | 2CH'.
  final int currentSegment;
  final int totalSegments;
  final double percentage;
  final String downloadedSize;
  final String totalSize;
  final String speed;
  final String eta;
  final String? message; // Additional information for post-processing states.

  DownloadProgress({
    required this.type,
    required this.quality,
    required this.currentSegment,
    required this.totalSegments,
    required this.percentage,
    required this.downloadedSize,
    required this.totalSize,
    required this.speed,
    required this.eta,
    this.message,
  });

  // Create a muxing progress state.
  factory DownloadProgress.muxing(String message) {
    return DownloadProgress(
      type: 'muxing',
      quality: '',
      currentSegment: 0,
      totalSegments: 0,
      percentage: 0.0,
      downloadedSize: '',
      totalSize: '',
      speed: '',
      eta: '',
      message: message,
    );
  }

  // Create a cleanup progress state.
  factory DownloadProgress.cleaning() {
    return DownloadProgress(
      type: 'cleaning',
      quality: '',
      currentSegment: 0,
      totalSegments: 0,
      percentage: 0.0,
      downloadedSize: '',
      totalSize: '',
      speed: '',
      eta: '',
      message: 'Cleaning files...',
    );
  }

  // Create a completed progress state.
  factory DownloadProgress.done(String fileName) {
    return DownloadProgress(
      type: 'done',
      quality: '',
      currentSegment: 0,
      totalSegments: 0,
      percentage: 100.0,
      downloadedSize: '',
      totalSize: '',
      speed: '',
      eta: '',
      message: 'Done: $fileName',
    );
  }
}
