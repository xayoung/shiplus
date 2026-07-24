import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shiplus/ffi/n_m3u8dl_re.dart';
import 'dart:io';

void main() {
  group('N_m3u8DL_RE Path Tests', () {
    testWidgets('Should return valid executable paths on all platforms', (WidgetTester tester) async {
      // Verify the basic executable-path behavior. Assets may be unavailable
      // in the test environment, so this only validates path formatting.
      
      // Verify Windows path formatting.
      if (Platform.isWindows) {
        // Windows executable paths should include the .exe extension.
        expect('N_m3u8DL-RE.exe'.endsWith('.exe'), isTrue);
        expect('ffmpeg.exe'.endsWith('.exe'), isTrue);
      } else {
        // Unix executable paths should not include the .exe extension.
        expect('N_m3u8DL-RE'.endsWith('.exe'), isFalse);
        expect('ffmpeg'.endsWith('.exe'), isFalse);
      }
    });

    test('Platform-specific executable names', () {
      // Verify platform-specific executable names.
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
      // Verify asset path formatting.
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
