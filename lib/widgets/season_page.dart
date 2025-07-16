import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shiplus/widgets/play_detail_page.dart';
import 'weekend_page.dart';
import 'main_layout.dart';
import '../utils/dio_helper.dart';

// 数据模型类
class SeasonItem {
  final String id;
  final Map<String, dynamic> metadata;
  final List<Map<String, dynamic>>? actions;
  final String? pageid;

  SeasonItem({
    required this.id,
    required this.metadata,
    this.actions,
    this.pageid,
  });

  factory SeasonItem.fromJson(Map<String, dynamic> json) {
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

    return SeasonItem(
      id: json['id']?.toString() ?? '',
      metadata: json['metadata'] ?? {},
      actions: actions,
      pageid: pageid,
    );
  }
}

// 容器数据模型类
class SeasonContainer {
  final String title;
  final String layout;
  final List<SeasonItem> items;

  SeasonContainer({
    required this.title,
    required this.layout,
    required this.items,
  });
}

class SeasonPage extends StatefulWidget {
  final String pageid;

  const SeasonPage({super.key, required this.pageid});

  @override
  State<SeasonPage> createState() => _SeasonPageState();
}

class _SeasonPageState extends State<SeasonPage> {
  List<SeasonContainer> _containers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSeasonData();
  }

  Future<void> _fetchSeasonData() async {
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
        List<SeasonContainer> seasonContainers = [];

        if (data['resultObj']?['containers'] != null) {
          final containers = data['resultObj']['containers'] as List<dynamic>;

          // 处理每个容器
          for (final container in containers) {
            String title = container['title']?.toString() ?? '';
            if (title.isEmpty) {
              final collectionName = container['retrieveItems']?['resultObj']
                      ?['collectionName']
                  ?.toString();
              if (collectionName != null && collectionName.isNotEmpty) {
                title = collectionName;
              }
            }
            final layout = container['layout']?.toString() ?? '';
            List<SeasonItem> containerItems = [];

            if (container['retrieveItems']?['resultObj']?['containers'] !=
                null) {
              final itemContainers = container['retrieveItems']['resultObj']
                  ['containers'] as List<dynamic>;

              for (final item in itemContainers) {
                try {
                  final seasonItem = SeasonItem.fromJson(item);
                  containerItems.add(seasonItem);
                } catch (e) {
                  print('Error parsing item: $e');
                }
              }
            }

            // 只添加有内容的容器
            if (containerItems.isNotEmpty) {
              seasonContainers.add(SeasonContainer(
                title: title,
                layout: layout,
                items: containerItems,
              ));
            }
          }
        }

        setState(() {
          _containers = seasonContainers;
          _isLoading = false;
        });

        print('Season containers: ${_containers.length}');
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
      print('Error fetching season data: $e');
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
          'Season',
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
            Text('Loading season data...'),
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
  Widget _buildContainerSection(SeasonContainer container, int containerIndex) {
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
            return _buildSeasonItem(item, index);
          },
        ),

        // 容器之间的间隔
        const SizedBox(height: 32),
      ],
    );
  }

  // 构建单个项目
  Widget _buildSeasonItem(SeasonItem item, int index) {
    // 构建图片URL
    final pictureUrl = item.metadata['pictureUrl']?.toString() ?? '';
    final imageUrl = pictureUrl.isNotEmpty
        ? 'https://f1tv.formula1.com/image-resizer/image/$pictureUrl?w=1024&h=576&q=HI&o=L'
        : 'https://www.formula1.com/etc/designs/fom-website/images/f1-logo-red.png';

    // 获取赛事信息
    final emfAttributes = item.metadata['emfAttributes'] ?? {};
    final meetingNumber = emfAttributes['Meeting_Number']?.toString() ?? '';
    final countryName =
        emfAttributes['Global_Meeting_Country_Name']?.toString() ?? '';
    final displayDate = emfAttributes['Meeting_Display_Date']?.toString() ?? '';
    final globalTitle = emfAttributes['Global_Title']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        print('Item selected: ${item.metadata['title']}');
        print('Item ID: ${item.id}');
        print('Page ID: ${item.pageid}');
        // 使用NavigationHelper在当前tab中跳转到weekend页面
        if (item.pageid != null) {
          NavigationHelper.pushPageInCurrentTab(
            context,
            WeekendPage(pageid: item.pageid!),
          );
        } else {
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
                  print('Image failed to load: $imageUrl');
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
                    // 标题行
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${meetingNumber.isNotEmpty ? 'R$meetingNumber  ' : ''}$countryName',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (displayDate.isNotEmpty)
                          Text(
                            displayDate,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    // 副标题
                    Text(
                      globalTitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
