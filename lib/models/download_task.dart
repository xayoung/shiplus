/// 下载任务状态枚举
enum DownloadStatus {
  pending, // 等待中
  downloading, // 下载中
  completed, // 已完成
  failed, // 失败
  cancelled, // 已取消
}

/// 下载任务模型
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

  /// 复制并修改部分属性
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

  /// 获取状态显示文本
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

  /// 获取状态颜色
  int get statusColor {
    switch (status) {
      case DownloadStatus.pending:
        return 0xFF9E9E9E; // 灰色
      case DownloadStatus.downloading:
        return 0xFF2196F3; // 蓝色
      case DownloadStatus.completed:
        return 0xFF4CAF50; // 绿色
      case DownloadStatus.failed:
        return 0xFFF44336; // 红色
      case DownloadStatus.cancelled:
        return 0xFF9E9E9E; // 灰色
    }
  }

  /// 是否可以重试
  bool get canRetry {
    return status == DownloadStatus.failed ||
        status == DownloadStatus.cancelled;
  }

  /// 是否可以取消
  bool get canCancel {
    return status == DownloadStatus.pending ||
        status == DownloadStatus.downloading;
  }
}
