import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'dart:io';

class HttpService {
  static HttpService? _instance;
  static Dio? _dio;

  HttpService._();

  static HttpService get instance {
    _instance ??= HttpService._();
    return _instance!;
  }

  static Dio get dio {
    if (_dio == null) {
      throw Exception(
        'HttpService not initialized. Call HttpService.init() first.',
      );
    }
    return _dio!;
  }

  static Future<void> init() async {
    if (_dio != null) return;

    _dio = Dio();

    _dio!.options = BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
      },
    );

    if (_dio!.httpClientAdapter is IOHttpClientAdapter) {
      (_dio!.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();

        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) {
              print('⚠️ SSL Certificate warning for $host:$port');
              return true;
            };

        client.connectionTimeout = const Duration(seconds: 30);

        client.idleTimeout = const Duration(seconds: 30);

        return client;
      };
    }

    _addInterceptors();

    print('HttpService initialized successfully');
  }

  static void _addInterceptors() {
    _dio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          print('🚀 Request: ${options.method} ${options.uri}');
          if (options.data != null) {
            print('📤 Request Data: ${options.data}');
          }
          if (options.headers.isNotEmpty) {
            print('📋 Request Headers: ${options.headers}');
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          print(
            '✅ Response: ${response.statusCode} ${response.requestOptions.uri}',
          );
          print(
            '📥 Response Data Length: ${response.data?.toString().length ?? 0}',
          );
          handler.next(response);
        },
        onError: (error, handler) {
          print('❌ Error Type: ${error.type}');
          print('❌ Error Message: ${error.message}');
          print('❌ Error toString: ${error.toString()}');
          print(
            '🔗 Request: ${error.requestOptions.method} ${error.requestOptions.uri}',
          );

          if (error.error != null) {
            print('❌ Underlying Error: ${error.error}');
            print('❌ Underlying Error Type: ${error.error.runtimeType}');
          }

          if (error.response != null) {
            print(
              '📊 Error Response: ${error.response?.statusCode} ${error.response?.data}',
            );
          } else {
            print('📊 No response received');
          }

          if (error.error is HandshakeException) {
            print('🔒 SSL Handshake Error detected');
          }

          handler.next(error);
        },
      ),
    );

    _dio!.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          if (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.sendTimeout) {
            final requestOptions = error.requestOptions;
            final retryCount = requestOptions.extra['retryCount'] ?? 0;

            if (retryCount < 3) {
              print(
                '🔄 Retrying request (${retryCount + 1}/3): ${requestOptions.uri}',
              );
              requestOptions.extra['retryCount'] = retryCount + 1;

              try {
                final response = await _dio!.fetch(requestOptions);
                handler.resolve(response);
                return;
              } catch (e) {}
            }
          }

          handler.next(error);
        },
      ),
    );
  }

  static Dio createCustomDio({
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    Map<String, dynamic>? headers,
  }) {
    final customDio = Dio();

    customDio.options = BaseOptions(
      connectTimeout: connectTimeout ?? const Duration(seconds: 30),
      receiveTimeout: receiveTimeout ?? const Duration(seconds: 30),
      sendTimeout: sendTimeout ?? const Duration(seconds: 30),
      headers: {...(_dio?.options.headers ?? {}), ...(headers ?? {})},
    );

    return customDio;
  }

  static void dispose() {
    _dio?.close();
    _dio = null;
    _instance = null;
    print('HttpService disposed');
  }
}

class Http {
  static Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) {
    return HttpService.dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }

  static Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return HttpService.dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  static Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return HttpService.dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  static Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return HttpService.dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
}
