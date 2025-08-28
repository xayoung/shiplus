import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'dart:io';

/// 简化版全局HTTP服务配置
class HttpService {
  static HttpService? _instance;
  static Dio? _dio;

  // 私有构造函数
  HttpService._();

  /// 获取单例实例
  static HttpService get instance {
    _instance ??= HttpService._();
    return _instance!;
  }

  /// 获取配置好的Dio实例
  static Dio get dio {
    if (_dio == null) {
      throw Exception(
          'HttpService not initialized. Call HttpService.init() first.');
    }
    return _dio!;
  }

  /// 初始化HTTP服务
  static Future<void> init() async {
    if (_dio != null) return; // 已经初始化过了

    // 创建Dio实例
    _dio = Dio();

    // 基础配置
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

    // 配置HTTP客户端适配器，处理SSL证书问题
    if (_dio!.httpClientAdapter is IOHttpClientAdapter) {
      (_dio!.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();

        // 设置更宽松的SSL配置
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) {
          print('⚠️ SSL Certificate warning for $host:$port');
          return true; // 在开发环境中接受所有证书
        };

        // 设置连接超时
        client.connectionTimeout = const Duration(seconds: 30);

        // 设置空闲超时
        client.idleTimeout = const Duration(seconds: 30);

        return client;
      };
    }

    // 添加拦截器
    _addInterceptors();

    print('HttpService initialized successfully');
  }

  /// 添加拦截器
  static void _addInterceptors() {
    // 请求拦截器
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
              '✅ Response: ${response.statusCode} ${response.requestOptions.uri}');
          print(
              '📥 Response Data Length: ${response.data?.toString().length ?? 0}');
          handler.next(response);
        },
        onError: (error, handler) {
          print('❌ Error Type: ${error.type}');
          print('❌ Error Message: ${error.message}');
          print('❌ Error toString: ${error.toString()}');
          print(
              '🔗 Request: ${error.requestOptions.method} ${error.requestOptions.uri}');

          // 打印更详细的错误信息
          if (error.error != null) {
            print('❌ Underlying Error: ${error.error}');
            print('❌ Underlying Error Type: ${error.error.runtimeType}');
          }

          if (error.response != null) {
            print(
                '📊 Error Response: ${error.response?.statusCode} ${error.response?.data}');
          } else {
            print('📊 No response received');
          }

          // 检查是否是SSL证书问题
          if (error.error is HandshakeException) {
            print('🔒 SSL Handshake Error detected');
          }

          handler.next(error);
        },
      ),
    );

    // 重试拦截器（可选）
    _dio!.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          // 对于网络错误，可以实现重试逻辑
          if (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.sendTimeout) {
            final requestOptions = error.requestOptions;
            final retryCount = requestOptions.extra['retryCount'] ?? 0;

            if (retryCount < 3) {
              print(
                  '🔄 Retrying request (${retryCount + 1}/3): ${requestOptions.uri}');
              requestOptions.extra['retryCount'] = retryCount + 1;

              try {
                final response = await _dio!.fetch(requestOptions);
                handler.resolve(response);
                return;
              } catch (e) {
                // 重试失败，继续抛出原错误
              }
            }
          }

          handler.next(error);
        },
      ),
    );
  }

  /// 创建带有自定义配置的Dio实例
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
      headers: {
        ...(_dio?.options.headers ?? {}),
        ...(headers ?? {}),
      },
    );

    return customDio;
  }

  /// 释放资源
  static void dispose() {
    _dio?.close();
    _dio = null;
    _instance = null;
    print('HttpService disposed');
  }
}

/// 便捷的HTTP请求方法
class Http {
  /// GET请求
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

  /// POST请求
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

  /// PUT请求
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

  /// DELETE请求
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
