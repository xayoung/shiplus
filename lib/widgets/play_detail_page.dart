import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'main_layout.dart';
import '../services/global_download_manager.dart';
import '../services/download_service.dart';
import '../utils/dio_helper.dart';

class PlayDetailPage extends StatefulWidget {
  final String itemId;

  const PlayDetailPage({super.key, required this.itemId});

  @override
  State<PlayDetailPage> createState() => _PlayDetailPageState();
}

class _PlayDetailPageState extends State<PlayDetailPage> {
  Map<String, dynamic>? _metadata;
  List<dynamic>? _additionalStreams;
  bool _isLoading = true;
  String? _error;
  late final Dio dio;

  @override
  void initState() {
    super.initState();
    // 创建带有 Cookie 管理器的 Dio 实例
    dio = DioHelper.createDioWithCookies(enableDebug: true);
    _fetchVideoDetail();
  }

  Future<void> _fetchStreamToken(String playbackUrl, String title) async {
    try {
      // 显示加载提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('正在获取流媒体信息: $title'),
          duration: const Duration(seconds: 2),
        ),
      );

      // 第一步：POST请求获取token
      final tokenResponse = await dio.post(
        'https://www.histreams.net/api/token_v3',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'type': '0',
          's': '6550010',
        },
      );

      if (tokenResponse.statusCode == 200) {
        final tokenData = tokenResponse.data;
        final token = tokenData['token']?[0]?['token']?.toString();

        if (token != null && token.isNotEmpty) {
          print('Token获取成功: $token');

          // 第二步：使用token请求流媒体数据
          await _fetchStreamData(playbackUrl, token, title);
        } else {
          print('Token获取失败: 响应中没有找到token');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('获取访问令牌失败'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        print('Token请求失败: ${tokenResponse.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('获取访问令牌失败: ${tokenResponse.statusCode}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Token请求异常: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('请求失败: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _fetchStreamData(
      String playbackUrl, String token, String title) async {
    try {
      final url =
          'https://f1tv.formula1.com/2.0/R/ENG/BIG_SCREEN_HLS/ALL/$playbackUrl&player=player_bm';
      const deviceInfo =
          'device=tvos;screen=bigscreen;os=tvos;model=appletv14.1;osVersion=16.4;appVersion=2.31.0;playerVersion=3.65.0';
      // final url =
      //     'https://f1tv.formula1.com/2.0/R/ENG/WEB_HLS/ALL/$playbackUrl&player=player_bm';
      // final deviceInfo =
      //     'device=web;screen=browser;os=mac os;browser=chrome;browserVersion=137.0.0.0;model=Macintosh;osVersion=14.6.1;appVersion=release-R43.0.1;playerVersion=8.212.0';

      print('请求流媒体数据: $url');
      final response = await dio.get(
        url,
        options: Options(
          headers: {
            'accept': '*/*',
            'accept-encoding': 'gzip, deflate, br, zstd',
            'accept-language': 'zh-CN',
            'origin': 'https://f1tv.formula1.com',
            'sec-fetch-dest': 'empty',
            'sec-fetch-mode': 'cors',
            'sec-fetch-site': 'same-origin',
            'user-agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.6998.165 Safari/537.36',
            'referer': 'https://www.formula1.com/',
            'sec-ch-ua': '"Not:A-Brand";v="24", "Chromium";v="134"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
            'priority': 'u=1, i',
            'ascendonToken': token,
            'x-f1-device-info': deviceInfo,
          },
        ),
      );

      if (response.statusCode == 200) {
        print('流媒体数据获取成功');
        print('Response: ${response.data}');
        final responseData = response.data;
        try {
          final streamUrl = responseData['resultObj']?['url']?.toString();
          if (streamUrl != null) {
            print('Stream URL: $streamUrl');

            // 添加到全局下载管理器
            final downloadManager = GlobalDownloadManager();
            final taskId = await downloadManager.addDownloadTask(
              url: streamUrl,
              title: title,
            );

            // 显示下载进度
            _showDownloadProgress(taskId, title);
          } else {
            final msg = responseData['message']?.toString();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(msg!),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        } catch (e) {
          print('解析响应数据失败: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('解析流媒体数据失败: $e'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        print('流媒体数据请求失败: ${response.statusCode}');
        print('Response: ${response.data}');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('获取流媒体数据失败: ${response.statusCode}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('流媒体数据请求异常: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('获取流媒体数据失败: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _fetchVideoDetail() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final url =
          'https://f1tv.formula1.com/3.0/A/ENG/WEB_DASH/ALL/CONTENT/VIDEO/${widget.itemId}/Anonymous/2?contentId=${widget.itemId}&entitlement=Anonymous';

      final response = await dio.get(
        url,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        setState(() {
          _metadata = data['resultObj']?['containers']?[0]?['metadata'];
          _additionalStreams = data['resultObj']?['containers']?[0]?['metadata']
              ?['additionalStreams'];
          _isLoading = false;
        });

        print('Video detail loaded for ID: ${widget.itemId}');
        print('Additional streams count: ${_additionalStreams?.length ?? 0}');
      } else {
        setState(() {
          _error = 'HTTP error! status: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      print('Error fetching video detail: $e');
    }
  }

  /// 下载主视频
  Future<void> _downloadMainVideo(String title) async {
    print('Main video download requested:');
    print('Title: $title');
    await _fetchStreamToken('CONTENT/PLAY?contentId=${widget.itemId}', title);
  }

  /// 下载封面图片
  Future<void> _downloadCover(String imageUrl, String title) async {
    try {
      // 显示开始下载的提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('开始下载封面...'),
          duration: Duration(seconds: 2),
        ),
      );

      // 获取下载路径
      final downloadPath = await DownloadService.getDownloadPath();

      // 清理文件名，移除不安全的字符
      final cleanTitle = title
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .replaceAll(RegExp(r'\s+'), '_')
          .trim();

      // 获取图片扩展名
      final uri = Uri.parse(imageUrl);
      String extension = path.extension(uri.path);
      if (extension.isEmpty) {
        extension = '.jpg'; // 默认使用 jpg 扩展名
      }

      // 构建文件名
      final fileName = '${cleanTitle}_cover$extension';
      final filePath = path.join(downloadPath, fileName);

      print('Downloading cover from: $imageUrl');
      print('Saving to: $filePath');

      // 下载图片
      final response = await dio.get(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      // 保存文件
      final file = File(filePath);
      await file.writeAsBytes(response.data);

      // 显示成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('封面下载成功: $fileName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: '查看',
              textColor: Colors.white,
              onPressed: () {
                // 可以添加打开文件夹的功能
                print('Cover saved to: $filePath');
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('Error downloading cover: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('封面下载失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 显示下载进度
  void _showDownloadProgress(String taskId, String title) {
    final downloadManager = GlobalDownloadManager();

    // 显示初始的 SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('开始下载: $title'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: '查看进度',
          onPressed: () {
            _showProgressDialog(taskId, title);
          },
        ),
      ),
    );
  }

  /// 显示进度对话框
  void _showProgressDialog(String taskId, String title) {
    final downloadManager = GlobalDownloadManager();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('下载进度: $title'),
        content: StreamBuilder(
          stream: downloadManager.getProgressStream(taskId),
          builder: (context, snapshot) {
            final tracker = downloadManager.getStatusTracker(taskId);
            if (tracker == null) {
              return const Text('准备下载...');
            }

            final info = tracker.getDetailedInfo();

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 整体进度
                Text('整体进度: ${tracker.overallProgress.toStringAsFixed(1)}%'),
                LinearProgressIndicator(
                  value: tracker.overallProgress / 100,
                ),
                const SizedBox(height: 16),

                // 视频进度
                if (info['video'] != null) ...[
                  Text('视频 (${info['video']['quality']}):'),
                  Text(
                      '${info['video']['progress']} - ${info['video']['percentage'].toStringAsFixed(1)}%'),
                  Text(
                      '大小: ${info['video']['size']} | ETA: ${info['video']['eta']}'),
                  const SizedBox(height: 8),
                ],

                // 音频进度
                if (info['audio'] != null) ...[
                  Text('音频 (${info['audio']['quality']}):'),
                  Text(
                      '${info['audio']['progress']} - ${info['audio']['percentage'].toStringAsFixed(1)}%'),
                  Text(
                      '大小: ${info['audio']['size']} | ETA: ${info['audio']['eta']}'),
                  const SizedBox(height: 8),
                ],

                // 状态信息
                if (info['status'] != null) Text('状态: ${info['status']}'),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              downloadManager.cancelDownload(taskId);
              Navigator.of(context).pop();
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => NavigationHelper.popPageInCurrentTab(context),
        ),
        title: const Text(
          'Play Detail',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading video details...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchVideoDetail,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 视频基本信息
          _buildVideoInfo(),
          const SizedBox(height: 24),

          // Additional Streams 部分（只有当有内容时才显示）
          if (_additionalStreams != null && _additionalStreams!.isNotEmpty)
            _buildAdditionalStreams(),
        ],
      ),
    );
  }

  Widget _buildVideoInfo() {
    if (_metadata == null) return const SizedBox.shrink();

    final title = _metadata!['title']?.toString() ?? 'Unknown Title';
    final titleBrief = _metadata!['titleBrief']?.toString() ?? '';
    final description = _metadata!['longDescription']?.toString() ?? '';
    final pictureUrl = _metadata!['pictureUrl']?.toString() ?? '';

    final imageUrl = pictureUrl.isNotEmpty
        ? 'https://f1tv.formula1.com/image-resizer/image/$pictureUrl?w=1024&h=576&q=HI&o=L'
        : null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 视频封面
            if (imageUrl != null)
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 200,
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                            size: 48,
                          ),
                        );
                      },
                    ),
                  ),
                  // 下载封面按钮
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        onPressed: () => _downloadCover(imageUrl, title),
                        icon: const Icon(
                          Icons.download,
                          color: Colors.white,
                          size: 20,
                        ),
                        tooltip: '下载封面',
                      ),
                    ),
                  ),
                ],
              ),
            if (imageUrl != null) const SizedBox(height: 16),

            // 标题
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            // 副标题
            if (titleBrief.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                titleBrief,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],

            // 描述
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],

            // 视频ID
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'ID: ${widget.itemId}',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.grey[600],
                ),
              ),
            ),

            // 下载按钮
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _downloadMainVideo(title),
                icon: const Icon(Icons.download),
                label: const Text('下载视频'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalStreams() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.video_library,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Additional Streams',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _additionalStreams!.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final stream = _additionalStreams![index];
                return _buildStreamItem(stream, index);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamItem(dynamic stream, int index) {
    final title = stream['title']?.toString() ?? 'Stream ${index + 1}';
    final type = stream['type']?.toString() ?? '';
    final language = stream['language']?.toString() ?? '';
    final driverName = stream['driverName']?.toString() ?? '';
    final teamName = stream['teamName']?.toString() ?? '';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
        child: Text(
          '${index + 1}',
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (type.isNotEmpty) Text('Type: $type'),
          if (language.isNotEmpty) Text('Language: $language'),
          if (driverName.isNotEmpty) Text('Driver: $driverName'),
          if (teamName.isNotEmpty) Text('Team: $teamName'),
        ],
      ),
      trailing: const Icon(Icons.download),
      onTap: () async {
        // 打印playbackUrl
        final playbackUrl = stream['playbackUrl']?.toString() ?? '';
        print('Stream item clicked:');
        print('Title: $title');
        print('PlaybackUrl: $playbackUrl');
        final t = _metadata!['title']?.toString();
        String titlev2 = '$t-$title';
        if (playbackUrl.isNotEmpty) {
          await _fetchStreamToken(playbackUrl, titlev2);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No playback URL available for: $title'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }
}
