class DownloadProgress {
  final String type; // 'video', 'audio', 'muxing', 'cleaning', 'done'
  final String quality; // '1920x1080' 或 'English | eng | 2CH'
  final int currentSegment; // 当前片段 21
  final int totalSegments; // 总片段 96
  final double percentage; // 进度百分比 21.88
  final String downloadedSize; // 已下载 201.03MB
  final String totalSize; // 总大小 919.0MB
  final String speed; // 下载速度 16.13MBps
  final String eta; // 预计剩余时间 00:01:07
  final String? message; // 额外信息，用于合并状态等

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

  // 创建合并状态的进度
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

  // 创建清理状态的进度
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

  // 创建完成状态的进度
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
