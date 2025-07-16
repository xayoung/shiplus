import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/download_progress.dart';
import '../services/download_service.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  final _urlController = TextEditingController();
  final _fileNameController = TextEditingController();
  final _pathController = TextEditingController();
  final _extraArgsController = TextEditingController();
  bool _isDownloading = false;
  String _currentPath = '';
  String _downloadStatus = '';
  final List<String> _downloadLogs = [];
  final ScrollController _logScrollController = ScrollController();
  bool _showAdvancedOptions = false;

  // 添加进度状态变量
  DownloadProgress? _videoProgress;
  DownloadProgress? _audioProgress;

  @override
  void initState() {
    super.initState();
    _loadCurrentPath();
    // 预设一些避免交互的参数
    // _extraArgsController.text = '--auto-select --select-video best --select-audio best';
  }

  Future<void> _loadCurrentPath() async {
    try {
      final path = await DownloadService.getDownloadPath();
      setState(() {
        _currentPath = path;
      });
    } catch (e) {
      _showErrorSnackBar('获取下载路径失败: $e');
    }
  }

  void _updateDownloadPath() {
    final newPath = _pathController.text.trim();
    if (newPath.isNotEmpty) {
      DownloadService.setDownloadPath(newPath);
      _loadCurrentPath();
      _showSuccessSnackBar('下载路径已更新');
      _pathController.clear();
    } else {
      _showErrorSnackBar('请输入有效的路径');
    }
  }

  void _clearCustomPath() {
    DownloadService.clearCustomDownloadPath();
    _loadCurrentPath();
    _pathController.clear();
    _showSuccessSnackBar('已恢复默认下载路径');
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  List<String> _parseExtraArgs(String extraArgsText) {
    if (extraArgsText.trim().isEmpty) {
      return [];
    }
    return extraArgsText.trim().split(RegExp(r'\s+'));
  }

  Future<void> _startDownload() async {
    final url = _urlController.text.trim();
    final fileName = _fileNameController.text.trim();

    if (url.isEmpty || fileName.isEmpty) {
      _showErrorSnackBar('请输入URL和文件名');
      return;
    }

    // 验证URL格式
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      _showErrorSnackBar('请输入有效的URL（以http://或https://开头）');
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadStatus = '正在准备下载...';
      _downloadLogs.clear();
      _videoProgress = null;
      _audioProgress = null;
    });

    try {
      setState(() {
        _downloadStatus = '正在下载视频，请稍候...';
      });

      await DownloadService.downloadVideo(
        url,
        _currentPath, // 使用当前路径
        fileName,
        extraArgs: _parseExtraArgs(_extraArgsController.text),
        onLog: (log) {
          setState(() {
            _downloadLogs.add(log);
          });
          // 自动滚动到底部
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_logScrollController.hasClients) {
              _logScrollController.animateTo(
                _logScrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        },
        onProgress: (progress) {
          setState(() {
            if (progress.type == 'video') {
              _videoProgress = progress;
            } else if (progress.type == 'audio') {
              _audioProgress = progress;
            }
          });
        },
      );

      if (mounted) {
        setState(() {
          _downloadStatus = '下载完成！';
        });
        _showSuccessSnackBar('视频下载完成');

        // 清空输入框
        _urlController.clear();
        _fileNameController.clear();

        // 3秒后清空日志
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _downloadLogs.clear();
            });
          }
        });
      }
    } catch (e) {
      print('下载失败: $e');
      if (mounted) {
        setState(() {
          _downloadStatus = '下载失败: $e';
        });
        _showErrorSnackBar('下载失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });

        // 3秒后清除状态信息
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _downloadStatus = '';
            });
          }
        });
      }
    }
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        if (_videoProgress != null) ...[
          Text('视频: ${_videoProgress!.quality}'),
          LinearProgressIndicator(value: _videoProgress!.percentage / 100),
          Text(
              '${_videoProgress!.currentSegment}/${_videoProgress!.totalSegments} (${_videoProgress!.percentage.toStringAsFixed(1)}%)'),
          Text(
              '${_videoProgress!.downloadedSize}/${_videoProgress!.totalSize} - ${_videoProgress!.speed} - ETA: ${_videoProgress!.eta}'),
        ],
        if (_audioProgress != null) ...[
          Text('音频: ${_audioProgress!.quality}'),
          LinearProgressIndicator(value: _audioProgress!.percentage / 100),
          Text(
              '${_audioProgress!.currentSegment}/${_audioProgress!.totalSegments} (${_audioProgress!.percentage.toStringAsFixed(1)}%)'),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('M3U8视频下载器'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 当前路径显示卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '下载设置',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '当前下载路径:',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _currentPath.isEmpty ? '加载中...' : _currentPath,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _pathController,
                            decoration: const InputDecoration(
                              labelText: '自定义下载路径（可选）',
                              hintText: '留空使用默认路径',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _updateDownloadPath,
                          child: const Text('设置'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _clearCustomPath,
                          child: const Text('重置'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 下载表单卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '视频下载',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'M3U8视频链接',
                        hintText: '请输入M3U8视频链接',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !_isDownloading,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _fileNameController,
                      decoration: const InputDecoration(
                        labelText: '文件名',
                        hintText: '请输入保存的文件名（不含扩展名）',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !_isDownloading,
                    ),
                    const SizedBox(height: 16),

                    // 高级选项切换
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showAdvancedOptions = !_showAdvancedOptions;
                        });
                      },
                      child: Row(
                        children: [
                          Icon(
                            _showAdvancedOptions
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_right,
                          ),
                          const Text('高级选项'),
                        ],
                      ),
                    ),

                    // 高级选项内容
                    if (_showAdvancedOptions) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _extraArgsController,
                        decoration: const InputDecoration(
                          labelText: '额外参数（可选）',
                          hintText: '例如: --auto-select --select-video best',
                          border: OutlineInputBorder(),
                        ),
                        enabled: !_isDownloading,
                        maxLines: 2,
                      ),
                    ],

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isDownloading ? null : _startDownload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isDownloading
                              ? Colors.grey
                              : Theme.of(context).primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isDownloading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('下载中...',
                                      style: TextStyle(color: Colors.white)),
                                ],
                              )
                            : const Text('开始下载',
                                style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 下载状态显示
            if (_downloadStatus.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        _downloadStatus.contains('失败')
                            ? Icons.error
                            : _downloadStatus.contains('完成')
                                ? Icons.check_circle
                                : Icons.info,
                        color: _downloadStatus.contains('失败')
                            ? Colors.red
                            : _downloadStatus.contains('完成')
                                ? Colors.green
                                : Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _downloadStatus,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: _downloadStatus.contains('失败')
                                ? Colors.red
                                : _downloadStatus.contains('完成')
                                    ? Colors.green
                                    : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 进度显示
            if (_videoProgress != null || _audioProgress != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '下载进度',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildProgressIndicator(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 下载日志显示
            if (_downloadLogs.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '下载日志 (${_downloadLogs.length} 条)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _downloadLogs.clear();
                              });
                            },
                            child: const Text('清空'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          controller: _logScrollController,
                          padding: const EdgeInsets.all(8),
                          itemCount: _downloadLogs.length,
                          itemBuilder: (context, index) {
                            final log = _downloadLogs[index];
                            Color textColor = Colors.white;
                            if (log.contains('ERROR') || log.contains('❌')) {
                              textColor = Colors.red;
                            } else if (log.contains('🎉') ||
                                log.contains('完成')) {
                              textColor = Colors.green;
                            } else if (log.contains('🚀') ||
                                log.contains('开始')) {
                              textColor = Colors.blue;
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1),
                              child: Text(
                                log,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _fileNameController.dispose();
    _pathController.dispose();
    _logScrollController.dispose();
    _extraArgsController.dispose();
    super.dispose();
  }
}
