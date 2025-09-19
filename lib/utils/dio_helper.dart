import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:dio/io.dart';
import 'dart:io';
import '../services/proxy_service.dart';

/// Dio 工具类，用于创建 Dio 实例
class DioHelper {
  /// 创建带有 CookieManager 的 Dio 实例
  /// 注意：需要手动添加 Cookie 管理器
  static Future<Dio> createDioWithCookies({bool enableDebug = false}) async {
    final dio = Dio();
    
    // 配置代理
    await _configureProxy(dio);
    
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
          print('Response received from: ${response.requestOptions.uri}');
          _printCookiesForUrl(cookieJar, response.requestOptions.uri);
          handler.next(response);
        },
      ));
    }

    return dio;
  }

  /// 创建普通的 Dio 实例（不带 Cookie 管理）
  static Future<Dio> createPlainDio() async {
    final dio = Dio();
    
    // 配置代理
    await _configureProxy(dio);
    
    return dio;
  }

  /// 配置代理设置
  static Future<void> _configureProxy(Dio dio) async {
    try {
      final proxyConfig = await ProxyService.getProxyConfig();
      final proxyEnabled = proxyConfig['enabled'] as bool;
      final proxyUrl = proxyConfig['url'] as String;

      if (proxyEnabled && proxyUrl.isNotEmpty) {
        // 配置代理
        (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
          final client = HttpClient();
          
          // 解析代理URL
          final uri = Uri.parse(proxyUrl);
          final proxyHost = uri.host;
          final proxyPort = uri.port;
          
          // if (uri.scheme == 'http' || uri.scheme == 'https') {
          //   // HTTP/HTTPS 代理
          //   client.findProxy = (url) {
          //     return 'PROXY $proxyHost:$proxyPort';
          //   };
          // }
          client.findProxy = (url) {
              return 'PROXY $proxyHost:$proxyPort';
            }; 
          
          // else if (uri.scheme == 'socks5') {
          //   // SOCKS5 代理
          //   client.findProxy = (url) {
          //     return 'SOCKS5 $proxyHost:$proxyPort';
          //   };
          // }
          
          // 处理代理认证
          if (uri.userInfo.isNotEmpty) {
            final credentials = uri.userInfo.split(':');
            if (credentials.length == 2) {
              client.addProxyCredentials(
                proxyHost,
                proxyPort,
                'realm',
                HttpClientBasicCredentials(credentials[0], credentials[1]),
              );
            }
          }
          
          // 忽略证书错误（可选，用于开发环境）
          client.badCertificateCallback = (cert, host, port) => true;
          
          return client;
        };
        
        print('🌐 Proxy configured: $proxyUrl');
      } else {
        print('🌐 No proxy configured');
      }
    } catch (e) {
      print('❌ Error configuring proxy: $e');
      // 代理配置失败时继续使用默认配置
    }
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
        print('🍪 Cookies for ${uri.host}:');
        for (final cookie in cookies) {
          print('  ${cookie.name}=${cookie.value}');
        }
      } else {
        print('🍪 No cookies found for ${uri.host}');
      }
    } catch (e) {
      print('❌ Error reading cookies for ${uri.host}: $e');
    }
  }

  /// 打印所有存储的 cookies（用于调试）
  static Future<void> printAllCookies(CookieJar cookieJar) async {
    try {
      // 注意：CookieJar 没有直接获取所有 cookies 的方法
      // 这里只能打印提示信息
      print(
          '🍪 Cookie jar is active. Use printCookiesForUrl() to check specific URLs.');
    } catch (e) {
      print('❌ Error accessing cookie jar: $e');
    }
  }
}
