import 'package:flutter_test/flutter_test.dart';
import 'package:shiplus/services/n_m3u8dl_config_service.dart';

void main() {
  group('N_m3u8dlConfigService Tests', () {
    setUpAll(() async {
      // 初始化 Flutter binding
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() async {
      // 清理内存缓存
      N_m3u8dlConfigService.clearCache();
    });

    test('should return default values when no config is set', () async {
      final format = await N_m3u8dlConfigService.getFormat();
      final skipSub = await N_m3u8dlConfigService.getSkipSub();
      final resolution = await N_m3u8dlConfigService.getResolution();
      final range = await N_m3u8dlConfigService.getRange();

      expect(format, equals('mp4'));
      expect(skipSub, equals(true));
      expect(resolution, equals('3840'));
      expect(range, equals('SDR'));
    });

    test('should save and retrieve format correctly', () async {
      await N_m3u8dlConfigService.setFormat('mkv');
      final format = await N_m3u8dlConfigService.getFormat();

      expect(format, equals('mkv'));
    });

    test('should save and retrieve skipSub correctly', () async {
      await N_m3u8dlConfigService.setSkipSub(false);
      final skipSub = await N_m3u8dlConfigService.getSkipSub();

      expect(skipSub, equals(false));
    });

    test('should save and retrieve resolution correctly', () async {
      await N_m3u8dlConfigService.setResolution('1920');
      final resolution = await N_m3u8dlConfigService.getResolution();

      expect(resolution, equals('1920'));
    });

    test('should save and retrieve range correctly', () async {
      await N_m3u8dlConfigService.setRange('HLG');
      final range = await N_m3u8dlConfigService.getRange();

      expect(range, equals('HLG'));
    });

    test('should generate correct muxer parameter with default values',
        () async {
      final parameter = await N_m3u8dlConfigService.getMuxerParameter();

      expect(parameter, equals('format=mp4:muxer=ffmpeg:skip_sub=true'));
    });

    test('should generate correct muxer parameter with custom values',
        () async {
      await N_m3u8dlConfigService.setFormat('mkv');
      await N_m3u8dlConfigService.setSkipSub(false);

      final parameter = await N_m3u8dlConfigService.getMuxerParameter();

      expect(parameter, equals('format=mkv:muxer=ffmpeg:skip_sub=false'));
    });

    test('should generate correct video select parameter with default values',
        () async {
      final parameter = await N_m3u8dlConfigService.getVideoSelectParameter();

      expect(parameter, equals('res="3840*":range=SDR:for=best'));
    });

    test('should generate correct video select parameter with custom values',
        () async {
      await N_m3u8dlConfigService.setResolution('1920');
      await N_m3u8dlConfigService.setRange('HLG');

      final parameter = await N_m3u8dlConfigService.getVideoSelectParameter();

      expect(parameter, equals('res="1920*":range=HLG:for=best'));
    });

    test('should reset to defaults correctly', () async {
      // 设置非默认值
      await N_m3u8dlConfigService.setFormat('mkv');
      await N_m3u8dlConfigService.setSkipSub(false);
      await N_m3u8dlConfigService.setResolution('1920');
      await N_m3u8dlConfigService.setRange('HLG');

      // 重置为默认值
      await N_m3u8dlConfigService.resetToDefaults();

      final format = await N_m3u8dlConfigService.getFormat();
      final skipSub = await N_m3u8dlConfigService.getSkipSub();
      final resolution = await N_m3u8dlConfigService.getResolution();
      final range = await N_m3u8dlConfigService.getRange();

      expect(format, equals('mp4'));
      expect(skipSub, equals(true));
      expect(resolution, equals('3840'));
      expect(range, equals('SDR'));
    });

    test('should validate format correctly', () {
      expect(N_m3u8dlConfigService.isValidFormat('mp4'), isTrue);
      expect(N_m3u8dlConfigService.isValidFormat('mkv'), isTrue);
      expect(N_m3u8dlConfigService.isValidFormat('MP4'), isTrue);
      expect(N_m3u8dlConfigService.isValidFormat('MKV'), isTrue);
      expect(N_m3u8dlConfigService.isValidFormat('avi'), isFalse);
      expect(N_m3u8dlConfigService.isValidFormat('mov'), isFalse);
    });

    test('should return supported formats list', () {
      final formats = N_m3u8dlConfigService.getSupportedFormats();

      expect(formats, contains('mp4'));
      expect(formats, contains('mkv'));
      expect(formats.length, equals(2));
    });

    test('should return supported resolutions list', () {
      final resolutions = N_m3u8dlConfigService.getSupportedResolutions();

      expect(resolutions, contains('480'));
      expect(resolutions, contains('1920'));
      expect(resolutions, contains('3840'));
      expect(resolutions.length, equals(8));
    });

    test('should return supported ranges list', () {
      final ranges = N_m3u8dlConfigService.getSupportedRanges();

      expect(ranges, contains('SDR'));
      expect(ranges, contains('HLG'));
      expect(ranges.length, equals(2));
    });

    test('should get all config correctly', () async {
      await N_m3u8dlConfigService.setFormat('mkv');
      await N_m3u8dlConfigService.setSkipSub(false);

      final config = await N_m3u8dlConfigService.getAllConfig();

      expect(config['format'], equals('mkv'));
      expect(config['skipSub'], equals(false));
    });
  });
}
