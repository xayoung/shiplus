import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../services/n_m3u8dl_config_service.dart';
import '../models/download_progress.dart';
import '../services/proxy_service.dart';

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

  static AudioLanguage fromCode(String code) {
    return AudioLanguage.values.firstWhere(
      (lang) => lang.code == code,
      orElse: () => AudioLanguage.english,
    );
  }

  static List<String> get allCodes =>
      AudioLanguage.values.map((e) => e.code).toList();
}

class N_m3u8DL_RE {
  static final Map<String, Process> _runningProcesses = {};

  static Future<String> get _execPath async {
    final appSupportDir = await getApplicationSupportDirectory();
    if (!appSupportDir.existsSync()) {
      appSupportDir.createSync(recursive: true);
    }

    final execName = Platform.isWindows ? 'N_m3u8DL-RE.exe' : 'N_m3u8DL-RE';
    final execInAppSupport = File('${appSupportDir.path}/$execName');
    if (!execInAppSupport.existsSync()) {
      try {
        final assetPath = 'assets/bin/$execName';

        print('Loading executable from assets: $assetPath');
        print('Target path: ${execInAppSupport.path}');

        final ByteData data = await rootBundle.load(assetPath);
        final Uint8List bytes = data.buffer.asUint8List();

        await execInAppSupport.writeAsBytes(bytes);

        if (Platform.isMacOS || Platform.isLinux) {
          final result = await Process.run('chmod', [
            '755',
            execInAppSupport.path,
          ]);
          if (result.exitCode != 0) {
            print('Failed to set executable permissions: ${result.stderr}');
            final result2 = await Process.run('chmod', [
              'u+x',
              execInAppSupport.path,
            ]);
            if (result2.exitCode != 0) {
              print(
                'Fallback permission update also failed: ${result2.stderr}',
              );
            }
          } else {
            print('Executable permissions set successfully (755)');
          }

          final lsResult = await Process.run('ls', [
            '-la',
            execInAppSupport.path,
          ]);
          print('File permission details: ${lsResult.stdout}');
        }

        print('Executable extracted from assets to: ${execInAppSupport.path}');
      } catch (e) {
        print('Failed to extract executable from assets: $e');
        throw Exception(
          'Failed to extract the N_m3u8DL-RE executable from app assets: $e',
        );
      }
    }

    return execInAppSupport.path;
  }

  static Future<String> get _ffmpegPath async {
    final appSupportDir = await getApplicationSupportDirectory();
    if (!appSupportDir.existsSync()) {
      appSupportDir.createSync(recursive: true);
    }

    final ffmpegName = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
    final ffmpegInAppSupport = File('${appSupportDir.path}/$ffmpegName');
    if (!ffmpegInAppSupport.existsSync()) {
      try {
        final assetPath = 'assets/bin/$ffmpegName';

        print('Loading the ffmpeg executable from assets: $assetPath');
        print('Target path: ${ffmpegInAppSupport.path}');

        final ByteData data = await rootBundle.load(assetPath);
        final Uint8List bytes = data.buffer.asUint8List();

        await ffmpegInAppSupport.writeAsBytes(bytes);

        if (Platform.isMacOS || Platform.isLinux) {
          final result = await Process.run('chmod', [
            '755',
            ffmpegInAppSupport.path,
          ]);
          if (result.exitCode != 0) {
            print(
              'Failed to set ffmpeg executable permissions: ${result.stderr}',
            );
          } else {
            print('ffmpeg executable permissions set successfully (755)');
          }
        }

        print('ffmpeg executable extracted to: ${ffmpegInAppSupport.path}');
      } catch (e) {
        print('Failed to extract the ffmpeg executable from assets: $e');
        throw Exception(
          'Failed to extract the ffmpeg executable from app assets: $e',
        );
      }
    }

    return ffmpegInAppSupport.path;
  }

  ///
  ///
  ///
  static Future<int> downloadVideo(
    String url,
    String saveDir,
    String saveName, {
    String? taskId,
    String audioLang = 'eng',
    List<String>? extraArgs,
    Function(String)? onLog,
    Function(DownloadProgress)? onProgress,
  }) async {
    print('Starting video download: $url');
    print('Save directory: $saveDir');
    print('File name: $saveName');

    final execPath = await _execPath;
    print('Using executable: $execPath');

    final ffmpegPath = await _ffmpegPath;
    print('Using ffmpeg executable: $ffmpegPath');

    final execFile = File(execPath);
    if (!execFile.existsSync()) {
      throw Exception('N_m3u8DL-RE executable does not exist: $execPath');
    }

    final ffmpegFile = File(ffmpegPath);
    if (!ffmpegFile.existsSync()) {
      throw Exception('ffmpeg executable does not exist: $ffmpegPath');
    }

    final targetDir = Directory(saveDir);
    if (!targetDir.existsSync()) {
      try {
        await targetDir.create(recursive: true);
        print('Created save directory: ${targetDir.path}');
      } catch (e) {
        throw Exception('Failed to create the save directory: $e');
      }
    }

    final arguments = [
      url,
      '--save-dir',
      saveDir,
      '--save-name',
      saveName,
      '--tmp-dir',
      saveDir,
    ];

    try {
      print('Starting download: $url');
      print('Save directory: $saveDir');
      print('File name: $saveName');
      print('Executable path: $execPath');

      final muxerParameter = await N_m3u8dlConfigService.getMuxerParameter();
      final videoSelectParameter =
          await N_m3u8dlConfigService.getVideoSelectParameter();
      final skipSub = await N_m3u8dlConfigService.getSkipSub();

      final effectiveAudioLang = audioLang.isEmpty
          ? await N_m3u8dlConfigService.getAudioLang()
          : audioLang;

      var audioSelectParameter = 'lang=$effectiveAudioLang:for=best';
      if (effectiveAudioLang == 'all') {
        audioSelectParameter = 'all';
      }

      final fullArgs = [
        url,
        '--use-system-proxy',
        'False',
        '--save-dir',
        saveDir,
        '--save-name',
        saveName,
        '--tmp-dir',
        saveDir,
        '-mt',
        'True',
        '-M',
        muxerParameter,
        '--ffmpeg-binary-path',
        ffmpegPath,
        '-sv',
        videoSelectParameter,
        '-sa',
        audioSelectParameter,
      ];

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

      if (extraArgs != null && extraArgs.isNotEmpty) {
        fullArgs.addAll(extraArgs);
        final argsTimestamp = DateTime.now().toString().substring(11, 19);
        final argsMessage =
            '🔧 [$argsTimestamp] Using extra arguments: ${extraArgs.join(' ')}';
        print(argsMessage);
        onLog?.call(argsMessage);
      }

      final commandTimestamp = DateTime.now().toString().substring(11, 19);
      final commandMessage =
          '🚀 [$commandTimestamp] Running command: N_m3u8DL-RE ${fullArgs.join(' ')}';
      final ffmpegMessage =
          '🔧 [$commandTimestamp] Using ffmpeg path: $ffmpegPath';
      print(commandMessage);
      print(ffmpegMessage);
      onLog?.call(commandMessage);
      onLog?.call(ffmpegMessage);

      final process = await Process.start(
        execPath,
        fullArgs,
        mode: ProcessStartMode.normal,
      );

      if (taskId != null) {
        _runningProcesses[taskId] = process;
      }

      if (process.stdin != null) {
        process.stdin.writeln('1');
        await process.stdin.close();
      }

      final stdout = <String>[];
      final stderr = <String>[];

      final stdoutCompleter = Completer<void>();
      final stderrCompleter = Completer<void>();

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
              print('stdout decoding error: $error');
              if (!stdoutCompleter.isCompleted) {
                stdoutCompleter.completeError(error);
              }
            },
          );

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
              print('stderr decoding error: $error');
              if (!stderrCompleter.isCompleted) {
                stderrCompleter.completeError(error);
              }
            },
          );

      final exitCode = await process.exitCode;

      try {
        await Future.wait([
          stdoutCompleter.future,
          stderrCompleter.future,
        ]).timeout(const Duration(seconds: 10));
      } catch (timeoutError) {
        print('Timed out while waiting for output streams: $timeoutError');
        if (!stdoutCompleter.isCompleted) {
          stdoutCompleter.complete();
        }
        if (!stderrCompleter.isCompleted) {
          stderrCompleter.complete();
        }
      }

      if (taskId != null) {
        _runningProcesses.remove(taskId);
      }

      final timestamp = DateTime.now().toString().substring(11, 19);
      final finalMessage =
          '📊 [$timestamp] Download command exit code: $exitCode';
      print(finalMessage);
      onLog?.call(finalMessage);

      if (exitCode == 0) {
        final successMessage =
            '🎉 [$timestamp] Download completed successfully!';
        onLog?.call(successMessage);
        return exitCode;
      } else {
        final allErrors = stderr.isNotEmpty ? stderr.join('\n') : 'ERROR';
        final errorMessage = '❌ [$timestamp] ERROR ( $exitCode):\n$allErrors';
        onLog?.call(errorMessage);
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (taskId != null) {
        _runningProcesses.remove(taskId);
      }

      final timestamp = DateTime.now().toString().substring(11, 19);

      String errorMessage;
      if (e is FormatException &&
          e.message.contains('Missing extension byte')) {
        errorMessage =
            '❌ [$timestamp] The character encoding error was handled. Retry the download.';
        print('UTF-8 decoding error handled with allowMalformed: $e');
      } else {
        errorMessage = '❌ [$timestamp] Download failed with an exception: $e';
        print(errorMessage);
      }

      onLog?.call(errorMessage);
      rethrow;
    }
  }

  static DownloadProgress? _parseProgress(String line) {
    if (line.contains('Vid ') ||
        line.contains('Aud ') ||
        line.contains('Sub ')) {
      print('Parsing progress line: $line');
    }

    if (Platform.isWindows) {
      return _parseProgressWindows(line);
    } else {
      return _parseProgressMacLinux(line);
    }
  }

  static DownloadProgress? _parseProgressWindows(String line) {
    if (line.contains('Muxing to') ||
        line.contains('\u6b63\u5728\u5408\u5e76')) {
      final fileName =
          RegExp(r'Muxing to (.+)').firstMatch(line)?.group(1) ??
          RegExp(
            '\u6b63\u5728\u5408\u5e76.*?([^\\\\/]+\\.\\w+)',
          ).firstMatch(line)?.group(1) ??
          '';
      return DownloadProgress.muxing('Muxing to: $fileName');
    }

    if (line.contains('Cleaning files') ||
        line.contains('\u6e05\u7406\u6587\u4ef6')) {
      return DownloadProgress.cleaning();
    }

    if (line.contains('Rename to') || line.contains('\u91cd\u547d\u540d')) {
      final fileName =
          RegExp(r'Rename to (.+)').firstMatch(line)?.group(1) ??
          RegExp(
            '\u91cd\u547d\u540d.*?([^\\\\/]+\\.\\w+)',
          ).firstMatch(line)?.group(1) ??
          '';
      return DownloadProgress.muxing('Renaming to: $fileName');
    }

    if (line.contains('Done') ||
        line.contains('\u5b8c\u6210') ||
        line.contains('\u4efb\u52a1\u7ed3\u675f')) {
      return DownloadProgress.done('Download complete');
    }

    final videoPatterns = [
      r'Vid\s+([^|]+)\s*\|.*?[━═▬■]+\s*(\d+)/(\d+)\s+(\d+\.\d+)%(?:\s+([\d.]+\w+)(?:/[\d.]+\w+)?\s*(?:[\d.]+\w+)?\s*(?:-?\s*(\d{2}:\d{2}:\d{2}))?)?',
      r'Vid\s+([^|]+)\s*\|.*?[=\-#*]+\s*(\d+)/(\d+)\s+(\d+\.\d+)%(?:\s+([\d.]+\w+)(?:/[\d.]+\w+)?\s*(?:[\d.]+\w+)?\s*(?:-?\s*(\d{2}:\d{2}:\d{2}))?)?',
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

    final audioPatterns = [
      r'Aud\s+([^━═▬■]+)\s*[━═▬■]+\s*(\d+)/(\d+)\s+(\d+\.\d+)%(?:\s+([\d.]+\w+)\s*(?:-\s*(\d{2}:\d{2}:\d{2}))?)?',
      r'Aud\s+([^=\-#*]+)\s*[=\-#*]+\s*(\d+)/(\d+)\s+(\d+\.\d+)%(?:\s+([\d.]+\w+)\s*(?:-\s*(\d{2}:\d{2}:\d{2}))?)?',
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

    final subtitlePatterns = [
      r'Sub\s+([^━═▬■]+)\s*[━═▬■]+\s*(\d+)/(\d+)\s+(\d+\.\d+)%(?:\s+([\d.]+\w+)\s*(?:-\s*(\d{2}:\d{2}:\d{2}))?)?',
      r'Sub\s+([^=\-#*]+)\s*[=\-#*]+\s*(\d+)/(\d+)\s+(\d+\.\d+)%(?:\s+([\d.]+\w+)\s*(?:-\s*(\d{2}:\d{2}:\d{2}))?)?',
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

  static DownloadProgress? _parseProgressMacLinux(String line) {
    if (line.contains('Muxing to')) {
      final fileName =
          RegExp(r'Muxing to (.+)').firstMatch(line)?.group(1) ?? '';
      return DownloadProgress.muxing('Muxing to: $fileName');
    }

    if (line.contains('Cleaning files')) {
      return DownloadProgress.cleaning();
    }

    if (line.contains('Rename to')) {
      final fileName =
          RegExp(r'Rename to (.+)').firstMatch(line)?.group(1) ?? '';
      return DownloadProgress.muxing('Renaming to: $fileName');
    }

    if (line.contains('Done')) {
      return DownloadProgress.done('Download complete');
    }

    final videoRegex = RegExp(
      r'Vid\s+([^|]+)\s*\|.*?━+\s*(\d+)/(\d+)\s+(\d+\.\d+)%(?:\s+([\d.]+\w+)(?:/[\d.]+\w+)?\s*(?:[\d.]+\w+)?\s*(?:-?\s*(\d{2}:\d{2}:\d{2}))?)?',
    );
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

    final audioRegex = RegExp(
      r'Aud\s+([^━]+)\s*━+\s*(\d+)/(\d+)\s+(\d+\.\d+)%(?:\s+([\d.]+\w+)\s*(?:-\s*(\d{2}:\d{2}:\d{2}))?)?',
    );
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

    final subtitleRegex = RegExp(
      r'Sub\s+([^━]+)\s*━+\s*(\d+)/(\d+)\s+(\d+\.\d+)%(?:\s+([\d.]+\w+)\s*(?:-\s*(\d{2}:\d{2}:\d{2}))?)?',
    );
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

  static bool cancelDownload(String taskId) {
    final process = _runningProcesses[taskId];
    if (process != null) {
      try {
        process.kill();
        _runningProcesses.remove(taskId);
        print('Cancelled download task: $taskId');
        return true;
      } catch (e) {
        print('Failed to cancel download task: $e');
        return false;
      }
    }
    return false;
  }

  static int getRunningTasksCount() {
    return _runningProcesses.length;
  }

  static List<String> getRunningTaskIds() {
    return _runningProcesses.keys.toList();
  }

  static void cancelAllDownloads() {
    final taskIds = _runningProcesses.keys.toList();
    for (final taskId in taskIds) {
      cancelDownload(taskId);
    }
  }
}
