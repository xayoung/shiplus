import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:dio/io.dart';
import 'dart:io';
import '../services/proxy_service.dart';

class DioHelper {
  static Future<Dio> createDioWithCookies({bool enableDebug = false}) async {
    final dio = Dio();

    await _configureProxy(dio);

    final cookieJar = CookieJar();
    dio.interceptors.add(CookieManager(cookieJar));

    if (enableDebug) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            _printCookiesForUrl(cookieJar, options.uri);
            handler.next(options);
          },
          onResponse: (response, handler) {
            print('Response received from: ${response.requestOptions.uri}');
            _printCookiesForUrl(cookieJar, response.requestOptions.uri);
            handler.next(response);
          },
        ),
      );
    }

    return dio;
  }

  static Future<Dio> createPlainDio() async {
    final dio = Dio();

    await _configureProxy(dio);

    return dio;
  }

  static Future<void> _configureProxy(Dio dio) async {
    try {
      final proxyConfig = await ProxyService.getProxyConfig();
      final proxyEnabled = proxyConfig['enabled'] as bool;
      final proxyUrl = proxyConfig['url'] as String;

      if (proxyEnabled && proxyUrl.isNotEmpty) {
        (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
          final client = HttpClient();

          final uri = Uri.parse(proxyUrl);
          final proxyHost = uri.host;
          final proxyPort = uri.port;

          // if (uri.scheme == 'http' || uri.scheme == 'https') {
          //   client.findProxy = (url) {
          //     return 'PROXY $proxyHost:$proxyPort';
          //   };
          // }
          client.findProxy = (url) {
            return 'PROXY $proxyHost:$proxyPort';
          };

          // else if (uri.scheme == 'socks5') {
          //   client.findProxy = (url) {
          //     return 'SOCKS5 $proxyHost:$proxyPort';
          //   };
          // }

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

          client.badCertificateCallback = (cert, host, port) => true;

          return client;
        };

        print('🌐 Proxy configured: $proxyUrl');
      } else {
        print('🌐 No proxy configured');
      }
    } catch (e) {
      print('❌ Error configuring proxy: $e');
    }
  }

  static Future<void> printCookiesForUrl(
    CookieJar cookieJar,
    String url,
  ) async {
    final uri = Uri.parse(url);
    await _printCookiesForUrl(cookieJar, uri);
  }

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

  static Future<void> printAllCookies(CookieJar cookieJar) async {
    try {
      print(
        '🍪 Cookie jar is active. Use printCookiesForUrl() to check specific URLs.',
      );
    } catch (e) {
      print('❌ Error accessing cookie jar: $e');
    }
  }
}
