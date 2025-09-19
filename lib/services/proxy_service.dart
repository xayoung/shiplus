import 'package:shared_preferences/shared_preferences.dart';

class ProxyService {
  static const String _proxyEnabledKey = 'proxy_enabled';
  static const String _proxyUrlKey = 'proxy_url';
  
  // Default values
  static const bool defaultProxyEnabled = false;
  static const String defaultProxyUrl = '';

  /// Get proxy enabled status
  static Future<bool> getProxyEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_proxyEnabledKey) ?? defaultProxyEnabled;
    } catch (e) {
      print('Error getting proxy enabled status: $e');
      return defaultProxyEnabled;
    }
  }

  /// Set proxy enabled status
  static Future<void> setProxyEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_proxyEnabledKey, enabled);
    } catch (e) {
      print('Error setting proxy enabled status: $e');
      throw Exception('Failed to save proxy enabled status');
    }
  }

  /// Get proxy URL
  static Future<String> getProxyUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_proxyUrlKey) ?? defaultProxyUrl;
    } catch (e) {
      print('Error getting proxy URL: $e');
      return defaultProxyUrl;
    }
  }

  /// Set proxy URL
  static Future<void> setProxyUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_proxyUrlKey, url);
    } catch (e) {
      print('Error setting proxy URL: $e');
      throw Exception('Failed to save proxy URL');
    }
  }

  /// Get proxy configuration
  static Future<Map<String, dynamic>> getProxyConfig() async {
    try {
      final enabled = await getProxyEnabled();
      final url = await getProxyUrl();
      return {
        'enabled': enabled,
        'url': url,
      };
    } catch (e) {
      print('Error getting proxy configuration: $e');
      return {
        'enabled': defaultProxyEnabled,
        'url': defaultProxyUrl,
      };
    }
  }

  /// Set proxy configuration
  static Future<void> setProxyConfig({
    required bool enabled,
    required String url,
  }) async {
    try {
      await setProxyEnabled(enabled);
      await setProxyUrl(url);
    } catch (e) {
      print('Error setting proxy configuration: $e');
      throw Exception('Failed to save proxy configuration');
    }
  }

  /// Clear proxy configuration
  static Future<void> clearProxyConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_proxyEnabledKey);
      await prefs.remove(_proxyUrlKey);
    } catch (e) {
      print('Error clearing proxy configuration: $e');
      throw Exception('Failed to clear proxy configuration');
    }
  }

  /// Reset proxy configuration to defaults
  static Future<void> resetToDefaults() async {
    try {
      await setProxyEnabled(defaultProxyEnabled);
      await setProxyUrl(defaultProxyUrl);
    } catch (e) {
      print('Error resetting proxy configuration: $e');
      throw Exception('Failed to reset proxy configuration');
    }
  }

  /// Validate proxy URL format
  static bool isValidProxyUrl(String url) {
    if (url.isEmpty) return true; // Empty URL is valid (no proxy)
    
    try {
      final uri = Uri.parse(url);
      // Check if it's a valid HTTP/HTTPS/SOCKS URL
      return uri.hasScheme && 
             (uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme == 'socks5') &&
             uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }
}