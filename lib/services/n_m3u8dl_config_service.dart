/// N_m3u8DL-RE 配置服务
/// 使用内存存储，避免 SharedPreferences 和文件系统的兼容性问题
class N_m3u8dlConfigService {
  // 默认值
  static const String defaultFormat = 'mp4';
  static const bool defaultSkipSub = true;
  static const String defaultResolution = 'best';
  static const String defaultRange = 'auto';
  static const String defaultAudioLang = 'eng';

  // 内存存储，简单可靠
  static String _format = defaultFormat;
  static bool _skipSub = defaultSkipSub;
  static String _resolution = defaultResolution;
  static String _range = defaultRange;
  static String _audioLang = defaultAudioLang;

  /// 清理内存缓存
  static void clearCache() {
    _format = defaultFormat;
    _skipSub = defaultSkipSub;
    _resolution = defaultResolution;
    _range = defaultRange;
    _audioLang = defaultAudioLang;
  }

  /// 获取输出格式
  static Future<String> getFormat() async {
    return _format;
  }

  /// 设置输出格式
  static Future<void> setFormat(String format) async {
    _format = format;
  }

  /// 获取跳过字幕设置
  static Future<bool> getSkipSub() async {
    return _skipSub;
  }

  /// 设置跳过字幕
  static Future<void> setSkipSub(bool skipSub) async {
    _skipSub = skipSub;
  }

  /// 获取视频分辨率
  static Future<String> getResolution() async {
    return _resolution;
  }

  /// 设置视频分辨率
  static Future<void> setResolution(String resolution) async {
    _resolution = resolution;
  }

  /// 获取动态范围
  static Future<String> getRange() async {
    return _range;
  }

  /// 设置动态范围
  static Future<void> setRange(String range) async {
    _range = range;
  }

  /// 获取音频语言
  static Future<String> getAudioLang() async {
    return _audioLang;
  }

  /// 设置音频语言
  static Future<void> setAudioLang(String audioLang) async {
    _audioLang = audioLang;
  }

  /// 获取完整的 -M 参数
  static Future<String> getMuxerParameter() async {
    final format = await getFormat();
    final skipSub = await getSkipSub();

    // 始终包含 skip_sub 参数，无论是 true 还是 false
    String parameter = 'format=$format:muxer=ffmpeg:skip_sub=$skipSub';

    return parameter;
  }

  /// 获取视频选择参数 (-sv)
  static Future<String> getVideoSelectParameter() async {
    final resolution = await getResolution();
    final range = await getRange();
    if (range == 'auto') {
      if (resolution == 'best') {
        return 'best';
      } else {
        return 'res="$resolution*":for=best';
      }
    } else {
      if (resolution == 'best') {
        return ':range=$range:for=best';
      } else {
        return 'res="$resolution*":range=$range:for=best';
      }
    }
  }

  /// 重置为默认配置
  static Future<void> resetToDefaults() async {
    await setFormat(defaultFormat);
    await setSkipSub(defaultSkipSub);
    await setResolution(defaultResolution);
    await setRange(defaultRange);
    await setAudioLang(defaultAudioLang);
  }

  /// 获取所有配置
  static Future<Map<String, dynamic>> getAllConfig() async {
    return {
      'format': await getFormat(),
      'skipSub': await getSkipSub(),
      'resolution': await getResolution(),
      'range': await getRange(),
      'audioLang': await getAudioLang(),
    };
  }

  /// 验证格式是否有效
  static bool isValidFormat(String format) {
    return ['mp4', 'mkv'].contains(format.toLowerCase());
  }

  /// 获取支持的格式列表
  static List<String> getSupportedFormats() {
    return ['mp4', 'mkv'];
  }

  /// 获取支持的分辨率列表
  static List<Map<String, String>> getSupportedResolutionsTitle() {
    return [
      {'name': 'Best', 'value': 'best'},
      {'name': '4K', 'value': '3840'},
      {'name': '2K', 'value': '2560'},
      {'name': '1080P', 'value': '1920'},
      {'name': '720P', 'value': '1280'},
      {'name': '540P', 'value': '960'},
      {'name': '480P', 'value': '640'},
      // {'name': '360P', 'value': '512'},
    ];
  }

  /// 获取支持的动态范围列表
  static List<Map<String, String>> getSupportedRanges() {
    return [
      {'name': 'Auto', 'value': 'auto'},
      {'name': 'SDR', 'value': 'SDR'},
      {'name': 'HDR', 'value': 'HLG'}
    ];
  }

  /// 获取支持的音频语言列表
  static List<Map<String, String>> getSupportedAudioLanguages() {
    return [
      {'name': 'English', 'value': 'eng'},
      {'name': 'Deutsch', 'value': 'deu'},
      {'name': 'Français', 'value': 'fra'},
      {'name': 'Español', 'value': 'spa'},
      {'name': 'Nederlands', 'value': 'nld'},
      {'name': 'Português', 'value': 'por'},
      {'name': 'FX', 'value': 'fx'},
      {'name': 'All Languages', 'value': 'all'},
    ];
  }

  /// 验证音频语言是否有效
  static bool isValidAudioLang(String audioLang) {
    const validLangs = ['eng', 'deu', 'fra', 'spa', 'nld', 'por', 'fx', 'all'];
    return validLangs.contains(audioLang.toLowerCase());
  }
}
