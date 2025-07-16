import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shiplus/widgets/play_detail_page.dart';
import 'dart:convert';
import 'season_page.dart';
import 'main_layout.dart';
import '../utils/dio_helper.dart';

// 数据模型类
class ArchiveItem {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String pageid;

  ArchiveItem({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.pageid,
  });

  factory ArchiveItem.fromJson(Map<String, dynamic> json) {
    // 从metadata中提取数据
    final metadata = json['metadata'] ?? {};
    final actions = json['actions'] as List<dynamic>? ?? [];

    // 从actions中提取pageid
    String pageid = '';
    if (actions.isNotEmpty) {
      final href = actions[0]['href']?.toString() ?? '';
      final pageIdMatch = RegExp(r'/page/(\d+)').firstMatch(href);
      if (pageIdMatch != null) {
        pageid = pageIdMatch.group(1) ?? '';
      }
    }

    return ArchiveItem(
      id: json['id']?.toString() ?? '',
      title: metadata['title']?.toString() ?? 'Unknown Season',
      description: metadata['longDescription']?.toString() ?? '',
      imageUrl: metadata['pictureUrl']?.toString() ?? '',
      pageid: pageid,
    );
  }
}

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  List<ArchiveItem> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final dio = DioHelper.createDioWithCookies();
      final response = await dio.get(
        'https://nodeapi.histreams.net/api/f1/compage/493',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // 按照React Native版本的逻辑解析数据
        List<ArchiveItem> seasonsArray = [];

        if (data['resultObj']?['containers'] != null) {
          final containers = data['resultObj']['containers'] as List<dynamic>;

          // 遍历所有容器，查找包含retrieveItems的容器
          for (int i = 0; i < containers.length; i++) {
            final container = containers[i];

            if (container['retrieveItems']?['resultObj']?['containers'] !=
                null) {
              final itemContainers = container['retrieveItems']['resultObj']
                  ['containers'] as List<dynamic>;

              // 将找到的items添加到seasonsArray中
              for (final item in itemContainers) {
                try {
                  seasonsArray.add(ArchiveItem.fromJson(item));
                } catch (e) {
                  print('Error parsing item: $e');
                }
              }

              print('Found seasons in container $i: ${seasonsArray.length}');
            }
          }
        }

        setState(() {
          _items = seasonsArray;
          _isLoading = false;
        });

        print('Final seasons count: ${_items.length}');
        if (_items.isNotEmpty) {
          print('First season: ${_items[0].title}');
        }
      } else {
        setState(() {
          _error = '请求失败: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '网络错误: $e';
        _isLoading = false;
      });
      print('Error in _fetchData: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 页面标题
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Archive',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '浏览和发现精彩内容',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _fetchData,
                  icon: const Icon(Icons.refresh),
                  tooltip: '刷新',
                ),
              ],
            ),
            const SizedBox(height: 32),

            // 内容区域
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
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
            Text('加载中...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchData,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '暂无内容',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '没有找到任何内容',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据窗口宽度动态计算每行显示的item数量
        int crossAxisCount;
        if (constraints.maxWidth < 600) {
          crossAxisCount = 2; // 小屏幕显示2列
        } else if (constraints.maxWidth < 900) {
          crossAxisCount = 3; // 中等屏幕显示3列
        } else if (constraints.maxWidth < 1200) {
          crossAxisCount = 4; // 大屏幕显示4列
        } else {
          crossAxisCount = 5; // 超大屏幕显示5列
        }

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.6,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final item = _items[index];
            return _buildItemCard(item);
          },
        );
      },
    );
  }

  Widget _buildItemCard(ArchiveItem item) {
    // 构建图片URL，参考React Native版本的逻辑
    String imageUrl = item.imageUrl.isNotEmpty
        ? 'https://f1tv.formula1.com/image-resizer/image/${item.imageUrl}?w=1024&h=576&q=HI&o=L'
        : 'https://www.formula1.com/etc/designs/fom-website/images/f1-logo-red.png';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // 使用NavigationHelper在当前tab中跳转到season页面
          print('Season selected: ${item.title}');
          print('Page ID: ${item.pageid}');
          print('Item ID: ${item.id}');
          if (item.pageid.isNotEmpty) {
            NavigationHelper.pushPageInCurrentTab(
              context,
              SeasonPage(pageid: item.pageid),
            );
          } else {
            NavigationHelper.pushPageInCurrentTab(
              context,
              PlayDetailPage(itemId: item.id),
            );
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片区域
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[200],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.image_not_supported,
                        size: 48,
                        color: Colors.grey[400],
                      );
                    },
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
