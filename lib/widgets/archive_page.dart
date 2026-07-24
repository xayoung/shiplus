import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shiplus/widgets/play_detail_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'dart:convert';
import 'season_page.dart';
import 'main_layout.dart';
import '../utils/dio_helper.dart';
import 'ui/shiplus_ui.dart';

// Data model class
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
    // Extract data from metadata
    final metadata = json['metadata'] ?? {};
    final actions = json['actions'] as List<dynamic>? ?? [];

    // Extract pageid from actions
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

      final dio = await DioHelper.createDioWithCookies();
      final response = await dio.get(
        'https://f1tv.formula1.com/2.0/R/ENG/WEB_DASH/ALL/PAGE/493/F1_TV_Pro_Annual/3',
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // Parse data according to React Native version logic
        List<ArchiveItem> seasonsArray = [];

        if (data['resultObj']?['containers'] != null) {
          final containers = data['resultObj']['containers'] as List<dynamic>;

          // Iterate through all containers to find containers with retrieveItems
          for (int i = 0; i < containers.length; i++) {
            final container = containers[i];

            if (container['retrieveItems']?['resultObj']?['containers'] !=
                null) {
              final itemContainers =
                  container['retrieveItems']['resultObj']['containers']
                      as List<dynamic>;

              // Add found items to seasonsArray
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
          _error = 'Request failed: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
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
            // Page title
            ShiplusPageHeader(
              title: 'Archive',
              description: 'Explore the full Formula 1 content catalogue.',
              icon: LucideIcons.archive,
              actions: [
                ShadIconButton.outline(
                  onPressed: _fetchData,
                  icon: const Icon(LucideIcons.refreshCw, size: 17),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Content area
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const ShiplusLoadingState();
    }

    if (_error != null) {
      return ShiplusErrorState(
        title: 'Archive failed to load',
        message: _error!,
        onRetry: _fetchData,
      );
    }

    if (_items.isEmpty) {
      return const ShiplusEmptyState(
        title: 'No archive content',
        description: 'No content is available for this account.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        if (constraints.maxWidth < 600) {
          crossAxisCount = 2;
        } else if (constraints.maxWidth < 900) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth < 1200) {
          crossAxisCount = 4;
        } else {
          crossAxisCount = 5;
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
    String imageUrl = item.imageUrl.isNotEmpty
        ? 'https://f1tv.formula1.com/image-resizer/image/${item.imageUrl}?w=1024&h=576&q=HI&o=L'
        : 'https://www.formula1.com/etc/designs/fom-website/images/f1-logo-red.png';

    return ShadCard(
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
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
            ),
          ],
        ),
      ),
    );
  }
}
