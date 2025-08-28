import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'main_layout.dart';
import '../services/global_download_manager.dart';
import '../services/download_service.dart';
import '../utils/dio_helper.dart';
import '../services/formula1_service.dart';
import '../services/n_m3u8dl_config_service.dart';

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
      // Create Dio instance with Cookie manager
    dio = DioHelper.createDioWithCookies(enableDebug: true);
    _fetchVideoDetail();
  }

  Future<void> _fetchStreamToken(String playbackUrl, String title) async {
    try {
      // Show loading hint
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Getting streaming information: $title'),
          duration: const Duration(seconds: 2),
        ),
      );
      final token = await Formula1Service.currentUserData!['data']['subscriptionToken'];
      await _fetchStreamData(playbackUrl, token, title);
    } catch (e) {
      // print('Token request exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Need Logged in F1TV. 「 Settings - Login to F1TV 」'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
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

      print('Requesting streaming data: $url');
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
        print('Streaming data retrieved successfully');
        print('Response: ${response.data}');
        final responseData = response.data;
        try {
          final streamUrl = responseData['resultObj']?['url']?.toString();
          final laUrl = responseData['resultObj']?['laUrl']?.toString();
          if (streamUrl != null) {

            if(laUrl != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('The content is currently under DRM, please try again in a few hours'),
                  duration: const Duration(seconds: 3),
                  backgroundColor: Colors.red,
                ),
              );
            } else {
              // Request the m3u8 content first
              await _fetchAndParseM3u8Content(streamUrl, title);
            }
            
            
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
          print('Failed to parse response data: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to parse streaming data: $e'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }  else {
        print('Streaming data request failed: ${response.statusCode}');
        print('Response: ${response.data}');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get streaming data: ${response.statusCode}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on DioException catch (e) {
      print('Streaming data request exception: $e');
      if (e.response != null) {
        // Server returned error
        final statusCode = e.response!.statusCode;
        final errorData = e.response!.data;
        print('Status code: $statusCode, Error data: $errorData');
        if (statusCode == 401) {
          final refreshedData = await Formula1Service.refreshToken();
          final refresToken = refreshedData!['data']['subscriptionToken'];
          await _fetchStreamData(playbackUrl, refresToken, title);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to get streaming data: $errorData'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Other errors
        print('Unknown error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to get streaming data: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
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

  /// Download main video
  Future<void> _downloadMainVideo(String title) async {
    print('Main video download requested:');
    print('Title: $title');
    await _fetchStreamToken('CONTENT/PLAY?contentId=${widget.itemId}', title);
  }

  /// Download cover image
  Future<void> _downloadCover(String imageUrl, String title) async {
    try {
      // 显示开始下载的提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Starting cover download...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Get download path
      final downloadPath = await DownloadService.getDownloadPath();

      // Clean filename, remove unsafe characters
      final cleanTitle = title
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .replaceAll(RegExp(r'\s+'), '_')
          .trim();

      // Get image extension
      final uri = Uri.parse(imageUrl);
      String extension = path.extension(uri.path);
      if (extension.isEmpty) {
        extension = '.jpg'; // Default to jpg extension
      }

      // Build filename
      final fileName = '${cleanTitle}_cover$extension';
      final filePath = path.join(downloadPath, fileName);

      print('Downloading cover from: $imageUrl');
      print('Saving to: $filePath');

      // Download image
      final response = await dio.get(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      // Save file
      final file = File(filePath);
      await file.writeAsBytes(response.data);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cover download successful: $fileName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                // Could add functionality to open folder
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
            content: Text('Cover download failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Fetch and parse M3U8 content
  Future<void> _fetchAndParseM3u8Content(String streamUrl, String title) async {
    // Show loading dialog
    BuildContext? dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        dialogContext = context;
        return AlertDialog(
          title: const Text('Loading stream options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Fetching available stream options...'),
            ],
          ),
        );
      },
    );
    
    try {
      // Request the m3u8 content
      final response = await dio.get(
        streamUrl,
        options: Options(
          responseType: ResponseType.plain,
        ),
      );
      
      // Close loading dialog
      if (mounted && dialogContext != null) {
        Navigator.pop(dialogContext!);
      }
      
      if (response.statusCode == 200) {
        final m3u8Content = response.data.toString();
        _showDownloadOptionsDialog(m3u8Content, streamUrl, title);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch stream options: ${response.statusCode}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still showing
      if (mounted && dialogContext != null) {
        Navigator.pop(dialogContext!);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching stream options: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  
  /// Show download options dialog based on parsed M3U8 content
  Future<void> _showDownloadOptionsDialog(String m3u8Content, String streamUrl, String title) async {
    // Parse the M3U8 content to extract video streams and audio tracks
    final parsedVideoStreams = _parseVideoStreams(m3u8Content);
    final parsedAudioTracks = _parseAudioTracks(m3u8Content);
    final subtitleTracks = _parseSubtitleTracks(m3u8Content);
  
    bool hasHDRContent = _checkForHDRContent(m3u8Content);
    final supportedResolutions = N_m3u8dlConfigService.getSupportedResolutionsTitle();
    final supportedRanges = N_m3u8dlConfigService.getSupportedRanges();
    final supportedAudioLanguages = N_m3u8dlConfigService.getSupportedAudioLanguages();
    final supportedFormats = N_m3u8dlConfigService.getSupportedFormats();
    final availableResolutions = _matchAvailableResolutions(parsedVideoStreams, supportedResolutions);
    final availableAudioLanguages = _matchAvailableAudioLanguages(parsedAudioTracks, supportedAudioLanguages);
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
    if (!availableResolutions.any((item) => item['value'] == selectedResolution)) {
      selectedResolution = availableResolutions.first['value']!;
    }
    
    if (!availableAudioLanguages.any((item) => item['value'] == selectedAudioLang)) {
      selectedAudioLang = availableAudioLanguages.first['value']!;
    }
    
    if (!availableRanges.any((item) => item['value'] == selectedRange)) {
      selectedRange = availableRanges.first['value']!;
    }
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                          items: availableResolutions.map((res) => DropdownMenuItem(
                            value: res['value'],
                            child: Text(res['name']!),
                          )).toList(),
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
                            items: availableRanges.map((range) => DropdownMenuItem(
                              value: range['value'],
                              child: Text(range['name']!),
                            )).toList(),
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
                          items: availableAudioLanguages.map((lang) => DropdownMenuItem(
                            value: lang['value'],
                            child: Text(lang['name']!),
                          )).toList(),
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
                          items: ['mp4', 'mkv'].map((format) => DropdownMenuItem(
                            value: format,
                            child: Text(format.toUpperCase())
                          )).toList(),
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
                        Switch(
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
                      ...subtitleTracks.map((track) => Text(
                        '• ${track['name']} (${track['language']})',
                        style: TextStyle(fontSize: 12),
                      )).toList(),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Save selected options to configuration service
                    await N_m3u8dlConfigService.setFormat(selectedFormat);
                    await N_m3u8dlConfigService.setSkipSub(skipSubtitles);
                    await N_m3u8dlConfigService.setResolution(selectedResolution);
                    await N_m3u8dlConfigService.setAudioLang(selectedAudioLang);
                    await N_m3u8dlConfigService.setRange(selectedRange);
                    
                    Navigator.of(context).pop();
                    _startDownloadWithOptions(
                      streamUrl, 
                      title, 
                      selectedResolution, 
                      selectedAudioLang, 
                      skipSubtitles,
                      selectedFormat
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
    List<Map<String, String>> supportedResolutions
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
        bool hasMatchingOrLarger = availableWidths.any((width) => 
          width >= supportedWidth * 0.9 && width <= supportedWidth * 1.1);
        
        if (hasMatchingOrLarger) {
          result.add(supported);
        }
      }
    }
    
    return result;
  }
  
  List<Map<String, String>> _matchAvailableAudioLanguages(
    List<Map<String, String>> parsedTracks, 
    List<Map<String, String>> supportedLanguages
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
      } else if (supportedCode != null && availableLanguages.contains(supportedCode)) {
        result.add(supported);
      }
    }
    
    if (result.isEmpty || !result.any((lang) => lang['value'] != 'all')) {
      result.insert(0, supportedLanguages.firstWhere((lang) => lang['value'] == 'eng'));
    }
    
    return result;
  }

  List<Map<String, String>> _getAvailableRanges(
    List<Map<String, String>> supportedRanges, 
    bool hasHDRContent
  ) {

    final result = [
      supportedRanges.firstWhere((range) => range['value'] == 'auto'),
      supportedRanges.firstWhere((range) => range['value'] == 'SDR'),
    ];

    if (hasHDRContent) {
      result.add(supportedRanges.firstWhere((range) => range['value'] == 'HLG'));
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
          tracks.add({
            'name': name,
            'language': language,
            'uri': uri,
          });
        }
      }
    }
    
    // If no audio tracks found, add a default one
    if (tracks.isEmpty) {
      tracks.add({
        'name': 'Default Audio',
        'language': 'eng',
        'uri': '',
      });
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
          tracks.add({
            'name': name,
            'language': language,
            'uri': uri,
          });
        }
      }
    }
    
    return tracks;
  }
  
  /// Start download with selected options
  void _startDownloadWithOptions(
    String streamUrl, 
    String title, 
    String resolution, 
    String audioLang, 
    bool skipSub,
    String format
  ) async {
    try {
      // Prepare extra arguments based on selected options
      List<String> extraArgs = [];
      
      // 获取视频选择参数
      final range = await N_m3u8dlConfigService.getRange();
      String videoSelectParam;
      
      if (range == 'auto') {
        if (resolution == 'best') {
          videoSelectParam = 'best';
        } else {
          videoSelectParam = 'res="${resolution}*":for=best';
        }
      } else {
        if (resolution == 'best') {
          videoSelectParam = ':range=$range:for=best';
        } else {
          videoSelectParam = 'res="${resolution}*":range=$range:for=best';
        }
      }
      
      // Add resolution and range selection
      if (videoSelectParam != 'best') {
        extraArgs.add('-sv');
        extraArgs.add(videoSelectParam);
      }
      
      // Add audio language selection
      if (audioLang != 'eng') {
        extraArgs.add('-sa');
        extraArgs.add(audioLang);
      }
      
      // Add format and subtitle options
      extraArgs.add('-M');
      extraArgs.add('format=$format:muxer=ffmpeg:skip_sub=$skipSub');
      
      // Add to global download manager
      final downloadManager = GlobalDownloadManager();
      final taskId = await downloadManager.addDownloadTask(
        url: streamUrl,
        title: title,
      );
      
      // Show download progress
      _showDownloadProgress(taskId, title);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start download: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  
  /// Show download progress
  void _showDownloadProgress(String taskId, String title) {
    final downloadManager = GlobalDownloadManager();

    // 显示初始的 SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting download: $title'),
        duration: const Duration(seconds: 2)
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
                        onPressed: () => _downloadCover(imageUrl, title),
                        icon: const Icon(
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
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            // Subtitle
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

            // Description
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
                onPressed: () => _downloadMainVideo(title),
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
        final playbackUrl = stream['playbackUrl']?.toString() ?? '';
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
