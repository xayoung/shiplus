import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../ffi/n_m3u8dl_re.dart';
import '../models/download_progress.dart';

/// Download service class, responsible for managing video download functionality
class DownloadService {
  static String? _customDownloadPath;

  /// Get download path
  ///
  /// Priority: use user-set custom path if available,
  /// try system Downloads directory (macOS and Windows),
  /// fallback to application documents directory downloads folder
  static Future<String> getDownloadPath() async {
    try {
      // 1. First try to use custom path
      if (_customDownloadPath != null && _customDownloadPath!.isNotEmpty) {
        final dir = Directory(_customDownloadPath!);
        await dir.create(recursive: true);

        // Test if directory is writable
        final testFile = File('${dir.path}/.write_test');
        try {
          await testFile.writeAsString('test');
          await testFile.delete();
          print('Using custom download path: ${_customDownloadPath!}');
          return _customDownloadPath!;
        } catch (e) {
          print('Custom path not writable, fallback to system download path: $e');
        }
      }

      // 2. On macOS and Windows, try to use system Downloads directory
      if (Platform.isMacOS || Platform.isWindows) {
        try {
          final downloadsDir = await getDownloadsDirectory();
          if (downloadsDir != null) {
            // Test if directory is writable
            final testFile = File('${downloadsDir.path}/.write_test');
            try {
              await testFile.writeAsString('test');
              await testFile.delete();
              print('Using system download path: ${downloadsDir.path}');
              return downloadsDir.path;
            } catch (e) {
              print('System download path not writable, fallback to app documents directory: $e');
            }
          } else {
            print('System download path not available, fallback to app documents directory');
          }
        } catch (e) {
          print('Failed to get system download path, fallback to app documents directory: $e');
        }
      } else {
        print('Current platform does not support system download directory, using app documents directory');
      }

      // 3. Use downloads folder in app documents directory as final fallback
      final directory = await getApplicationDocumentsDirectory();
      final downloadPath = '${directory.path}/downloads';
      final dir = Directory(downloadPath);
      await dir.create(recursive: true);
      print('Using app documents directory download path: $downloadPath');
      return downloadPath;
    } catch (e) {
      print('Failed to get download path: $e');
      // Final fallback
      final directory = await getApplicationDocumentsDirectory();
      final downloadPath = '${directory.path}/downloads';
      final dir = Directory(downloadPath);
      await dir.create(recursive: true);
      return downloadPath;
    }
  }

  /// Set custom download path
  static void setDownloadPath(String path) {
    _customDownloadPath = path.trim();
    print('Set download path to: $_customDownloadPath');
  }

  /// Clear custom download path, restore to default path
  static void clearCustomDownloadPath() {
    _customDownloadPath = null;
    print('Cleared custom download path, will use default path');
  }

  /// Download video
  ///
  /// [url] M3U8 video link
  /// [fileName] File name to save (without extension)
  /// [audioLang] Audio language selection, options: eng, deu, fra, spa, nld, por, fx, all
  /// [extraArgs] Additional N_m3u8DL-RE command line arguments
  /// [onLog] Log callback function for real-time download logs
  ///
  /// Throws exception if download fails
  static Future<void> downloadVideo(
    String url,
    String saveDir, // Modified parameter order, added saveDir parameter
    String fileName, {
    String? taskId, // New task ID parameter
    String audioLang = '', // Audio language selection, empty string means use default from config
    List<String>? extraArgs,
    Function(String)? onLog,
    Function(DownloadProgress)? onProgress, // Add progress callback
  }) async {
    if (url.trim().isEmpty) {
      throw Exception('Video URL cannot be empty');
    }

    if (fileName.trim().isEmpty) {
      throw Exception('File name cannot be empty');
    }

    // Clean filename, remove unsafe characters
    final cleanFileName = _sanitizeFileName(fileName);

    try {
      print('Starting video download to: $saveDir');

      onLog?.call('🚀 Starting download: $cleanFileName');
      onLog?.call('📁 Save directory: $saveDir');
      onLog?.call('🔗 Video link: $url');

      final result = await N_m3u8DL_RE.downloadVideo(
        url,
        saveDir,
        cleanFileName,
        taskId: taskId, // Pass task ID
        audioLang: audioLang, // Pass audio language selection
        extraArgs: extraArgs,
        onLog: onLog,
        onProgress: onProgress, // Pass progress callback
      );

      if (result != 0) {
        throw Exception('ERROR: $result');
      }

      // print('Video download successful: $cleanFileName');
      // onLog?.call('🎉 Video download successful: $cleanFileName');
    } catch (e) {
      // print('Error occurred while downloading video: $e');
      rethrow;
    }
  }

  /// Clean filename, remove unsafe characters
  static String _sanitizeFileName(String fileName) {
    // Remove or replace unsafe characters
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }

  /// 检查下载目录是否可用
  static Future<bool> isDownloadPathAccessible() async {
    try {
      final path = await getDownloadPath();
      final dir = Directory(path);
      return dir.existsSync();
    } catch (e) {
      return false;
    }
  }
}
