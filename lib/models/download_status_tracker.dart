import 'download_progress.dart';

/// Tracks the independent progress of video, audio, and subtitle streams.
class DownloadStatusTracker {
  DownloadProgress? _videoProgress;
  final List<DownloadProgress> _audioProgresses = [];
  final List<DownloadProgress> _subtitleProgresses = [];
  DownloadProgress? _currentStatus;

  // Video progress.
  DownloadProgress? get videoProgress => _videoProgress;

  // Audio stream progress.
  List<DownloadProgress> get audioProgresses =>
      List.unmodifiable(_audioProgresses);

  // Subtitle stream progress.
  List<DownloadProgress> get subtitleProgresses =>
      List.unmodifiable(_subtitleProgresses);

  // Current post-processing state, such as muxing, cleanup, or completion.
  DownloadProgress? get currentStatus => _currentStatus;

  // Retained for backward compatibility.
  DownloadProgress? get audioProgress =>
      _audioProgresses.isNotEmpty ? _audioProgresses.first : null;

  // Overall progress based on completed segments.
  double get overallProgress {
    if (_currentStatus?.type == 'done') {
      return 100.0;
    }

    if (_currentStatus?.type == 'muxing' ||
        _currentStatus?.type == 'cleaning') {
      return 95.0; // Download finished; post-processing is in progress.
    }

    // Sum completed and total segments across all streams.
    int totalCompletedSegments = 0;
    int totalSegments = 0;

    if (_videoProgress != null) {
      totalCompletedSegments += _videoProgress!.currentSegment;
      totalSegments += _videoProgress!.totalSegments;
    }

    // Include every audio stream.
    for (final audioProgress in _audioProgresses) {
      totalCompletedSegments += audioProgress.currentSegment;
      totalSegments += audioProgress.totalSegments;
    }

    // Include every subtitle stream.
    for (final subtitleProgress in _subtitleProgresses) {
      totalCompletedSegments += subtitleProgress.currentSegment;
      totalSegments += subtitleProgress.totalSegments;
    }

    if (totalSegments == 0) {
      return 0.0;
    }

    return (totalCompletedSegments / totalSegments) * 100;
  }

  // Human-readable status description.
  String get statusDescription {
    if (_currentStatus != null) {
      switch (_currentStatus!.type) {
        case 'muxing':
          return _currentStatus!.message ?? 'Muxing...';
        case 'cleaning':
          return 'Cleaning temporary files...';
        case 'done':
          return 'Download complete';
        default:
          return _currentStatus!.message ?? '';
      }
    }

    List<String> descriptions = [];

    if (_videoProgress != null) {
      descriptions.add(
        'Video: ${_videoProgress!.percentage.toStringAsFixed(1)}%',
      );
    }

    if (_audioProgresses.isNotEmpty) {
      final audioCount = _audioProgresses.length;
      final avgAudioProgress = _audioProgresses.isEmpty
          ? 0.0
          : _audioProgresses.map((a) => a.percentage).reduce((a, b) => a + b) /
                _audioProgresses.length;
      descriptions.add(
        'Audio ($audioCount): ${avgAudioProgress.toStringAsFixed(1)}%',
      );
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
        'Subtitles ($subtitleCount): '
        '${avgSubtitleProgress.toStringAsFixed(1)}%',
      );
    }

    if (descriptions.isEmpty) {
      return 'Preparing download...';
    }

    return descriptions.join(' | ');
  }

  // Update progress.
  void updateProgress(DownloadProgress progress) {
    switch (progress.type) {
      case 'video':
        _videoProgress = progress;
        _currentStatus = null; // Clear post-processing state while downloading.
        break;
      case 'audio':
        // Update the matching audio stream when it already exists.
        final existingIndex = _audioProgresses.indexWhere(
          (a) => a.quality == progress.quality,
        );
        if (existingIndex != -1) {
          _audioProgresses[existingIndex] = progress;
        } else {
          _audioProgresses.add(progress);
        }
        _currentStatus = null; // Clear post-processing state while downloading.
        break;
      case 'subtitle':
        // Update the matching subtitle stream when it already exists.
        final existingIndex = _subtitleProgresses.indexWhere(
          (s) => s.quality == progress.quality,
        );
        if (existingIndex != -1) {
          _subtitleProgresses[existingIndex] = progress;
        } else {
          _subtitleProgresses.add(progress);
        }
        _currentStatus = null; // Clear post-processing state while downloading.
        break;
      case 'muxing':
      case 'cleaning':
      case 'done':
        _currentStatus = progress;
        break;
    }
  }

  // Reset all state.
  void reset() {
    _videoProgress = null;
    _audioProgresses.clear();
    _subtitleProgresses.clear();
    _currentStatus = null;
  }

  // Whether processing has completed.
  bool get isCompleted => _currentStatus?.type == 'done';

  // Whether post-processing is in progress.
  bool get isPostProcessing =>
      _currentStatus?.type == 'muxing' || _currentStatus?.type == 'cleaning';

  // Detailed progress data for presentation.
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
          .map(
            (audio) => {
              'quality': audio.quality,
              'progress': '${audio.currentSegment}/${audio.totalSegments}',
              'percentage': audio.percentage,
              'size': audio.downloadedSize,
              'eta': audio.eta,
            },
          )
          .toList(),
      'subtitles': _subtitleProgresses
          .map(
            (subtitle) => {
              'quality': subtitle.quality,
              'progress':
                  '${subtitle.currentSegment}/${subtitle.totalSegments}',
              'percentage': subtitle.percentage,
              'size': subtitle.downloadedSize,
              'eta': subtitle.eta,
            },
          )
          .toList(),
      'status': _currentStatus?.message,
      'overall_progress': overallProgress,
      'status_description': statusDescription,
    };
  }
}
