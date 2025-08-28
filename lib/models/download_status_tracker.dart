import 'download_progress.dart';

/// 下载状态跟踪器，用于管理 Vid、Aud 和 Sub 的分别进度
class DownloadStatusTracker {
  DownloadProgress? _videoProgress;
  final List<DownloadProgress> _audioProgresses = [];
  final List<DownloadProgress> _subtitleProgresses = [];
  DownloadProgress? _currentStatus;

  // 获取视频进度
  DownloadProgress? get videoProgress => _videoProgress;

  // 获取音频进度列表
  List<DownloadProgress> get audioProgresses =>
      List.unmodifiable(_audioProgresses);

  // 获取字幕进度列表
  List<DownloadProgress> get subtitleProgresses =>
      List.unmodifiable(_subtitleProgresses);

  // 获取当前状态（合并、清理、完成等）
  DownloadProgress? get currentStatus => _currentStatus;

  // 为了向后兼容，保留单个音频进度的 getter
  DownloadProgress? get audioProgress =>
      _audioProgresses.isNotEmpty ? _audioProgresses.first : null;

  // 获取整体进度百分比（基于切片累加）
  double get overallProgress {
    if (_currentStatus?.type == 'done') {
      return 100.0;
    }

    if (_currentStatus?.type == 'muxing' ||
        _currentStatus?.type == 'cleaning') {
      return 95.0; // 下载完成，正在后处理
    }

    // 计算总的已完成切片和总切片数
    int totalCompletedSegments = 0;
    int totalSegments = 0;

    if (_videoProgress != null) {
      totalCompletedSegments += _videoProgress!.currentSegment;
      totalSegments += _videoProgress!.totalSegments;
    }

    // 添加所有音频进度
    for (final audioProgress in _audioProgresses) {
      totalCompletedSegments += audioProgress.currentSegment;
      totalSegments += audioProgress.totalSegments;
    }

    // 添加所有字幕进度
    for (final subtitleProgress in _subtitleProgresses) {
      totalCompletedSegments += subtitleProgress.currentSegment;
      totalSegments += subtitleProgress.totalSegments;
    }

    if (totalSegments == 0) {
      return 0.0;
    }

    return (totalCompletedSegments / totalSegments) * 100;
  }

  // 获取状态描述
  String get statusDescription {
    if (_currentStatus != null) {
      switch (_currentStatus!.type) {
        case 'muxing':
          return _currentStatus!.message ?? '正在合并...';
        case 'cleaning':
          return '正在清理临时文件...';
        case 'done':
          return '下载完成';
        default:
          return _currentStatus!.message ?? '';
      }
    }

    List<String> descriptions = [];

    if (_videoProgress != null) {
      descriptions.add('视频: ${_videoProgress!.percentage.toStringAsFixed(1)}%');
    }

    if (_audioProgresses.isNotEmpty) {
      final audioCount = _audioProgresses.length;
      final avgAudioProgress = _audioProgresses.isEmpty
          ? 0.0
          : _audioProgresses.map((a) => a.percentage).reduce((a, b) => a + b) /
              _audioProgresses.length;
      descriptions
          .add('音频($audioCount): ${avgAudioProgress.toStringAsFixed(1)}%');
    }

    if (_subtitleProgresses.isNotEmpty) {
      final subtitleCount = _subtitleProgresses.length;
      final avgSubtitleProgress = _subtitleProgresses.isEmpty
          ? 0.0
          : _subtitleProgresses
                  .map((s) => s.percentage)
                  .reduce((a, b) => a + b) /
              _subtitleProgresses.length;
      descriptions.add(
          '字幕($subtitleCount): ${avgSubtitleProgress.toStringAsFixed(1)}%');
    }

    if (descriptions.isEmpty) {
      return '准备下载...';
    }

    return descriptions.join(' | ');
  }

  // 更新进度
  void updateProgress(DownloadProgress progress) {
    switch (progress.type) {
      case 'video':
        _videoProgress = progress;
        _currentStatus = null; // 清除状态，表示正在下载
        break;
      case 'audio':
        // 查找是否已存在相同质量的音频进度
        final existingIndex = _audioProgresses.indexWhere(
          (a) => a.quality == progress.quality,
        );
        if (existingIndex != -1) {
          _audioProgresses[existingIndex] = progress;
        } else {
          _audioProgresses.add(progress);
        }
        _currentStatus = null; // 清除状态，表示正在下载
        break;
      case 'subtitle':
        // 查找是否已存在相同质量的字幕进度
        final existingIndex = _subtitleProgresses.indexWhere(
          (s) => s.quality == progress.quality,
        );
        if (existingIndex != -1) {
          _subtitleProgresses[existingIndex] = progress;
        } else {
          _subtitleProgresses.add(progress);
        }
        _currentStatus = null; // 清除状态，表示正在下载
        break;
      case 'muxing':
      case 'cleaning':
      case 'done':
        _currentStatus = progress;
        break;
    }
  }

  // 重置状态
  void reset() {
    _videoProgress = null;
    _audioProgresses.clear();
    _subtitleProgresses.clear();
    _currentStatus = null;
  }

  // 检查是否完成
  bool get isCompleted => _currentStatus?.type == 'done';

  // 检查是否正在后处理
  bool get isPostProcessing =>
      _currentStatus?.type == 'muxing' || _currentStatus?.type == 'cleaning';

  // 获取详细信息用于显示
  Map<String, dynamic> getDetailedInfo() {
    return {
      'video': _videoProgress != null
          ? {
              'quality': _videoProgress!.quality,
              'progress':
                  '${_videoProgress!.currentSegment}/${_videoProgress!.totalSegments}',
              'percentage': _videoProgress!.percentage,
              'size': _videoProgress!.downloadedSize,
              'eta': _videoProgress!.eta,
            }
          : null,
      'audios': _audioProgresses
          .map((audio) => {
                'quality': audio.quality,
                'progress': '${audio.currentSegment}/${audio.totalSegments}',
                'percentage': audio.percentage,
                'size': audio.downloadedSize,
                'eta': audio.eta,
              })
          .toList(),
      'subtitles': _subtitleProgresses
          .map((subtitle) => {
                'quality': subtitle.quality,
                'progress':
                    '${subtitle.currentSegment}/${subtitle.totalSegments}',
                'percentage': subtitle.percentage,
                'size': subtitle.downloadedSize,
                'eta': subtitle.eta,
              })
          .toList(),
      'status': _currentStatus?.message,
      'overall_progress': overallProgress,
      'status_description': statusDescription,
    };
  }
}
