import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../utils/dio_helper.dart';
import 'weekend_page.dart';
import 'main_layout.dart';

// 数据模型类，参考 season_page.dart
class HomeItem {
  final String id;
  final Map<String, dynamic> metadata;
  final List<Map<String, dynamic>>? actions;
  final String? pageid;

  HomeItem({
    required this.id,
    required this.metadata,
    this.actions,
    this.pageid,
  });

  factory HomeItem.fromJson(Map<String, dynamic> json) {
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

    return HomeItem(
      id: json['id']?.toString() ?? '',
      metadata: json['metadata'] ?? {},
      actions: actions,
      pageid: pageid,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 滚动控制器
  final ScrollController _scrollController = ScrollController();
  // 首页数据相关状态
  List<HomeItem> _verticalItems = [];
  List<HomeItem> _horizontalItems = [];
  String _verticalTitle = '精选内容';
  String _horizontalTitle = '最新赛事';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchHomeData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 获取首页数据，参考 season_page.dart 的实现
  Future<void> _fetchHomeData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final dio = DioHelper.createDioWithCookies();
      final response = await dio.get(
        'https://nodeapi.histreams.net/api/f1/compage/10295',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // 分别处理两种布局类型的容器
        List<HomeItem> verticalItems = [];
        List<HomeItem> horizontalItems = [];
        String verticalTitle = '精选内容';
        String horizontalTitle = '最新赛事';

        if (data['resultObj']?['containers'] != null) {
          final containers = data['resultObj']['containers'] as List<dynamic>;

          // 分别处理 vertical_simple_poster 和 horizontal_thumbnail
          for (final container in containers) {
            final layout = container['layout']?.toString() ?? '';

            if (layout == 'vertical_simple_poster' ||
                layout == 'vertical_thumbnail') {
              // 提取容器标题
              final containerTitle = container['title']?.toString() ?? '';

              if (container['retrieveItems']?['resultObj']?['containers'] !=
                  null) {
                final itemContainers = container['retrieveItems']['resultObj']
                    ['containers'] as List<dynamic>;

                for (final item in itemContainers) {
                  try {
                    final homeItem = HomeItem.fromJson(item);
                    // 只添加有pageid的项目
                    if (homeItem.pageid != null &&
                        homeItem.pageid!.isNotEmpty) {
                      if (layout == 'vertical_simple_poster') {
                        verticalItems.add(homeItem);
                        if (containerTitle.isNotEmpty) {
                          verticalTitle = containerTitle;
                        }
                      } else if (layout == 'vertical_thumbnail') {
                        horizontalItems.add(homeItem);
                        if (containerTitle.isNotEmpty) {
                          horizontalTitle = containerTitle;
                        }
                      }
                    }
                  } catch (e) {
                    print('Error parsing item: $e');
                  }
                }
              }
            }
          }
        }

        setState(() {
          _verticalItems = verticalItems;
          _horizontalItems = horizontalItems;
          _verticalTitle = verticalTitle;
          _horizontalTitle = horizontalTitle;
          _isLoading = false;
        });

        print('Vertical items loaded: ${_verticalItems.length}');
        print('Horizontal items loaded: ${_horizontalItems.length}');
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
      print('Error fetching home data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
            Text('Loading home data...'),
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
              onPressed: _fetchHomeData,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 页面标题
          const Text(
            'F1 TV',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '最新的F1内容',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),

          // 内容列表
          _buildItemsList(),
        ],
      ),
    );
  }

  // 构建内容列表
  Widget _buildItemsList() {
    if (_verticalItems.isEmpty && _horizontalItems.isEmpty) {
      return const Center(
        child: Text(
          '暂无内容',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 垂直海报列表 (vertical_simple_poster)
        if (_verticalItems.isNotEmpty) ...[
          Text(
            _verticalTitle,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 240, // 固定高度
            child: _buildScrollableRow(_verticalItems),
          ),
          const SizedBox(height: 32),
        ],

        // 水平缩略图列表 (vertical_thumbnail)
        if (_horizontalItems.isNotEmpty) ...[
          Text(
            _horizontalTitle,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 1.67, // 16:9.6 aspect ratio
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            itemCount: _horizontalItems.length,
            itemBuilder: (context, index) {
              return _buildHorizontalItem(_horizontalItems[index], index);
            },
          ),
        ],
      ],
    );
  }

  // 构建带有左右滚动按钮的水平列表
  Widget _buildScrollableRow(List<HomeItem> items) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    // 计算每次滚动的距离（一次滚动3个项目）
    const itemWidth = 160.0; // 项目宽度
    const itemSpacing = 12.0; // 项目间距
    const scrollDistance = (itemWidth + itemSpacing) * 3; // 滚动3个项目的距离

    return Stack(
      children: [
        // 内容列表
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40), // 为按钮留出空间
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < items.length - 1 ? itemSpacing : 0,
                ),
                child: SizedBox(
                  width: itemWidth,
                  child: _buildVerticalItem(items[index], index),
                ),
              );
            },
          ),
        ),

        // 左滚动按钮
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () {
                  // 向左滚动
                  final currentPosition = _scrollController.position.pixels;
                  final newPosition = (currentPosition - scrollDistance).clamp(
                    0.0,
                    _scrollController.position.maxScrollExtent,
                  );
                  _scrollController.animateTo(
                    newPosition,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ),
          ),
        ),

        // 右滚动按钮
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                onPressed: () {
                  // 向右滚动
                  final currentPosition = _scrollController.position.pixels;
                  final newPosition = (currentPosition + scrollDistance).clamp(
                    0.0,
                    _scrollController.position.maxScrollExtent,
                  );
                  _scrollController.animateTo(
                    newPosition,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 构建垂直海报项目
  Widget _buildVerticalItem(HomeItem item, int index) {
    // 构建图片URL
    final pictureUrl = item.metadata['pictureUrl']?.toString() ?? '';
    final imageUrl = pictureUrl.isNotEmpty
        ? 'https://f1tv.formula1.com/image-resizer/image/$pictureUrl?w=640&h=960&q=HI&o=L'
        : 'https://www.formula1.com/etc/designs/fom-website/images/f1-logo-red.png';

    // 获取内容信息
    final title = item.metadata['title']?.toString() ?? 'Unknown Item';
    final description = item.metadata['longDescription']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        print('Vertical item selected: $title');
        if (item.pageid != null) {
          NavigationHelper.pushPageInCurrentTab(
            context,
            WeekendPage(pageid: item.pageid!),
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
                padding: const EdgeInsets.all(8),
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
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建水平缩略图项目
  Widget _buildHorizontalItem(HomeItem item, int index) {
    // 构建图片URL
    final pictureUrl = item.metadata['pictureUrl']?.toString() ?? '';
    final imageUrl = pictureUrl.isNotEmpty
        ? 'https://f1tv.formula1.com/image-resizer/image/$pictureUrl?w=1024&h=576&q=HI&o=L'
        : 'https://www.formula1.com/etc/designs/fom-website/images/f1-logo-red.png';

    // 获取内容信息
    final emfAttributes = item.metadata['emfAttributes'] ?? {};
    final meetingNumber = emfAttributes['Meeting_Number']?.toString() ?? '';
    final countryName =
        emfAttributes['Global_Meeting_Country_Name']?.toString() ??
            item.metadata['title']?.toString() ??
            'Unknown Item';
    final displayDate = emfAttributes['Meeting_Display_Date']?.toString() ?? '';
    final globalTitle = emfAttributes['Global_Title']?.toString() ??
        item.metadata['longDescription']?.toString() ??
        'Unknown Item';

    return GestureDetector(
      onTap: () {
        print('Home item selected: ${item.metadata['title']}');
        print('Item ID: ${item.id}');
        print('Page ID: ${item.pageid}');
        // 使用NavigationHelper在当前tab中跳转到weekend页面
        if (item.pageid != null) {
          NavigationHelper.pushPageInCurrentTab(
            context,
            WeekendPage(pageid: item.pageid!),
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
