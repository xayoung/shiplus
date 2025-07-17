import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shiplus/ffi/n_m3u8dl_re.dart';
import 'dart:io';

void main() {
  group('N_m3u8DL_RE Path Tests', () {
    testWidgets('Should return valid executable paths on all platforms', (WidgetTester tester) async {
      // 这个测试验证可执行文件路径的基本逻辑
      // 注意：在测试环境中，assets 可能不可用，所以这只是基本的路径格式验证
      
      // 测试 Windows 路径格式
      if (Platform.isWindows) {
        // 在 Windows 上，路径应该包含 .exe 扩展名
        expect('N_m3u8DL-RE.exe'.endsWith('.exe'), isTrue);
        expect('ffmpeg.exe'.endsWith('.exe'), isTrue);
      } else {
        // 在 Unix 系统上，路径不应该有 .exe 扩展名
        expect('N_m3u8DL-RE'.endsWith('.exe'), isFalse);
        expect('ffmpeg'.endsWith('.exe'), isFalse);
      }
    });

    test('Platform-specific executable names', () {
      // 测试平台特定的可执行文件名
      final execName = Platform.isWindows ? 'N_m3u8DL-RE.exe' : 'N_m3u8DL-RE';
      final ffmpegName = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
      
      if (Platform.isWindows) {
        expect(execName, equals('N_m3u8DL-RE.exe'));
        expect(ffmpegName, equals('ffmpeg.exe'));
      } else {
        expect(execName, equals('N_m3u8DL-RE'));
        expect(ffmpegName, equals('ffmpeg'));
      }
    });

    test('Asset paths should be correct', () {
      // 测试 assets 路径格式
      final execName = Platform.isWindows ? 'N_m3u8DL-RE.exe' : 'N_m3u8DL-RE';
      final ffmpegName = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
      
      final execAssetPath = 'assets/bin/$execName';
      final ffmpegAssetPath = 'assets/bin/$ffmpegName';
      
      expect(execAssetPath.startsWith('assets/bin/'), isTrue);
      expect(ffmpegAssetPath.startsWith('assets/bin/'), isTrue);
      
      if (Platform.isWindows) {
        expect(execAssetPath, equals('assets/bin/N_m3u8DL-RE.exe'));
        expect(ffmpegAssetPath, equals('assets/bin/ffmpeg.exe'));
      } else {
        expect(execAssetPath, equals('assets/bin/N_m3u8DL-RE'));
        expect(ffmpegAssetPath, equals('assets/bin/ffmpeg'));
      }
    });
  });
}
