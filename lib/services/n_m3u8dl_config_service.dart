class N_m3u8dlConfigService {
  static const String defaultFormat = 'mp4';
  static const bool defaultSkipSub = true;
  static const String defaultResolution = 'best';
  static const String defaultRange = 'auto';
  static const String defaultAudioLang = 'eng';

  static String _format = defaultFormat;
  static bool _skipSub = defaultSkipSub;
  static String _resolution = defaultResolution;
  static String _range = defaultRange;
  static String _audioLang = defaultAudioLang;

  static void clearCache() {
    _format = defaultFormat;
    _skipSub = defaultSkipSub;
    _resolution = defaultResolution;
    _range = defaultRange;
    _audioLang = defaultAudioLang;
  }

  static Future<String> getFormat() async {
    return _format;
  }

  static Future<void> setFormat(String format) async {
    _format = format;
  }

  static Future<bool> getSkipSub() async {
    return _skipSub;
  }

  static Future<void> setSkipSub(bool skipSub) async {
    _skipSub = skipSub;
  }

  static Future<String> getResolution() async {
    return _resolution;
  }

  static Future<void> setResolution(String resolution) async {
    _resolution = resolution;
  }

  static Future<String> getRange() async {
    return _range;
  }

  static Future<void> setRange(String range) async {
    _range = range;
  }

  static Future<String> getAudioLang() async {
    return _audioLang;
  }

  static Future<void> setAudioLang(String audioLang) async {
    _audioLang = audioLang;
  }

  static Future<String> getMuxerParameter() async {
    final format = await getFormat();
    final skipSub = await getSkipSub();

    String parameter = 'format=$format:muxer=ffmpeg:skip_sub=$skipSub';

    return parameter;
  }

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

  static Future<void> resetToDefaults() async {
    await setFormat(defaultFormat);
    await setSkipSub(defaultSkipSub);
    await setResolution(defaultResolution);
    await setRange(defaultRange);
    await setAudioLang(defaultAudioLang);
  }

  static Future<Map<String, dynamic>> getAllConfig() async {
    return {
      'format': await getFormat(),
      'skipSub': await getSkipSub(),
      'resolution': await getResolution(),
      'range': await getRange(),
      'audioLang': await getAudioLang(),
    };
  }

  static bool isValidFormat(String format) {
    return ['mp4', 'mkv'].contains(format.toLowerCase());
  }

  static List<String> getSupportedFormats() {
    return ['mp4', 'mkv'];
  }

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

  static List<Map<String, String>> getSupportedRanges() {
    return [
      {'name': 'Auto', 'value': 'auto'},
      {'name': 'SDR', 'value': 'SDR'},
      {'name': 'HDR', 'value': 'HLG'},
    ];
  }

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

  static bool isValidAudioLang(String audioLang) {
    const validLangs = ['eng', 'deu', 'fra', 'spa', 'nld', 'por', 'fx', 'all'];
    return validLangs.contains(audioLang.toLowerCase());
  }
}
