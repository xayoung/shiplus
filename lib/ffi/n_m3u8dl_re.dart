import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../services/n_m3u8dl_config_service.dart';
import '../models/download_progress.dart';
import '../services/proxy_service.dart';

/// 音频语言选择枚举
enum AudioLanguage {
  english('eng', 'English'),
  german('deu', 'Deutsch'),
  french('fra', 'Français'),
  spanish('spa', 'Español'),
  dutch('nld', 'Nederlands'),
  portuguese('por', 'Português'),
  fx('fx', 'FX'),
  all('all', 'All Languages');

  const AudioLanguage(this.code, this.displayName);

  final String code;
  final String displayName;

  /// 根据代码获取语言
  static AudioLanguage fromCode(String code) {
    return AudioLanguage.values.firstWhere(
      (lang) => lang.code == code,
      orElse: () => AudioLanguage.english,
    );
  }

  /// 获取所有可用的语言代码
  static List<String> get allCodes =>
      AudioLanguage.values.map((e) => e.code).toList();
}

class N_m3u8DL_RE {
  // 存储正在运行的进程，用于取消下载
  static final Map<String, Process> _runningProcesses = {};

  static Future<String> get _execPath async {
    // 获取应用程序的支持目录
    final appSupportDir = await getApplicationSupportDirectory();
    if (!appSupportDir.existsSync()) {
      appSupportDir.createSync(recursive: true);
    }

    // 确定可执行文件名和路径
    final execName = Platform.isWindows ? 'N_m3u8DL-RE.exe' : 'N_m3u8DL-RE';
    final execInAppSupport = File('${appSupportDir.path}/$execName');
    if (!execInAppSupport.existsSync()) {
      try {
        // 从assets中加载可执行文件
        final assetPath = 'assets/bin/$execName';

        print('从assets加载可执行文件: $assetPath');
        print('目标路径: ${execInAppSupport.path}');

        // 加载asset文件数据
        final ByteData data = await rootBundle.load(assetPath);
        final Uint8List bytes = data.buffer.asUint8List();

        // 写入到应用支持目录
        await execInAppSupport.writeAsBytes(bytes);

        // 在macOS/Linux上设置可执行权限
        if (Platform.isMacOS || Platform.isLinux) {
          // 使用755权限确保可执行
          final result =
              await Process.run('chmod', ['755', execInAppSupport.path]);
          if (result.exitCode != 0) {
            print('设置可执行权限失败: ${result.stderr}');
            // 尝试备用权限设置
            final result2 =
                await Process.run('chmod', ['u+x', execInAppSupport.path]);
            if (result2.exitCode != 0) {
              print('备用权限设置也失败: ${result2.stderr}');
            }
          } else {
            print('成功设置可执行权限 (755)');
          }

          // 验证文件权限
          final lsResult =
              await Process.run('ls', ['-la', execInAppSupport.path]);
          print('文件权限信息: ${lsResult.stdout}');
        }

        print('成功从assets提取可执行文件到: ${execInAppSupport.path}');
      } catch (e) {
        print('从assets提取可执行文件失败: $e');
        throw Exception('无法从应用资源中提取N_m3u8DL-RE可执行文件: $e');
      }
    }

    return execInAppSupport.path;
  }

  /// 获取ffmpeg可执行文件路径
  static Future<String> get _ffmpegPath async {
    // 获取应用程序的支持目录
    final appSupportDir = await getApplicationSupportDirectory();
    if (!appSupportDir.existsSync()) {
      appSupportDir.createSync(recursive: true);
    }

    // 确定ffmpeg可执行文件名和路径
    final ffmpegName = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
    final ffmpegInAppSupport = File('${appSupportDir.path}/$ffmpegName');
    if (!ffmpegInAppSupport.existsSync()) {
      try {
        // 从assets中加载ffmpeg可执行文件
        final assetPath = 'assets/bin/$ffmpegName';

        print('从assets加载ffmpeg可执行文件: $assetPath');
        print('目标路径: ${ffmpegInAppSupport.path}');

        // 加载asset文件数据
        final ByteData data = await rootBundle.load(assetPath);
        final Uint8List bytes = data.buffer.asUint8List();

        // 写入到应用支持目录
        await ffmpegInAppSupport.writeAsBytes(bytes);

        // 在macOS/Linux上设置可执行权限
        if (Platform.isMacOS || Platform.isLinux) {
          final result =
              await Process.run('chmod', ['755', ffmpegInAppSupport.path]);
          if (result.exitCode != 0) {
            print('设置ffmpeg可执行权限失败: ${result.stderr}');
          } else {
            print('成功设置ffmpeg可执行权限 (755)');
          }
        }

        print('成功从assets提取ffmpeg可执行文件到: ${ffmpegInAppSupport.path}');
      } catch (e) {
        print('从assets提取ffmpeg可执行文件失败: $e');
        throw Exception('无法从应用资源中提取ffmpeg可执行文件: $e');
      }
    }

    return ffmpegInAppSupport.path;
  }

  /// 下载M3U8视频
  ///
  /// [url] 视频的M3U8链接
  /// [saveDir] 保存目录路径
  /// [saveName] 保存的文件名
  /// [audioLang] 音频语言选择，可选值: eng、deu、fra、spa、nld、por、fx、all，默认为 eng
  /// [extraArgs] 额外的命令行参数，如 ['-M', 'format=mp4:muxer=ffmpeg']
  /// [onLog] 日志回调函数，用于实时接收N_m3u8DL-RE的输出
  /// [onProgress] 进度回调函数，用于实时接收下载进度信息
  ///
  /// 自动从assets/bin/目录加载N_m3u8DL-RE和ffmpeg可执行文件
  /// 并通过--ffmpeg-binary-path参数指定ffmpeg路径
  ///
  /// 返回下载结果的退出码，0表示成功
  static Future<int> downloadVideo(
    String url,
    String saveDir,
    String saveName, {
    String? taskId, // 新增任务ID参数
    String audioLang = 'eng', // 音频语言选择，默认为英语
    List<String>? extraArgs,
    Function(String)? onLog,
    Function(DownloadProgress)? onProgress, // 新增进度回调
  }) async {
    print('开始下载视频: $url');
    print('保存目录: $saveDir');
    print('文件名: $saveName');

    // 获取可执行文件路径
    final execPath = await _execPath;
    print('使用可执行文件: $execPath');

    // 获取ffmpeg可执行文件路径
    final ffmpegPath = await _ffmpegPath;
    print('使用ffmpeg可执行文件: $ffmpegPath');

    // 检查可执行文件是否存在
    final execFile = File(execPath);
    if (!execFile.existsSync()) {
      throw Exception('N_m3u8DL-RE可执行文件不存在: $execPath');
    }

    // 检查ffmpeg可执行文件是否存在
    final ffmpegFile = File(ffmpegPath);
    if (!ffmpegFile.existsSync()) {
      throw Exception('ffmpeg可执行文件不存在: $ffmpegPath');
    }

    // 确保保存目录存在
    final targetDir = Directory(saveDir);
    if (!targetDir.existsSync()) {
      try {
        await targetDir.create(recursive: true);
        print('创建保存目录: ${targetDir.path}');
      } catch (e) {
        throw Exception('无法创建保存目录: $e');
      }
    }

    // 构建下载命令参数
    final arguments = [
      url,
      '--save-dir',
      saveDir,
      '--save-name',
      saveName,
      '--tmp-dir',
      saveDir, // 使用相同目录作为临时目录
    ];

    try {
      print('开始下载: $url');
      print('保存目录: $saveDir');
      print('文件名: $saveName');
      print('可执行文件路径: $execPath');

      // 获取配置参数
      final muxerParameter = await N_m3u8dlConfigService.getMuxerParameter();
      final videoSelectParameter =
          await N_m3u8dlConfigService.getVideoSelectParameter();
      final skipSub = await N_m3u8dlConfigService.getSkipSub();

      // 如果没有指定音频语言，从配置中获取
      final effectiveAudioLang = audioLang.isEmpty
          ? await N_m3u8dlConfigService.getAudioLang()
          : audioLang;

      // 构建音频选择参数
      var audioSelectParameter = 'lang=$effectiveAudioLang:for=best';
      if (effectiveAudioLang == 'all') {
        audioSelectParameter = 'all';
      }

      // 构建完整的命令参数
      final fullArgs = [
        url, // 移除引号
        '--use-system-proxy', 'False',
        '--save-dir', saveDir,
        '--save-name', saveName,
        '--tmp-dir', saveDir,
        '-mt', 'True',
        '-M', muxerParameter,
        '--ffmpeg-binary-path', ffmpegPath, // 添加ffmpeg可执行文件路径
        '-sv', videoSelectParameter,
        '-sa', audioSelectParameter,
      ];

      // 只有当不跳过字幕时才添加字幕选择参数
      if (!skipSub) {
        fullArgs.add('-ss');
        fullArgs.add('all');
      }

      final proxyConfig = await ProxyService.getProxyConfig();
      final proxyEnabled = proxyConfig['enabled'] as bool;
      final proxyUrl = proxyConfig['url'] as String;

      if (proxyEnabled && proxyUrl.isNotEmpty) {
        fullArgs.add('--custom-proxy');
        fullArgs.add(proxyUrl);
      }

      // 添加额外参数
      if (extraArgs != null && extraArgs.isNotEmpty) {
        fullArgs.addAll(extraArgs);
        final argsTimestamp = DateTime.now().toString().substring(11, 19);
        final argsMessage =
            '🔧 [$argsTimestamp] 使用额外参数: ${extraArgs.join(' ')}';
        print(argsMessage);
        onLog?.call(argsMessage);
      }

      final commandTimestamp = DateTime.now().toString().substring(11, 19);
      final commandMessage =
          '🚀 [$commandTimestamp] 执行命令: N_m3u8DL-RE ${fullArgs.join(' ')}';
      final ffmpegMessage = '🔧 [$commandTimestamp] 使用ffmpeg路径: $ffmpegPath';
      print(commandMessage);
      print(ffmpegMessage);
      onLog?.call(commandMessage);
      onLog?.call(ffmpegMessage);

      // 使用Process.start来避免沙盒限制
      final process = await Process.start(
        execPath, // 这里使用的是完整路径，如 /path/to/N_m3u8DL-RE
        fullArgs,
        mode: ProcessStartMode.normal,
      );

      // 如果提供了taskId，存储进程引用以便后续取消
      if (taskId != null) {
        _runningProcesses[taskId] = process;
      }

      // 自动处理交互式选择
      if (process.stdin != null) {
        // 自动发送选择（比如选择第一个选项）
        process.stdin.writeln('1'); // 或者其他默认选择
        await process.stdin.close();
      }

      // 监听输出并实时回调
      final stdout = <String>[];
      final stderr = <String>[];

      // 创建Completer来等待输出流完成
      final stdoutCompleter = Completer<void>();
      final stderrCompleter = Completer<void>();

      // 监听stdout - 使用宽松的UTF-8解码，允许错误字符
      process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(
        (line) {
          stdout.add(line);
          final timestamp = DateTime.now().toString().substring(11, 19);
          final logMessage = '🚀 [$timestamp] $line';
          print(logMessage);
          onLog?.call(logMessage);

          // 解析进度信息
          final progress = _parseProgress(line);
          if (progress != null) {
            onProgress?.call(progress);
          }
        },
        onDone: () {
          if (!stdoutCompleter.isCompleted) {
            stdoutCompleter.complete();
          }
        },
        onError: (error) {
          print('stdout解码错误: $error');
          if (!stdoutCompleter.isCompleted) {
            stdoutCompleter.completeError(error);
          }
        },
      );

      // 监听stderr - 使用宽松的UTF-8解码，允许错误字符
      process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(
        (line) {
          stderr.add(line);
          final timestamp = DateTime.now().toString().substring(11, 19);
          final logMessage = '❌ [$timestamp] ERROR: $line';
          print(logMessage);
          onLog?.call(logMessage);
        },
        onDone: () {
          if (!stderrCompleter.isCompleted) {
            stderrCompleter.complete();
          }
        },
        onError: (error) {
          print('stderr解码错误: $error');
          if (!stderrCompleter.isCompleted) {
            stderrCompleter.completeError(error);
          }
        },
      );

      // 等待进程退出和所有输出流完成
      final exitCode = await process.exitCode;

      // 使用超时等待输出流完成，避免无限等待
      try {
        await Future.wait([
          stdoutCompleter.future,
          stderrCompleter.future
        ]).timeout(const Duration(seconds: 10));
      } catch (timeoutError) {
        print('等待输出流完成超时: $timeoutError');
        // 强制完成未完成的Completer
        if (!stdoutCompleter.isCompleted) {
          stdoutCompleter.complete();
        }
        if (!stderrCompleter.isCompleted) {
          stderrCompleter.complete();
        }
      }

      // 清理进程引用
      if (taskId != null) {
        _runningProcesses.remove(taskId);
      }

      final timestamp = DateTime.now().toString().substring(11, 19);
      final finalMessage = '📊 [$timestamp] 下载命令退出码: $exitCode';
      print(finalMessage);
      onLog?.call(finalMessage);

      if (exitCode == 0) {
        final successMessage = '🎉 [$timestamp] 下载成功完成！';
        onLog?.call(successMessage);
        return exitCode;
      } else {
        // 收集所有错误信息
        final allErrors = stderr.isNotEmpty ? stderr.join('\n') : 'ERROR';
        final errorMessage =
            '❌ [$timestamp] ERROR ( $exitCode):\n$allErrors';
        onLog?.call(errorMessage);
        throw Exception(errorMessage);
      }
    } catch (e) {
      // 清理进程引用（异常情况下）
      if (taskId != null) {
        _runningProcesses.remove(taskId);
      }

      final timestamp = DateTime.now().toString().substring(11, 19);

      // 区分不同类型的异常
      String errorMessage;
      if (e is FormatException && e.message.contains('Missing extension byte')) {
        errorMessage = '❌ [$timestamp] 字符编码错误已修复，请重试下载';
        print('UTF-8解码错误已通过allowMalformed修复: $e');
      } else {
        errorMessage = '❌ [$timestamp] 下载过程中发生异常: $e';
        print(errorMessage);
      }

      onLog?.call(errorMessage);
      rethrow;
    }
  }

  static DownloadProgress? _parseProgress(String line) {
    // 调试：打印正在解析的行
    if (line.contains('Vid ') ||
        line.contains('Aud ') ||
        line.contains('Sub ')) {
      print('解析进度行: $line');
    }

    // 根据平台选择不同的解析策略
    if (Platform.isWindows) {
      return _parseProgressWindows(line);
    } else {
      return _parseProgressMacLinux(line);
    }
  }

  /// Windows平台的进度解析
  static DownloadProgress? _parseProgressWindows(String line) {
    // 检查是否是合并状态
    if (line.contains('Muxing to') || line.contains('正在合并')) {
      final fileName =
          RegExp(r'Muxing to (.+)').firstMatch(line)?.group(1) ??
          RegExp(r'正在合并.*?([^\\/]+\.\w+)').firstMatch(line)?.group(1) ?? '';
      return DownloadProgress.muxing('正在合并到: $fileName');
    }

    // 检查是否是清理状态
    if (line.contains('Cleaning files') || line.contains('清理文件')) {
      return DownloadProgress.cleaning();
    }

    // 检查是否是重命名状态
    if (line.contains('Rename to') || line.contains('重命名')) {
      final fileName =
          RegExp(r'Rename to (.+)').firstMatch(line)?.group(1) ??
          RegExp(r'重命名.*?([^\\/]+\.\w+)').firstMatch(line)?.group(1) ?? '';
      return DownloadProgress.muxing('重命名为: $fileName');
    }

    // 检查是否是完成状态
    if (line.contains('Done') || line.contains('完成') || line.contains('任务结束')) {
      return DownloadProgress.done('下载完成');
    }

    // Windows平台可能使用不同的进度条字符，尝试多种模式
    // 解析视频进度 - 支持多种进度条字符
    final videoPatterns = [
      // 标准Unicode进度条
      r'Vid\s+([^|]+)\s*\|.*?[━═▬■]+\s*(\d+)/(\d+)\s+(\d+\.\d+)%(?:\s+([\d.]+\w+)(?:/[\d.]+\w+)?\s*(?:[\d.]+\w+)?\s*(?:-?\s*(\d{2}:\d{2}:\d{2}))?)?',
      // ASCII进度条
      r'Vid\s+([^|]+)\s*\|.*?[=\-#*]+\s*(\d+)/(\d+)\s+(\d+\.\d+)%(?:\s+([\d.]+\w+)(?:/[\d.]+\w+)?\s*(?:[\d.]+\w+)?\s*(?:-?\s*(\d{2}:\d{2}:\d{2}))?)?',
      // 简化模式，不依赖进度条字符
      r'Vid\s+([^|]+)\s*\|.*?\s+(\d+)/(\d+)\s+(\d+\.\d+)%(?:\s+([\d.]+\w+)(?:/[\d.]+\w+)?\s*(?:[\d.]+\w+)?\s*(?:-?\s*(\d{2}:\d{2}:\d{2}))?)?',
    ];

    for (final pattern in videoPatterns) {
      final videoMatch = RegExp(pattern).firstMatch(line);
      if (videoMatch != null) {
        return DownloadProgress(
          type: 'video',
          quality: videoMatch.group(1)?.trim() ?? '',
          currentSegment: int.parse(videoMatch.group(2) ?? '0'),
          totalSegments: int.parse(videoMatch.group(3) ?? '0'),
          percentage: double.parse(videoMatch.group(4) ?? '0'),
          downloadedSize: videoMatch.group(5) ?? '-',
          totalSize: '',
          speed: '',
          eta: videoMatch.group(6) ?? '--:--:--',
        );
      }
    }

    // 解析音频进度 - 支持多种进度条字符
    final audioPatterns = [
      // 标准Unicode进度条
      r'Aud\s+([^━═▬■]+)\s*[━═▬■]+\s*(\d+)/(\d+)\s+(\d+\.\d+)%(?:\s+([\d.]+\w+)\s*(?:-\s*(\d{2}:\d{2}:\d{2}))?)?',
      // ASCII进度条
      r'Aud\s+([^=\-#*]+)\s*[=\-#*]+\s*(\d+)/(\d+)\s+(\d+\.\d+)%(?:\s+([\d.]+\w+)\s*(?:-\s*(\d{2}:\d{2}:\d{2}))?)?',
      // 简化模式
      r'Aud\s+([^|]+)\s*\|.*?\s+(\d+)/(\d+)\s+(\d+\.\d+)%(?:\s+([\d.]+\w+)\s*(?:-\s*(\d{2}:\d{2}:\d{2}))?)?',
    ];

    for (final pattern in audioPatterns) {
      final audioMatch = RegExp(pattern).firstMatch(line);
      if (audioMatch != null) {
        return DownloadProgress(
          type: 'audio',
          quality: audioMatch.group(1)?.trim() ?? '',
          currentSegment: int.parse(audioMatch.group(2) ?? '0'),
          totalSegments: int.parse(audioMatch.group(3) ?? '0'),
          percentage: double.parse(audioMatch.group(4) ?? '0'),
          downloadedSize: audioMatch.group(5) ?? '-',
          totalSize: '',
          speed: '',
          eta: audioMatch.group(6) ?? '--:--:--',
        );
      }
    }

    // 解析字幕进度 - 支持多种进度条字符
    final subtitlePatterns = [
      // 标准Unicode进度条
      r'Sub\s+([^━═▬■]+)\s*[━═▬■]+\s*(\d+)/(\d+)\s+(\d+\.\d+)%(?:\s+([\d.]+\w+)\s*(?:-\s*(\d{2}:\d{2}:\d{2}))?)?',
      // ASCII进度条
      r'Sub\s+([^=\-#*]+)\s*[=\-#*]+\s*(\d+)/(\d+)\s+(\d+\.\d+)%(?:\s+([\d.]+\w+)\s*(?:-\s*(\d{2}:\d{2}:\d{2}))?)?',
      // 简化模式
      r'Sub\s+([^|]+)\s*\|.*?\s+(\d+)/(\d+)\s+(\d+\.\d+)%(?:\s+([\d.]+\w+)\s*(?:-\s*(\d{2}:\d{2}:\d{2}))?)?',
    ];

    for (final pattern in subtitlePatterns) {
      final subtitleMatch = RegExp(pattern).firstMatch(line);
      if (subtitleMatch != null) {
        return DownloadProgress(
          type: 'subtitle',
          quality: subtitleMatch.group(1)?.trim() ?? '',
          currentSegment: int.parse(subtitleMatch.group(2) ?? '0'),
          totalSegments: int.parse(subtitleMatch.group(3) ?? '0'),
          percentage: double.parse(subtitleMatch.group(4) ?? '0'),
          downloadedSize: subtitleMatch.group(5) ?? '-',
          totalSize: '',
          speed: '',
          eta: subtitleMatch.group(6) ?? '--:--:--',
        );
      }
    }

    return null;
  }

  /// Mac/Linux平台的进度解析（保持原有逻辑不变）
  static DownloadProgress? _parseProgressMacLinux(String line) {
    // 检查是否是合并状态
    if (line.contains('Muxing to')) {
      final fileName =
          RegExp(r'Muxing to (.+)').firstMatch(line)?.group(1) ?? '';
      return DownloadProgress.muxing('正在合并到: $fileName');
    }

    // 检查是否是清理状态
    if (line.contains('Cleaning files')) {
      return DownloadProgress.cleaning();
    }

    // 检查是否是重命名状态
    if (line.contains('Rename to')) {
      final fileName =
          RegExp(r'Rename to (.+)').firstMatch(line)?.group(1) ?? '';
      return DownloadProgress.muxing('重命名为: $fileName');
    }

    // 检查是否是完成状态
    if (line.contains('Done')) {
      return DownloadProgress.done('下载完成');
    }

    // 解析视频进度:
    // 有文件大小: Vid 1280x720 | 4060 Kbps | 50 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 57/708 8.05% 155.19MB/1.88GB 15.98MBps 00:03:36
    // 等待下载: Vid 1280x720 | 4060 Kbps | 50 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 0/708 0.00%
    final videoRegex = RegExp(
        r'Vid\s+([^|]+)\s*\|.*?━+\s*(\d+)/(\d+)\s+(\d+\.\d+)%(?:\s+([\d.]+\w+)(?:/[\d.]+\w+)?\s*(?:[\d.]+\w+)?\s*(?:-?\s*(\d{2}:\d{2}:\d{2}))?)?');
    final videoMatch = videoRegex.firstMatch(line);

    if (videoMatch != null) {
      return DownloadProgress(
        type: 'video',
        quality: videoMatch.group(1)?.trim() ?? '',
        currentSegment: int.parse(videoMatch.group(2) ?? '0'),
        totalSegments: int.parse(videoMatch.group(3) ?? '0'),
        percentage: double.parse(videoMatch.group(4) ?? '0'),
        downloadedSize: videoMatch.group(5) ?? '-',
        totalSize: '',
        speed: '',
        eta: videoMatch.group(6) ?? '--:--:--',
      );
    }

    // 解析音频进度:
    // 有文件大小: Aud English | eng | 2CH        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 717/717 100.00% 98.47MB - 00:00:00
    // 等待下载: Aud Team Radio | obc | 2CH    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  0/100 0.00%
    final audioRegex = RegExp(
        r'Aud\s+([^━]+)\s*━+\s*(\d+)/(\d+)\s+(\d+\.\d+)%(?:\s+([\d.]+\w+)\s*(?:-\s*(\d{2}:\d{2}:\d{2}))?)?');
    final audioMatch = audioRegex.firstMatch(line);

    if (audioMatch != null) {
      return DownloadProgress(
        type: 'audio',
        quality: audioMatch.group(1)?.trim() ?? '',
        currentSegment: int.parse(audioMatch.group(2) ?? '0'),
        totalSegments: int.parse(audioMatch.group(3) ?? '0'),
        percentage: double.parse(audioMatch.group(4) ?? '0'),
        downloadedSize: audioMatch.group(5) ?? '-',
        totalSize: '',
        speed: '',
        eta: audioMatch.group(6) ?? '--:--:--',
      );
    }

    // 解析字幕进度:
    // 有文件大小: Sub eng | English              ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 759/759 100.00% 187.38KB - 00:00:00
    // 等待下载: Sub eng | English              ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  0/759 0.00%
    final subtitleRegex = RegExp(
        r'Sub\s+([^━]+)\s*━+\s*(\d+)/(\d+)\s+(\d+\.\d+)%(?:\s+([\d.]+\w+)\s*(?:-\s*(\d{2}:\d{2}:\d{2}))?)?');
    final subtitleMatch = subtitleRegex.firstMatch(line);

    if (subtitleMatch != null) {
      return DownloadProgress(
        type: 'subtitle',
        quality: subtitleMatch.group(1)?.trim() ?? '',
        currentSegment: int.parse(subtitleMatch.group(2) ?? '0'),
        totalSegments: int.parse(subtitleMatch.group(3) ?? '0'),
        percentage: double.parse(subtitleMatch.group(4) ?? '0'),
        downloadedSize: subtitleMatch.group(5) ?? '-',
        totalSize: '',
        speed: '',
        eta: subtitleMatch.group(6) ?? '--:--:--',
      );
    }

    return null;
  }

  /// 取消指定任务的下载进程
  static bool cancelDownload(String taskId) {
    final process = _runningProcesses[taskId];
    if (process != null) {
      try {
        // 尝试优雅地终止进程
        process.kill();
        _runningProcesses.remove(taskId);
        print('已取消下载任务: $taskId');
        return true;
      } catch (e) {
        print('取消下载任务失败: $e');
        return false;
      }
    }
    return false;
  }

  /// 获取正在运行的下载任务数量
  static int getRunningTasksCount() {
    return _runningProcesses.length;
  }

  /// 获取所有正在运行的任务ID
  static List<String> getRunningTaskIds() {
    return _runningProcesses.keys.toList();
  }

  /// 取消所有正在运行的下载任务
  static void cancelAllDownloads() {
    final taskIds = _runningProcesses.keys.toList();
    for (final taskId in taskIds) {
      cancelDownload(taskId);
    }
  }
}
