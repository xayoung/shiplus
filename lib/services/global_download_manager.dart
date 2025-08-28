import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/download_progress.dart';
import '../models/download_task.dart';
import '../models/download_status_tracker.dart';
import '../ffi/n_m3u8dl_re.dart';
import 'download_service.dart';

/// 全局下载管理器，管理所有下载任务
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

  /// 获取所有下载任务
  List<DownloadTask> get downloadTasks => List.unmodifiable(_downloadTasks);

  /// 获取正在下载的任务数量
  int get activeDownloadsCount => _downloadTasks
      .where((task) => task.status == DownloadStatus.downloading)
      .length;

  /// 获取任务的状态跟踪器
  DownloadStatusTracker? getStatusTracker(String taskId) {
    return _statusTrackers[taskId];
  }

  /// 添加下载任务
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

    // 立即开始下载
    _startDownload(taskId);

    return taskId;
  }

  /// 开始下载任务
  Future<void> _startDownload(String taskId) async {
    final taskIndex = _downloadTasks.indexWhere((task) => task.id == taskId);
    if (taskIndex == -1) return;

    final task = _downloadTasks[taskIndex];
    _downloadTasks[taskIndex] =
        task.copyWith(status: DownloadStatus.downloading);
    notifyListeners();

    try {
      final downloadPath = await DownloadService.getDownloadPath();

      _logControllers[taskId]?.add('🚀 开始下载: ${task.title}');
      _logControllers[taskId]?.add('📁 保存目录: $downloadPath');
      _logControllers[taskId]?.add('🔗 视频链接: ${task.url}');

      await DownloadService.downloadVideo(
        task.url,
        downloadPath,
        task.fileName,
        taskId: taskId, // 传递任务ID
        onLog: (log) {
          _logControllers[taskId]?.add(log);
        },
        onProgress: (progress) {
          _progressControllers[taskId]?.add(progress);

          // 更新状态跟踪器
          final tracker = _statusTrackers[taskId];
          if (tracker != null) {
            tracker.updateProgress(progress);

            // 更新任务进度
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

      // 下载完成
      final taskIndex = _downloadTasks.indexWhere((t) => t.id == taskId);
      if (taskIndex != -1) {
        _downloadTasks[taskIndex] = _downloadTasks[taskIndex].copyWith(
          status: DownloadStatus.completed,
          progress: 100.0,
          completedAt: DateTime.now(),
        );
        notifyListeners();
      }

      _logControllers[taskId]?.add('🎉 下载完成: ${task.title}');
    } catch (e) {
      // 下载失败
      final taskIndex = _downloadTasks.indexWhere((t) => t.id == taskId);
      if (taskIndex != -1) {
        _downloadTasks[taskIndex] = _downloadTasks[taskIndex].copyWith(
          status: DownloadStatus.failed,
          error: e.toString(),
        );
        notifyListeners();
      }

      _logControllers[taskId]?.add('❌ 下载失败: ${e.toString()}');
    }
  }

  /// 取消下载任务并删除
  void cancelDownload(String taskId) {
    final taskIndex = _downloadTasks.indexWhere((task) => task.id == taskId);
    if (taskIndex == -1) return;

    // 尝试取消正在运行的进程
    final processKilled = N_m3u8DL_RE.cancelDownload(taskId);

    // 记录取消日志
    if (processKilled) {
      _logControllers[taskId]?.add('⏹️ 下载进程已中断，任务已删除');
    } else {
      _logControllers[taskId]?.add('⏹️ 下载已取消，任务已删除');
    }

    // 直接删除任务而不是更改状态
    removeDownloadTask(taskId);
  }

  /// 重试下载任务
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

  /// 删除下载任务
  void removeDownloadTask(String taskId) {
    _downloadTasks.removeWhere((task) => task.id == taskId);
    _logControllers[taskId]?.close();
    _logControllers.remove(taskId);
    _progressControllers[taskId]?.close();
    _progressControllers.remove(taskId);
    _statusTrackers.remove(taskId);
    notifyListeners();
  }

  /// 获取任务的日志流
  Stream<String>? getLogStream(String taskId) {
    return _logControllers[taskId]?.stream;
  }

  /// 获取任务的进度流
  Stream<DownloadProgress>? getProgressStream(String taskId) {
    return _progressControllers[taskId]?.stream;
  }

  /// 清理文件名
  String _sanitizeFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }

  /// 清空所有已完成的任务
  void clearCompletedTasks() {
    final completedTasks = _downloadTasks
        .where((task) =>
            task.status == DownloadStatus.completed ||
            task.status == DownloadStatus.failed ||
            task.status == DownloadStatus.cancelled)
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
