import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/download_progress.dart';
import '../models/download_task.dart';
import '../models/download_status_tracker.dart';
import '../ffi/n_m3u8dl_re.dart';
import 'download_service.dart';

class GlobalDownloadManager extends ChangeNotifier {
  static final GlobalDownloadManager _instance =
      GlobalDownloadManager._internal();
  factory GlobalDownloadManager() => _instance;
  GlobalDownloadManager._internal();

  final List<DownloadTask> _downloadTasks = [];
  final Map<String, StreamController<String>> _logControllers = {};
  final Map<String, StreamController<DownloadProgress>> _progressControllers =
      {};
  final Map<String, DownloadStatusTracker> _statusTrackers = {};

  List<DownloadTask> get downloadTasks => List.unmodifiable(_downloadTasks);

  int get activeDownloadsCount => _downloadTasks
      .where((task) => task.status == DownloadStatus.downloading)
      .length;

  DownloadStatusTracker? getStatusTracker(String taskId) {
    return _statusTrackers[taskId];
  }

  Future<String> addDownloadTask({
    required String url,
    required String title,
    String? customFileName,
  }) async {
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    final fileName = customFileName ?? _sanitizeFileName(title);

    final task = DownloadTask(
      id: taskId,
      url: url,
      title: title,
      fileName: fileName,
      status: DownloadStatus.pending,
      createdAt: DateTime.now(),
    );

    _downloadTasks.add(task);
    _logControllers[taskId] = StreamController<String>.broadcast();
    _progressControllers[taskId] =
        StreamController<DownloadProgress>.broadcast();
    _statusTrackers[taskId] = DownloadStatusTracker();

    notifyListeners();

    _startDownload(taskId);

    return taskId;
  }

  Future<void> _startDownload(String taskId) async {
    final taskIndex = _downloadTasks.indexWhere((task) => task.id == taskId);
    if (taskIndex == -1) return;

    final task = _downloadTasks[taskIndex];
    _downloadTasks[taskIndex] = task.copyWith(
      status: DownloadStatus.downloading,
    );
    notifyListeners();

    try {
      final downloadPath = await DownloadService.getDownloadPath();

      _logControllers[taskId]?.add('🚀 Starting download: ${task.title}');
      _logControllers[taskId]?.add('📁 Save directory: $downloadPath');
      _logControllers[taskId]?.add('🔗 Video URL: ${task.url}');

      await DownloadService.downloadVideo(
        task.url,
        downloadPath,
        task.fileName,
        taskId: taskId,
        onLog: (log) {
          _logControllers[taskId]?.add(log);
        },
        onProgress: (progress) {
          _progressControllers[taskId]?.add(progress);

          final tracker = _statusTrackers[taskId];
          if (tracker != null) {
            tracker.updateProgress(progress);

            final taskIndex = _downloadTasks.indexWhere((t) => t.id == taskId);
            if (taskIndex != -1) {
              _downloadTasks[taskIndex] = _downloadTasks[taskIndex].copyWith(
                progress: tracker.overallProgress,
              );
              notifyListeners();
            }
          }
        },
      );

      final taskIndex = _downloadTasks.indexWhere((t) => t.id == taskId);
      if (taskIndex != -1) {
        _downloadTasks[taskIndex] = _downloadTasks[taskIndex].copyWith(
          status: DownloadStatus.completed,
          progress: 100.0,
          completedAt: DateTime.now(),
        );
        notifyListeners();
      }

      _logControllers[taskId]?.add('🎉 Download complete: ${task.title}');
    } catch (e) {
      final taskIndex = _downloadTasks.indexWhere((t) => t.id == taskId);
      if (taskIndex != -1) {
        _downloadTasks[taskIndex] = _downloadTasks[taskIndex].copyWith(
          status: DownloadStatus.failed,
          error: e.toString(),
        );
        notifyListeners();
      }

      _logControllers[taskId]?.add('❌ Download failed: ${e.toString()}');
    }
  }

  void cancelDownload(String taskId) {
    final taskIndex = _downloadTasks.indexWhere((task) => task.id == taskId);
    if (taskIndex == -1) return;

    final processKilled = N_m3u8DL_RE.cancelDownload(taskId);

    if (processKilled) {
      _logControllers[taskId]?.add(
        '⏹️ Download process stopped and task removed',
      );
    } else {
      _logControllers[taskId]?.add('⏹️ Download cancelled and task removed');
    }

    removeDownloadTask(taskId);
  }

  void retryDownload(String taskId) {
    final taskIndex = _downloadTasks.indexWhere((task) => task.id == taskId);
    if (taskIndex == -1) return;

    final task = _downloadTasks[taskIndex];
    if (task.status == DownloadStatus.failed ||
        task.status == DownloadStatus.cancelled) {
      _downloadTasks[taskIndex] = task.copyWith(
        status: DownloadStatus.pending,
        error: null,
        progress: 0.0,
      );
      notifyListeners();

      _startDownload(taskId);
    }
  }

  void removeDownloadTask(String taskId) {
    _downloadTasks.removeWhere((task) => task.id == taskId);
    _logControllers[taskId]?.close();
    _logControllers.remove(taskId);
    _progressControllers[taskId]?.close();
    _progressControllers.remove(taskId);
    _statusTrackers.remove(taskId);
    notifyListeners();
  }

  Stream<String>? getLogStream(String taskId) {
    return _logControllers[taskId]?.stream;
  }

  Stream<DownloadProgress>? getProgressStream(String taskId) {
    return _progressControllers[taskId]?.stream;
  }

  String _sanitizeFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }

  void clearCompletedTasks() {
    final completedTasks = _downloadTasks
        .where(
          (task) =>
              task.status == DownloadStatus.completed ||
              task.status == DownloadStatus.failed ||
              task.status == DownloadStatus.cancelled,
        )
        .toList();

    for (final task in completedTasks) {
      removeDownloadTask(task.id);
    }
  }

  @override
  void dispose() {
    for (final controller in _logControllers.values) {
      controller.close();
    }
    for (final controller in _progressControllers.values) {
      controller.close();
    }
    _logControllers.clear();
    _progressControllers.clear();
    super.dispose();
  }
}
