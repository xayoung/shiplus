import 'package:flutter/material.dart';
import '../services/global_download_manager.dart';
import '../models/download_task.dart';

class DownloadManagerPage extends StatefulWidget {
  const DownloadManagerPage({super.key});

  @override
  State<DownloadManagerPage> createState() => _DownloadManagerPageState();
}

class _DownloadManagerPageState extends State<DownloadManagerPage> {
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 页面标题
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.download,
                      color: Theme.of(context).primaryColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Download Manager',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    GlobalDownloadManager().clearCompletedTasks();
                    _showSuccessSnackBar('Completed tasks cleared');
                  },
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear Completed Tasks'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 下载任务列表
            Expanded(
              child: ListenableBuilder(
                listenable: GlobalDownloadManager(),
                builder: (context, child) {
                  final downloadManager = GlobalDownloadManager();
                  final tasks = downloadManager.downloadTasks;

                  if (tasks.isEmpty) {
                    return _buildEmptyState();
                  }

                  return Column(
                    children: [
                      // 统计信息
                      _buildStatsCard(downloadManager, tasks),
                      const SizedBox(height: 24),

                      // 任务列表
                      Expanded(
                        child: Card(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    topRight: Radius.circular(8),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Text(
                                      'Download Task List',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'Total: ${tasks.length} tasks',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: tasks.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final task = tasks[index];
                                    return _buildTaskItem(task);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Card(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.download_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No Download Tasks',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Click the download button on the playback details page to start downloading',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard(
      GlobalDownloadManager downloadManager, List<DownloadTask> tasks) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              'Total',
              tasks.length.toString(),
              Icons.list_alt,
              Colors.blue,
            ),
            _buildStatItem(
              'Downloading',
              downloadManager.activeDownloadsCount.toString(),
              Icons.download,
              Colors.orange,
            ),
            _buildStatItem(
              'Completed',
              tasks
                  .where((t) => t.status == DownloadStatus.completed)
                  .length
                  .toString(),
              Icons.check_circle,
              Colors.green,
            ),
            _buildStatItem(
              'Failed',
              tasks
                  .where((t) => t.status == DownloadStatus.failed)
                  .length
                  .toString(),
              Icons.error,
              Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 24,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildTaskItem(DownloadTask task) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // 状态图标
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color(task.statusColor).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getStatusIcon(task.status),
              color: Color(task.statusColor),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),

          // 任务信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Color(task.statusColor).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        task.statusText,
                        style: TextStyle(
                          color: Color(task.statusColor),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (task.status == DownloadStatus.downloading) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${task.progress.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
                if (task.status == DownloadStatus.downloading) ...[
                  const SizedBox(height: 8),
                  StreamBuilder(
                    stream: GlobalDownloadManager().getProgressStream(task.id),
                    builder: (context, snapshot) {
                      return _buildDetailedProgress(task);
                    },
                  ),
                ],
                if (task.error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // 操作按钮
          _buildTaskActions(task),
        ],
      ),
    );
  }

  /// 构建详细的下载进度显示（分别显示 Vid 和 Aud）
  Widget _buildDetailedProgress(DownloadTask task) {
    final downloadManager = GlobalDownloadManager();
    final tracker = downloadManager.getStatusTracker(task.id);

    if (tracker == null) {
      // 如果没有状态跟踪器，显示简单的进度条
      return LinearProgressIndicator(
        value: task.progress / 100,
        backgroundColor: Colors.grey[300],
        valueColor: AlwaysStoppedAnimation<Color>(
          Color(task.statusColor),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 整体进度
        Row(
          children: [
            Text(
              'Overall Progress: ${tracker.overallProgress.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            if (tracker.isPostProcessing)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Post-processing',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: tracker.overallProgress / 100,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            Color(task.statusColor),
          ),
        ),

        // Vid、Aud 和 Sub 分别进度
        if (tracker.videoProgress != null ||
            tracker.audioProgresses.isNotEmpty ||
            tracker.subtitleProgresses.isNotEmpty) ...[
          const SizedBox(height: 8),

          // 视频进度
          if (tracker.videoProgress != null) ...[
            Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Vid (${tracker.videoProgress!.quality})',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Text(
                  '${tracker.videoProgress!.currentSegment}/${tracker.videoProgress!.totalSegments} - ${tracker.videoProgress!.percentage.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 2),
            LinearProgressIndicator(
              value: tracker.videoProgress!.percentage / 100,
              backgroundColor: Colors.blue[100],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            if (tracker.videoProgress!.downloadedSize.isNotEmpty &&
                tracker.videoProgress!.downloadedSize != '-') ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  const SizedBox(width: 10),
                  Text(
                    '${tracker.videoProgress!.downloadedSize} | ETA: ${tracker.videoProgress!.eta}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
          ],

          // 音频进度
          if (tracker.audioProgresses.isNotEmpty) ...[
            for (int i = 0; i < tracker.audioProgresses.length; i++) ...[
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Aud (${tracker.audioProgresses[i].quality})',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  Text(
                    '${tracker.audioProgresses[i].currentSegment}/${tracker.audioProgresses[i].totalSegments} - ${tracker.audioProgresses[i].percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              LinearProgressIndicator(
                value: tracker.audioProgresses[i].percentage / 100,
                backgroundColor: Colors.green[100],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              ),
              if (tracker.audioProgresses[i].downloadedSize.isNotEmpty &&
                  tracker.audioProgresses[i].downloadedSize != '-') ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    const SizedBox(width: 10),
                    Text(
                      '${tracker.audioProgresses[i].downloadedSize} | ETA: ${tracker.audioProgresses[i].eta}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
              if (i < tracker.audioProgresses.length - 1)
                const SizedBox(height: 6),
            ],
            const SizedBox(height: 6),
          ],

          // 字幕进度
          if (tracker.subtitleProgresses.isNotEmpty) ...[
            for (int i = 0; i < tracker.subtitleProgresses.length; i++) ...[
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Sub (${tracker.subtitleProgresses[i].quality})',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  Text(
                    '${tracker.subtitleProgresses[i].currentSegment}/${tracker.subtitleProgresses[i].totalSegments} - ${tracker.subtitleProgresses[i].percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              LinearProgressIndicator(
                value: tracker.subtitleProgresses[i].percentage / 100,
                backgroundColor: Colors.orange[100],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
              if (tracker.subtitleProgresses[i].downloadedSize.isNotEmpty &&
                  tracker.subtitleProgresses[i].downloadedSize != '-') ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    const SizedBox(width: 10),
                    Text(
                      '${tracker.subtitleProgresses[i].downloadedSize} | ETA: ${tracker.subtitleProgresses[i].eta}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
              if (i < tracker.subtitleProgresses.length - 1)
                const SizedBox(height: 6),
            ],
            const SizedBox(height: 6),
          ],
        ],

        // 状态信息
        if (tracker.currentStatus?.message != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              tracker.currentStatus!.message!,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTaskActions(DownloadTask task) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (task.canRetry)
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () {
              GlobalDownloadManager().retryDownload(task.id);
              _showSuccessSnackBar('Restart download: ${task.title}');
            },
            tooltip: 'Retry',
          ),
        if (task.canCancel)
          IconButton(
            icon: const Icon(Icons.stop, size: 20),
            onPressed: () {
              GlobalDownloadManager().cancelDownload(task.id);
              _showSuccessSnackBar('Download cancelled and deleted: ${task.title}');
            },
            tooltip: 'Cancel and Delete',
          ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: () {
            _showDeleteConfirmDialog(task);
          },
          tooltip: 'Delete',
        ),
      ],
    );
  }

  IconData _getStatusIcon(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.pending:
        return Icons.schedule;
      case DownloadStatus.downloading:
        return Icons.download;
      case DownloadStatus.completed:
        return Icons.check_circle;
      case DownloadStatus.failed:
        return Icons.error;
      case DownloadStatus.cancelled:
        return Icons.cancel;
    }
  }

  void _showDeleteConfirmDialog(DownloadTask task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete the download task "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              GlobalDownloadManager().removeDownloadTask(task.id);
              _showSuccessSnackBar('Task deleted: ${task.title}');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
