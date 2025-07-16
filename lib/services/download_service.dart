import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../ffi/n_m3u8dl_re.dart';
import '../models/download_progress.dart';

/// 下载服务类，负责管理视频下载功能
class DownloadService {
  static String? _customDownloadPath;

  /// 获取下载路径
  ///
  /// 优先使用用户设置的自定义路径，如果没有设置或路径不可用，
  /// 尝试使用系统的Downloads目录（macOS和Windows平台），
  /// 如果不可用，则使用应用文档目录下的downloads文件夹
  static Future<String> getDownloadPath() async {
    try {
      // 1. 首先尝试使用自定义路径
      if (_customDownloadPath != null && _customDownloadPath!.isNotEmpty) {
        final dir = Directory(_customDownloadPath!);
        await dir.create(recursive: true);

        // 测试目录是否可写
        final testFile = File('${dir.path}/.write_test');
        try {
          await testFile.writeAsString('test');
          await testFile.delete();
          print('使用自定义下载路径: ${_customDownloadPath!}');
          return _customDownloadPath!;
        } catch (e) {
          print('自定义路径不可写，回退到系统下载路径: $e');
        }
      }

      // 2. 在macOS和Windows平台上，尝试使用系统的Downloads目录
      if (Platform.isMacOS || Platform.isWindows) {
        try {
          final downloadsDir = await getDownloadsDirectory();
          if (downloadsDir != null) {
            // 测试目录是否可写
            final testFile = File('${downloadsDir.path}/.write_test');
            try {
              await testFile.writeAsString('test');
              await testFile.delete();
              print('使用系统下载路径: ${downloadsDir.path}');
              return downloadsDir.path;
            } catch (e) {
              print('系统下载路径不可写，回退到应用文档目录: $e');
            }
          } else {
            print('系统下载路径不可用，回退到应用文档目录');
          }
        } catch (e) {
          print('获取系统下载路径失败，回退到应用文档目录: $e');
        }
      } else {
        print('当前平台不支持系统下载目录，使用应用文档目录');
      }

      // 3. 使用应用文档目录下的downloads文件夹作为最后的回退方案
      final directory = await getApplicationDocumentsDirectory();
      final downloadPath = '${directory.path}/downloads';
      final dir = Directory(downloadPath);
      await dir.create(recursive: true);
      print('使用应用文档目录下载路径: $downloadPath');
      return downloadPath;
    } catch (e) {
      print('获取下载路径失败: $e');
      // 最后的回退方案
      final directory = await getApplicationDocumentsDirectory();
      final downloadPath = '${directory.path}/downloads';
      final dir = Directory(downloadPath);
      await dir.create(recursive: true);
      return downloadPath;
    }
  }

  /// 设置自定义下载路径
  static void setDownloadPath(String path) {
    _customDownloadPath = path.trim();
    print('设置下载路径为: $_customDownloadPath');
  }

  /// 清除自定义下载路径，恢复使用默认路径
  static void clearCustomDownloadPath() {
    _customDownloadPath = null;
    print('已清除自定义下载路径，将使用默认路径');
  }

  /// 下载视频
  ///
  /// [url] M3U8视频链接
  /// [fileName] 保存的文件名（不包含扩展名）
  /// [extraArgs] 额外的N_m3u8DL-RE命令行参数
  /// [onLog] 日志回调函数，用于实时接收下载日志
  ///
  /// 抛出异常如果下载失败
  static Future<void> downloadVideo(
    String url,
    String saveDir, // 修改参数顺序，添加saveDir参数
    String fileName, {
    String? taskId, // 新增任务ID参数
    List<String>? extraArgs,
    Function(String)? onLog,
    Function(DownloadProgress)? onProgress, // 添加进度回调
  }) async {
    if (url.trim().isEmpty) {
      throw Exception('视频URL不能为空');
    }

    if (fileName.trim().isEmpty) {
      throw Exception('文件名不能为空');
    }

    // 清理文件名，移除不安全的字符
    final cleanFileName = _sanitizeFileName(fileName);

    try {
      print('开始下载视频到: $saveDir');

      onLog?.call('🚀 开始下载: $cleanFileName');
      onLog?.call('📁 保存目录: $saveDir');
      onLog?.call('🔗 视频链接: $url');

      final result = await N_m3u8DL_RE.downloadVideo(
        url,
        saveDir,
        cleanFileName,
        taskId: taskId, // 传递任务ID
        extraArgs: extraArgs,
        onLog: onLog,
        onProgress: onProgress, // 传递进度回调
      );

      if (result != 0) {
        throw Exception('下载失败，退出码: $result');
      }

      print('视频下载成功: $cleanFileName');
      onLog?.call('🎉 视频下载成功: $cleanFileName');
    } catch (e) {
      print('下载视频时发生错误: $e');
      rethrow;
    }
  }

  /// 清理文件名，移除不安全的字符
  static String _sanitizeFileName(String fileName) {
    // 移除或替换不安全的字符
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
