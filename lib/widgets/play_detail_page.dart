import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'main_layout.dart';
import '../services/app_notification_service.dart';
import '../services/global_download_manager.dart';
import '../services/download_service.dart';
import '../utils/dio_helper.dart';
import '../services/formula1_service.dart';
import '../services/n_m3u8dl_config_service.dart';

class PlayDetailPage extends StatefulWidget {
  final String itemId;
  final Dio? dio;
  final Future<String?> Function()? getSubscriptionToken;
  final Future<Map<String, dynamic>?> Function()? refreshToken;
  final Future<String> Function()? getDownloadPath;
  final Future<void> Function(String filePath, String folderPath)? onRevealFile;
  final Future<String> Function({required String url, required String title})?
  onAddDownloadTask;

  const PlayDetailPage({
    super.key,
    required this.itemId,
    this.dio,
    this.getSubscriptionToken,
    this.refreshToken,
    this.getDownloadPath,
    this.onRevealFile,
    this.onAddDownloadTask,
  });

  @override
  State<PlayDetailPage> createState() => _PlayDetailPageState();
}

class _PlayDetailPageState extends State<PlayDetailPage> {
  static const String _coverNotificationId = 'cover_download';
  static const String _streamNotificationId = 'video_stream';
  static const Set<String> _imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.bmp',
    '.avif',
  };

  Map<String, dynamic>? _metadata;
  List<dynamic>? _additionalStreams;
  bool _isLoading = true;
  bool _isDownloadingCover = false;
  bool _isFetchingStream = false;
  String? _error;
  Dio? dio;
  final String _playbackSessionId = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    _initializeDio();
  }

  Future<void> _initializeDio() async {
    try {
      // Create Dio instance with Cookie manager
      dio = widget.dio ?? await DioHelper.createDioWithCookies(enableDebug: true);
      if (!mounted) return;
      await _fetchVideoDetail();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to initialize network client: $e';
        _isLoading = false;
      });
    }
  }

  void _openSettingsTab() {
    NavigationHelper.switchTabGlobal(NavigationHelper.settingsTab);
  }

  void _openDownloadsTab() {
    NavigationHelper.switchTabGlobal(NavigationHelper.downloadTab);
  }

  Future<void> _fetchStreamToken(String playbackUrl, String title) async {
    if (_isFetchingStream) return;
    if (dio == null) {
      AppNotificationService.instance.showError(
        id: _streamNotificationId,
        title: 'Failed to load stream',
        description: 'Network client is not initialized yet.',
      );
      return;
    }

    setState(() => _isFetchingStream = true);
    try {
      AppNotificationService.instance.showLoading(
        id: _streamNotificationId,
        title: 'Getting streaming information...',
        description: title,
      );

      String? token;
      try {
        token = await (widget.getSubscriptionToken?.call() ??
            Formula1Service.getValidSubscriptionToken());
      } catch (_) {
        AppNotificationService.instance.showError(
          id: _streamNotificationId,
          title: 'F1TV sign-in required',
          description: 'Please sign in to F1TV in Settings.',
          actionLabel: 'Settings',
          onAction: _openSettingsTab,
        );
        return;
      }

      if (token == null || token.isEmpty) {
        AppNotificationService.instance.showError(
          id: _streamNotificationId,
          title: 'F1TV sign-in required',
          description: 'Please sign in to F1TV in Settings.',
          actionLabel: 'Settings',
          onAction: _openSettingsTab,
        );
        return;
      }

      await _fetchStreamData(playbackUrl, token, title);
    } finally {
      if (mounted) {
        setState(() => _isFetchingStream = false);
      } else {
        _isFetchingStream = false;
      }
    }
  }

  Future<void> _fetchStreamData(
    String playbackUrl,
    String token,
    String title, {
    bool hasRetried = false,
  }) async {
    try {
      final url =
          'https://f1tv.formula1.com/2.0/R/ENG/BIG_SCREEN_HLS/ALL/$playbackUrl&player=player_bm';
      const deviceInfo =
          'device=tvos;screen=bigscreen;os=tvos;model=appletv14.1;osVersion=16.4;appVersion=2.31.0;playerVersion=3.65.0';

      print('Requesting streaming data: $url');
      if (dio == null) {
        throw Exception('Network client not initialized');
      }
      final accountSessionId = Formula1Service.currentSessionId;
      final response = await dio!.get(
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
            'sessionid': _playbackSessionId,
            if (accountSessionId != null && accountSessionId.isNotEmpty)
              'entitlementtoken': accountSessionId,
            'ascendonToken': token,
            'x-f1-device-info': deviceInfo,
          },
        ),
      );

      if (response.statusCode == 200) {
        print('Streaming data retrieved successfully');
        final responseData = response.data;
        if (responseData is! Map) {
          AppNotificationService.instance.showError(
            id: _streamNotificationId,
            title: 'Invalid streaming response',
            description: 'Unexpected response format returned by F1TV.',
          );
          return;
        }
        try {
          final resultObj = responseData['resultObj'];
          final streamUrl = resultObj is Map
              ? resultObj['url']?.toString().trim()
              : null;
          final laUrl = resultObj is Map
              ? resultObj['laUrl']?.toString().trim()
              : null;
          final hasStreamUrl =
              streamUrl != null &&
              streamUrl.isNotEmpty &&
              streamUrl.toLowerCase() != 'null';
          final hasDrm =
              laUrl != null &&
              laUrl.isNotEmpty &&
              laUrl.toLowerCase() != 'null';

          if (!hasStreamUrl) {
            final msg =
                responseData['message']?.toString().trim() ??
                responseData['errorDescription']?.toString().trim();
            final description =
                (msg != null && msg.isNotEmpty && msg.toLowerCase() != 'null')
                ? msg
                : 'Failed to load stream URL.';
            AppNotificationService.instance.showError(
              id: _streamNotificationId,
              title: 'Failed to load stream',
              description: description,
            );
            return;
          }

          if (hasDrm) {
            AppNotificationService.instance.showError(
              id: _streamNotificationId,
              title: 'Content is DRM protected',
              description:
                  'The content is currently under DRM, please try again in a few hours.',
            );
            return;
          }

          // Request the m3u8 content first
          await _fetchAndParseM3u8Content(streamUrl, title);
        } catch (e) {
          print('Failed to parse response data: $e');
          AppNotificationService.instance.showError(
            id: _streamNotificationId,
            title: 'Failed to parse streaming data',
            description: AppNotificationService.formatError(e),
          );
        }
      } else {
        print('Streaming data request failed: ${response.statusCode}');
        AppNotificationService.instance.showError(
          id: _streamNotificationId,
          title: 'Failed to get streaming data',
          description: 'Server returned HTTP ${response.statusCode}.',
        );
      }
    } on DioException catch (e) {
      print('Streaming data request exception: $e');
      final statusCode = e.response?.statusCode;
      if (statusCode == 401 && !hasRetried) {
        final refreshedData = await (widget.refreshToken?.call() ??
            Formula1Service.refreshToken());
        final refreshedToken =
            refreshedData?['data']?['subscriptionToken'] as String?;
        if (refreshedToken != null && refreshedToken.isNotEmpty) {
          await _fetchStreamData(
            playbackUrl,
            refreshedToken,
            title,
            hasRetried: true,
          );
          return;
        }
        AppNotificationService.instance.showError(
          id: _streamNotificationId,
          title: 'F1TV session expired',
          description: 'Please sign in again in Settings.',
          actionLabel: 'Settings',
          onAction: _openSettingsTab,
        );
        return;
      }

      AppNotificationService.instance.showError(
        id: _streamNotificationId,
        title: 'Failed to get streaming data',
        description: AppNotificationService.formatError(e),
      );
    } catch (e) {
      print('Unexpected error getting streaming data: $e');
      AppNotificationService.instance.showError(
        id: _streamNotificationId,
        title: 'Failed to get streaming data',
        description: AppNotificationService.formatError(e),
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

      if (dio == null) {
        throw Exception('Network client not initialized');
      }
      final response = await dio!.get(
        url,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
        ),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = response.data;

        setState(() {
          _metadata = data['resultObj']?['containers']?[0]?['metadata'];
          _additionalStreams =
              data['resultObj']?['containers']?[0]?['metadata']?['additionalStreams'];
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
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      print('Error fetching video detail: $e');
    }
  }

  /// Download main video
  Future<void> _downloadMainVideo(String title) async {
    print('Main video download requested:');
    print('Title: $title');
    await _fetchStreamToken('CONTENT/PLAY?contentId=${widget.itemId}', title);
  }

  String _sanitizeFileNamePart(String raw, String fallback) {
    final cleaned = raw
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^[._]+|[._]+$'), '')
        .trim();
    return cleaned.isEmpty ? fallback : cleaned;
  }

  String _resolveCoverExtension(Uri uri, String? contentType) {
    final ext = path.extension(uri.path).toLowerCase();
    if (_imageExtensions.contains(ext)) {
      return ext;
    }
    final lowerType = contentType?.toLowerCase() ?? '';
    if (lowerType.contains('image/png')) return '.png';
    if (lowerType.contains('image/webp')) return '.webp';
    if (lowerType.contains('image/gif')) return '.gif';
    if (lowerType.contains('image/bmp')) return '.bmp';
    if (lowerType.contains('image/avif')) return '.avif';
    return '.jpg';
  }

  Future<void> _revealSavedFile(String filePath, String folderPath) async {
    if (widget.onRevealFile != null) {
      await widget.onRevealFile!(filePath, folderPath);
      return;
    }

    if (Platform.isMacOS) {
      final result = await Process.run('open', ['-R', filePath]);
      if (result.exitCode == 0) return;
      final fallback = await Process.run('open', [folderPath]);
      if (fallback.exitCode != 0) {
        throw Exception('Could not open folder: $folderPath');
      }
      return;
    }

    if (Platform.isWindows) {
      if (File(filePath).existsSync()) {
        await Process.run('explorer', ['/select,$filePath']);
      } else {
        await Process.run('explorer', [folderPath]);
      }
      return;
    }

    if (Platform.isLinux) {
      final result = await Process.run('xdg-open', [folderPath]);
      if (result.exitCode == 0) return;
    }

    final opened = await launchUrl(
      Uri.directory(folderPath),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      throw Exception('Could not open folder: $folderPath');
    }
  }

  /// Download cover image
  Future<void> _downloadCover(String imageUrl, String title) async {
    if (_isDownloadingCover) return;
    if (imageUrl.trim().isEmpty) {
      AppNotificationService.instance.showError(
        id: _coverNotificationId,
        title: 'Cover download failed',
        description: 'No cover image URL is available.',
      );
      return;
    }
    if (dio == null) {
      AppNotificationService.instance.showError(
        id: _coverNotificationId,
        title: 'Cover download failed',
        description: 'Network client is not initialized yet.',
      );
      return;
    }

    setState(() => _isDownloadingCover = true);
    try {
      AppNotificationService.instance.showLoading(
        id: _coverNotificationId,
        title: 'Downloading cover image...',
        description: title,
      );

      final downloadPath = await (widget.getDownloadPath?.call() ??
          DownloadService.getDownloadPath());
      final cleanTitle = _sanitizeFileNamePart(
        title,
        'cover_${widget.itemId}',
      );
      final uri = Uri.parse(imageUrl);

      print('Downloading cover from: $imageUrl');

      final response = await dio!.get<List<int>>(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data;
      if (response.statusCode != 200 || bytes == null || bytes.isEmpty) {
        throw Exception(
          'Received empty or invalid image response (${response.statusCode}).',
        );
      }

      final extension = _resolveCoverExtension(
        uri,
        response.headers.value('content-type'),
      );
      final fileName = '${cleanTitle}_cover$extension';
      final filePath = path.join(downloadPath, fileName);
      print('Saving to: $filePath');

      final targetDir = Directory(downloadPath);
      if (!targetDir.existsSync()) {
        await targetDir.create(recursive: true);
      }

      final file = File(filePath);
      await file.writeAsBytes(bytes);

      AppNotificationService.instance.showSuccess(
        id: _coverNotificationId,
        title: 'Cover saved',
        description: fileName,
        actionLabel: 'Open Folder',
        onAction: () => _revealSavedFile(filePath, downloadPath),
      );
    } catch (e) {
      print('Error downloading cover: $e');
      AppNotificationService.instance.showError(
        id: _coverNotificationId,
        title: 'Cover download failed',
        description: AppNotificationService.formatError(e),
      );
    } finally {
      if (mounted) {
        setState(() => _isDownloadingCover = false);
      } else {
        _isDownloadingCover = false;
      }
    }
  }

  /// Fetch and parse M3U8 content
  Future<void> _fetchAndParseM3u8Content(String streamUrl, String title) async {
    if (!mounted) return;
    AppNotificationService.instance.dismiss(_streamNotificationId);

    final navigator = Navigator.of(context);
    final loadingRoute = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return const AlertDialog(
          title: Text('Loading stream options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Fetching available stream options...'),
            ],
          ),
        );
      },
    );
    navigator.push(loadingRoute);

    void closeLoadingDialog() {
      if (loadingRoute.isActive) {
        navigator.removeRoute(loadingRoute);
      }
    }

    try {
      if (dio == null) {
        throw Exception('Network client not initialized');
      }
      final response = await dio!.get(
        streamUrl,
        options: Options(responseType: ResponseType.plain),
      );

      closeLoadingDialog();

      if (!mounted) return;

      if (response.statusCode == 200) {
        final m3u8Content = response.data?.toString() ?? '';
        if (m3u8Content.trim().isEmpty) {
          AppNotificationService.instance.showError(
            id: _streamNotificationId,
            title: 'Failed to fetch stream options',
            description: 'Stream playlist was empty.',
          );
          return;
        }
        await _showDownloadOptionsDialog(m3u8Content, streamUrl, title);
      } else {
        AppNotificationService.instance.showError(
          id: _streamNotificationId,
          title: 'Failed to fetch stream options',
          description: 'Server returned HTTP ${response.statusCode}.',
        );
      }
    } catch (e) {
      closeLoadingDialog();
      AppNotificationService.instance.showError(
        id: _streamNotificationId,
        title: 'Failed to fetch stream options',
        description: AppNotificationService.formatError(e),
      );
    }
  }

  /// Show download options dialog based on parsed M3U8 content
  Future<void> _showDownloadOptionsDialog(
    String m3u8Content,
    String streamUrl,
    String title,
  ) async {
    // Parse the M3U8 content to extract video streams and audio tracks
    final parsedVideoStreams = _parseVideoStreams(m3u8Content);
    final parsedAudioTracks = _parseAudioTracks(m3u8Content);
    final subtitleTracks = _parseSubtitleTracks(m3u8Content);

    bool hasHDRContent = _checkForHDRContent(m3u8Content);
    final supportedResolutions =
        N_m3u8dlConfigService.getSupportedResolutionsTitle();
    final supportedRanges = N_m3u8dlConfigService.getSupportedRanges();
    final supportedAudioLanguages =
        N_m3u8dlConfigService.getSupportedAudioLanguages();
    final supportedFormats = N_m3u8dlConfigService.getSupportedFormats();
    final availableResolutions = _matchAvailableResolutions(
      parsedVideoStreams,
      supportedResolutions,
    );
    final availableAudioLanguages = _matchAvailableAudioLanguages(
      parsedAudioTracks,
      supportedAudioLanguages,
    );
    final availableRanges = _getAvailableRanges(supportedRanges, hasHDRContent);

    // Load saved configuration
    final format = await N_m3u8dlConfigService.getFormat();
    final skipSub = await N_m3u8dlConfigService.getSkipSub();
    final resolution = await N_m3u8dlConfigService.getResolution();
    final audioLang = await N_m3u8dlConfigService.getAudioLang();
    final range = await N_m3u8dlConfigService.getRange();

    // Selected options (initialized with saved configuration)
    String selectedResolution = resolution;
    String selectedAudioLang = audioLang;
    String selectedRange = range;
    bool skipSubtitles = skipSub;
    String selectedFormat = format;
    if (!availableResolutions.any(
      (item) => item['value'] == selectedResolution,
    )) {
      selectedResolution = availableResolutions.first['value']!;
    }

    if (!availableAudioLanguages.any(
      (item) => item['value'] == selectedAudioLang,
    )) {
      selectedAudioLang = availableAudioLanguages.first['value']!;
    }

    if (!availableRanges.any((item) => item['value'] == selectedRange)) {
      selectedRange = availableRanges.first['value']!;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Download Configuration'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Title: $title',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    // Video Resolution
                    Text(
                      'Video Resolution',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedResolution,
                          items: availableResolutions
                              .map(
                                (res) => DropdownMenuItem(
                                  value: res['value'],
                                  child: Text(res['name']!),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedResolution = value!;
                            });
                          },
                          isExpanded: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Dynamic Range (only if HDR content is available)
                    if (availableRanges.length > 1) ...[
                      Text(
                        'Dynamic Range',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedRange,
                            items: availableRanges
                                .map(
                                  (range) => DropdownMenuItem(
                                    value: range['value'],
                                    child: Text(range['name']!),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedRange = value!;
                              });
                            },
                            isExpanded: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Audio Language
                    Text(
                      'Audio Language',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedAudioLang,
                          items: availableAudioLanguages
                              .map(
                                (lang) => DropdownMenuItem(
                                  value: lang['value'],
                                  child: Text(lang['name']!),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedAudioLang = value!;
                            });
                          },
                          isExpanded: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Output Format
                    Text(
                      'Output Format',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedFormat,
                          items: ['mp4', 'mkv']
                              .map(
                                (format) => DropdownMenuItem(
                                  value: format,
                                  child: Text(format.toUpperCase()),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedFormat = value!;
                            });
                          },
                          isExpanded: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Skip Subtitles
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Skip Subtitles',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'When enabled, subtitle files will not be downloaded',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        ShadSwitch(
                          value: skipSubtitles,
                          onChanged: (value) {
                            setState(() {
                              skipSubtitles = value;
                            });
                          },
                        ),
                      ],
                    ),

                    if (subtitleTracks.isNotEmpty && !skipSubtitles) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Available Subtitles:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...subtitleTracks
                          .map(
                            (track) => Text(
                              '• ${track['name']} (${track['language']})',
                              style: TextStyle(fontSize: 12),
                            ),
                          )
                          .toList(),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Save selected options to configuration service
                    await N_m3u8dlConfigService.setFormat(selectedFormat);
                    await N_m3u8dlConfigService.setSkipSub(skipSubtitles);
                    await N_m3u8dlConfigService.setResolution(
                      selectedResolution,
                    );
                    await N_m3u8dlConfigService.setAudioLang(selectedAudioLang);
                    await N_m3u8dlConfigService.setRange(selectedRange);

                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                    if (!mounted) return;
                    await _startDownloadWithOptions(
                      streamUrl,
                      title,
                      selectedResolution,
                      selectedAudioLang,
                      skipSubtitles,
                      selectedFormat,
                    );
                  },
                  child: const Text('Download'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _checkForHDRContent(String m3u8Content) {
    return m3u8Content.contains('HLG') ||
        m3u8Content.contains('HDR10') ||
        m3u8Content.contains('DOLBY-VISION');
  }

  List<Map<String, String>> _matchAvailableResolutions(
    List<Map<String, String>> parsedStreams,
    List<Map<String, String>> supportedResolutions,
  ) {
    final result = [supportedResolutions.first];

    final Set<int> availableWidths = {};
    for (final stream in parsedStreams) {
      final resolution = stream['resolution'];
      if (resolution != null) {
        final width = int.tryParse(resolution.split('x')[0]);
        if (width != null) {
          availableWidths.add(width);
        }
      }
    }

    // Match supported resolutions
    for (final supported in supportedResolutions.skip(1)) {
      final supportedWidth = int.tryParse(supported['value'] ?? '');
      if (supportedWidth != null) {
        bool hasMatchingOrLarger = availableWidths.any(
          (width) =>
              width >= supportedWidth * 0.9 && width <= supportedWidth * 1.1,
        );

        if (hasMatchingOrLarger) {
          result.add(supported);
        }
      }
    }

    return result;
  }

  List<Map<String, String>> _matchAvailableAudioLanguages(
    List<Map<String, String>> parsedTracks,
    List<Map<String, String>> supportedLanguages,
  ) {
    if (parsedTracks.isEmpty) {
      return [supportedLanguages.firstWhere((lang) => lang['value'] == 'eng')];
    }

    final Set<String> availableLanguages = {};
    for (final track in parsedTracks) {
      final language = track['language'];
      if (language != null) {
        availableLanguages.add(language.toLowerCase());
      }
    }

    final result = <Map<String, String>>[];
    for (final supported in supportedLanguages) {
      final supportedCode = supported['value']?.toLowerCase();
      if (supportedCode == 'all') {
        result.add(supported);
      } else if (supportedCode != null &&
          availableLanguages.contains(supportedCode)) {
        result.add(supported);
      }
    }

    if (result.isEmpty || !result.any((lang) => lang['value'] != 'all')) {
      result.insert(
        0,
        supportedLanguages.firstWhere((lang) => lang['value'] == 'eng'),
      );
    }

    return result;
  }

  List<Map<String, String>> _getAvailableRanges(
    List<Map<String, String>> supportedRanges,
    bool hasHDRContent,
  ) {
    final result = [
      supportedRanges.firstWhere((range) => range['value'] == 'auto'),
      supportedRanges.firstWhere((range) => range['value'] == 'SDR'),
    ];

    if (hasHDRContent) {
      result.add(
        supportedRanges.firstWhere((range) => range['value'] == 'HLG'),
      );
    }

    return result;
  }

  /// Parse video streams from M3U8 content
  List<Map<String, String>> _parseVideoStreams(String m3u8Content) {
    final List<Map<String, String>> streams = [];
    final lines = m3u8Content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('#EXT-X-STREAM-INF:')) {
        final streamInfo = lines[i];
        String? resolution;
        String? bandwidth;
        String? codecs;

        // Extract resolution
        final resMatch = RegExp(r'RESOLUTION=(\d+x\d+)').firstMatch(streamInfo);
        if (resMatch != null) {
          resolution = resMatch.group(1);
        }

        // Extract bandwidth
        final bwMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(streamInfo);
        if (bwMatch != null) {
          final bw = int.parse(bwMatch.group(1)!);
          if (bw > 1000000) {
            bandwidth = '${(bw / 1000000).toStringAsFixed(1)} Mbps';
          } else {
            bandwidth = '${(bw / 1000).toStringAsFixed(0)} Kbps';
          }
        }

        // Extract codecs
        final codecsMatch = RegExp(r'CODECS="([^"]+)"').firstMatch(streamInfo);
        if (codecsMatch != null) {
          codecs = codecsMatch.group(1);
        }

        if (resolution != null && bandwidth != null && i + 1 < lines.length) {
          streams.add({
            'resolution': resolution,
            'bandwidth': bandwidth,
            'codecs': codecs ?? '',
            'url': lines[i + 1].trim(),
          });
        }
      }
    }

    return streams;
  }

  /// Parse audio tracks from M3U8 content
  List<Map<String, String>> _parseAudioTracks(String m3u8Content) {
    final List<Map<String, String>> tracks = [];
    final lines = m3u8Content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('#EXT-X-MEDIA:TYPE=AUDIO')) {
        final audioInfo = lines[i];
        String? name;
        String? language;
        String? uri;

        // Extract name
        final nameMatch = RegExp(r'NAME="([^"]+)"').firstMatch(audioInfo);
        if (nameMatch != null) {
          name = nameMatch.group(1);
        }

        // Extract language
        final langMatch = RegExp(r'LANGUAGE="([^"]+)"').firstMatch(audioInfo);
        if (langMatch != null) {
          language = langMatch.group(1);
        }

        // Extract URI
        final uriMatch = RegExp(r'URI="([^"]+)"').firstMatch(audioInfo);
        if (uriMatch != null) {
          uri = uriMatch.group(1);
        }

        if (name != null && language != null && uri != null) {
          tracks.add({'name': name, 'language': language, 'uri': uri});
        }
      }
    }

    // If no audio tracks found, add a default one
    if (tracks.isEmpty) {
      tracks.add({'name': 'Default Audio', 'language': 'eng', 'uri': ''});
    }

    return tracks;
  }

  /// Parse subtitle tracks from M3U8 content
  List<Map<String, String>> _parseSubtitleTracks(String m3u8Content) {
    final List<Map<String, String>> tracks = [];
    final lines = m3u8Content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('#EXT-X-MEDIA:TYPE=SUBTITLES')) {
        final subInfo = lines[i];
        String? name;
        String? language;
        String? uri;

        // Extract name
        final nameMatch = RegExp(r'NAME="([^"]+)"').firstMatch(subInfo);
        if (nameMatch != null) {
          name = nameMatch.group(1);
        }

        // Extract language
        final langMatch = RegExp(r'LANGUAGE="([^"]+)"').firstMatch(subInfo);
        if (langMatch != null) {
          language = langMatch.group(1);
        }

        // Extract URI
        final uriMatch = RegExp(r'URI="([^"]+)"').firstMatch(subInfo);
        if (uriMatch != null) {
          uri = uriMatch.group(1);
        }

        if (name != null && language != null && uri != null) {
          tracks.add({'name': name, 'language': language, 'uri': uri});
        }
      }
    }

    return tracks;
  }

  /// Start download with selected options
  Future<void> _startDownloadWithOptions(
    String streamUrl,
    String title,
    String resolution,
    String audioLang,
    bool skipSub,
    String format,
  ) async {
    try {
      // Add to global download manager
      final addTask =
          widget.onAddDownloadTask ??
          ({required String url, required String title}) =>
              GlobalDownloadManager().addDownloadTask(url: url, title: title);
      final taskId = await addTask(url: streamUrl, title: title);

      // Show download progress
      _showDownloadProgress(taskId, title);
    } catch (e) {
      AppNotificationService.instance.showError(
        id: _streamNotificationId,
        title: 'Failed to start download',
        description: AppNotificationService.formatError(e),
      );
    }
  }

  /// Show download progress
  void _showDownloadProgress(String taskId, String title) {
    AppNotificationService.instance.showSuccess(
      id: 'video_download_$taskId',
      title: 'Added to download queue',
      description: title,
      actionLabel: 'Downloads',
      onAction: _openDownloadsTab,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        elevation: 0,
        leading: ShadIconButton.ghost(
          icon: const Icon(LucideIcons.arrowLeft, size: 18),
          onPressed: () => NavigationHelper.popPageInCurrentTab(context),
        ),
        title: Text('Play Detail', style: theme.textTheme.h4),
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
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Error',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
          // Video basic information
          _buildVideoInfo(),
          const SizedBox(height: 24),

          // Additional Streams section (only shown when there is content)
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video cover
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
                  // Download cover button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        onPressed: _isDownloadingCover
                            ? null
                            : () => _downloadCover(imageUrl, title),
                        icon: _isDownloadingCover
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.download,
                                color: Colors.white,
                                size: 20,
                              ),
                        tooltip: 'Download Cover',
                      ),
                    ),
                  ),
                ],
              ),
            if (imageUrl != null) const SizedBox(height: 16),

            // Title
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            // Subtitle
            if (titleBrief.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                titleBrief,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],

            // Description
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ],

            // Video ID
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

            // Download button
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isFetchingStream
                    ? null
                    : () => _downloadMainVideo(title),
                icon: const Icon(Icons.download),
                label: const Text('Download Video'),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
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
        if (_isFetchingStream) return;
        final playbackUrl = stream['playbackUrl']?.toString().trim() ?? '';
        final mainTitle = _metadata?['title']?.toString().trim() ?? '';
        final streamTitle = mainTitle.isNotEmpty ? '$mainTitle-$title' : title;
        if (playbackUrl.isNotEmpty) {
          await _fetchStreamToken(playbackUrl, streamTitle);
        } else {
          AppNotificationService.instance.showError(
            id: _streamNotificationId,
            title: 'Unavailable stream',
            description: 'No playback URL available for: $title',
          );
        }
      },
    );
  }
}
