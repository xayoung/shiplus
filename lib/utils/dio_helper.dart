import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'dart:developer' as developer;

/// Dio 工具类，用于创建 Dio 实例
class DioHelper {
  /// 创建带有 CookieManager 的 Dio 实例
  /// 注意：需要手动添加 Cookie 管理器
  static Dio createDioWithCookies({bool enableDebug = false}) {
    final dio = Dio();
    // 注意：Cookie 管理器需要在调用处手动添加
    final cookieJar = CookieJar();
    dio.interceptors.add(CookieManager(cookieJar));

    // 添加调试拦截器用于打印 cookies
    if (enableDebug) {
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          _printCookiesForUrl(cookieJar, options.uri);
          handler.next(options);
        },
        onResponse: (response, handler) {
          developer
              .log('Response received from: ${response.requestOptions.uri}');
          _printCookiesForUrl(cookieJar, response.requestOptions.uri);
          handler.next(response);
        },
      ));
    }

    return dio;
  }

  /// 创建普通的 Dio 实例（不带 Cookie 管理）
  static Dio createPlainDio() {
    return Dio();
  }

  /// 打印指定 URL 的 cookies（用于调试）
  static Future<void> printCookiesForUrl(
      CookieJar cookieJar, String url) async {
    final uri = Uri.parse(url);
    await _printCookiesForUrl(cookieJar, uri);
  }

  /// 内部方法：打印指定 URI 的 cookies
  static Future<void> _printCookiesForUrl(CookieJar cookieJar, Uri uri) async {
    try {
      final cookies = await cookieJar.loadForRequest(uri);
      if (cookies.isNotEmpty) {
        developer.log('🍪 Cookies for ${uri.host}:');
        for (final cookie in cookies) {
          developer.log('  ${cookie.name}=${cookie.value}');
        }
      } else {
        developer.log('🍪 No cookies found for ${uri.host}');
      }
    } catch (e) {
      developer.log('❌ Error reading cookies for ${uri.host}: $e');
    }
  }

  /// 打印所有存储的 cookies（用于调试）
  static Future<void> printAllCookies(CookieJar cookieJar) async {
    try {
      // 注意：CookieJar 没有直接获取所有 cookies 的方法
      // 这里只能打印提示信息
      developer.log(
          '🍪 Cookie jar is active. Use printCookiesForUrl() to check specific URLs.');
    } catch (e) {
      developer.log('❌ Error accessing cookie jar: $e');
    }
  }
}
