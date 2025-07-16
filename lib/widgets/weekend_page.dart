import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'play_detail_page.dart';
import 'main_layout.dart';
import '../utils/dio_helper.dart';

// 数据模型类
class WeekendItem {
  final String id;
  final Map<String, dynamic> metadata;
  final List<Map<String, dynamic>>? actions;
  final String? pageid;

  WeekendItem({
    required this.id,
    required this.metadata,
    this.actions,
    this.pageid,
  });

  factory WeekendItem.fromJson(Map<String, dynamic> json) {
    final actions =
        (json['actions'] as List<dynamic>?)?.cast<Map<String, dynamic>>();

    // 从actions中提取pageid
    String? pageid;
    if (actions != null && actions.isNotEmpty) {
      final href = actions[0]['href']?.toString() ?? '';
      final pageIdMatch = RegExp(r'/page/(\d+)').firstMatch(href);
      if (pageIdMatch != null) {
        pageid = pageIdMatch.group(1);
      }
    }

    return WeekendItem(
      id: json['id']?.toString() ?? '',
      metadata: json['metadata'] ?? {},
      actions: actions,
      pageid: pageid,
    );
  }
}

// 容器数据模型类
class WeekendContainer {
  final String title;
  final String layout;
  final List<WeekendItem> items;

  WeekendContainer({
    required this.title,
    required this.layout,
    required this.items,
  });
}

class WeekendPage extends StatefulWidget {
  final String pageid;

  const WeekendPage({super.key, required this.pageid});

  @override
  State<WeekendPage> createState() => _WeekendPageState();
}

class _WeekendPageState extends State<WeekendPage> {
  List<WeekendContainer> _containers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchWeekendData();
  }

  Future<void> _fetchWeekendData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final dio = DioHelper.createDioWithCookies();
      final response = await dio.get(
        'https://nodeapi.histreams.net/api/f1/compage/${widget.pageid}',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // 处理所有容器，不进行过滤
        List<WeekendContainer> weekendContainers = [];

        if (data['resultObj']?['containers'] != null) {
          final containers = data['resultObj']['containers'] as List<dynamic>;

          // 处理每个容器
          for (final container in containers) {
            final title = container['title']?.toString() ?? '';
            final layout = container['layout']?.toString() ?? '';
            List<WeekendItem> containerItems = [];

            if (container['retrieveItems']?['resultObj']?['containers'] !=
                null) {
              final itemContainers = container['retrieveItems']['resultObj']
                  ['containers'] as List<dynamic>;

              for (final item in itemContainers) {
                try {
                  containerItems.add(WeekendItem.fromJson(item));
                } catch (e) {
                  print('Error parsing item: $e');
                }
              }
            }

            // 只添加有内容的容器
            if (containerItems.isNotEmpty && title.isNotEmpty) {
              weekendContainers.add(WeekendContainer(
                title: title,
                layout: layout,
                items: containerItems,
              ));
            }
          }
        }

        setState(() {
          _containers = weekendContainers;
          _isLoading = false;
        });

        print('Weekend containers: ${_containers.length}');
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
      print('Error fetching weekend data: $e');
    }
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
          'Weekend',
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
            Text('Loading weekend data...'),
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
          ],
        ),
      );
    }

    if (_containers.isEmpty) {
      return const Center(
        child: Text(
          'No content to display',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView.builder(
        itemCount: _containers.length,
        itemBuilder: (context, containerIndex) {
          final container = _containers[containerIndex];
          return _buildContainerSection(container, containerIndex);
        },
      ),
    );
  }

  // 构建容器部分
  Widget _buildContainerSection(
      WeekendContainer container, int containerIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 容器标题
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
          child: Text(
            container.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1E1E),
            ),
          ),
        ),

        // 容器内容
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 1.67, // 16:9.6 aspect ratio
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
          ),
          itemCount: container.items.length,
          itemBuilder: (context, index) {
            final item = container.items[index];
            return _buildWeekendItem(item, index);
          },
        ),

        // 容器之间的间隔
        const SizedBox(height: 32),
      ],
    );
  }

  // 构建单个项目
  Widget _buildWeekendItem(WeekendItem item, int index) {
    // 构建图片URL
    final pictureUrl = item.metadata['pictureUrl']?.toString() ?? '';
    final imageUrl = pictureUrl.isNotEmpty
        ? 'https://f1tv.formula1.com/image-resizer/image/$pictureUrl?w=1024&h=576&q=HI&o=L'
        : 'https://www.formula1.com/etc/designs/fom-website/images/f1-logo-red.png';

    // 获取视频信息
    final shortDescription = item.metadata['title']?.toString() ?? '';
    final titleBrief = item.metadata['titleBrief']?.toString() ?? '';

    final uiSeries = item.metadata['uiSeries']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        print('Weekend item selected: ${item.id}');
        if (item.id.isNotEmpty) {
          NavigationHelper.pushPageInCurrentTab(
            context,
            PlayDetailPage(itemId: item.id),
          );
        }
      },
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            // 背景图片
            Positioned.fill(
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.image_not_supported,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
            // 底部覆盖层
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black87,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 标题
                    Text(
                      shortDescription,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            titleBrief,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          uiSeries,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
