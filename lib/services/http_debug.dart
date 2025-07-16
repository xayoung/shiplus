import 'package:dio/dio.dart';
import 'dart:io';

/// 调试版HTTP服务 - 最简配置
class HttpDebugService {
  static Dio? _dio;

  /// 初始化最简HTTP服务
  static Future<void> init() async {
    if (_dio != null) return;

    _dio = Dio();
    
    // 最基本的配置
    _dio!.options = BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    );

    // 添加基本的日志拦截器
    _dio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          print('🚀 [DEBUG] Request: ${options.method} ${options.uri}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          print('✅ [DEBUG] Response: ${response.statusCode}');
          handler.next(response);
        },
        onError: (error, handler) {
          print('❌ [DEBUG] Error: ${error.type}');
          print('❌ [DEBUG] Message: ${error.message}');
          print('❌ [DEBUG] Error Object: ${error.error}');
          print('❌ [DEBUG] Stack Trace: ${error.stackTrace}');
          handler.next(error);
        },
      ),
    );

    print('✅ [DEBUG] HttpDebugService initialized');
  }

  /// 获取Dio实例
  static Dio get dio {
    if (_dio == null) {
      throw Exception('HttpDebugService not initialized');
    }
    return _dio!;
  }

  /// 测试基本连接
  static Future<bool> testConnection() async {
    try {
      print('🔍 [DEBUG] Testing basic connection...');
      final response = await _dio!.get('https://httpbin.org/get');
      print('✅ [DEBUG] Connection test successful: ${response.statusCode}');
      return true;
    } catch (e) {
      print('❌ [DEBUG] Connection test failed: $e');
      return false;
    }
  }

  /// 测试HTTP连接（非HTTPS）
  static Future<bool> testHttpConnection() async {
    try {
      print('🔍 [DEBUG] Testing HTTP connection...');
      final response = await _dio!.get('http://httpbin.org/get');
      print('✅ [DEBUG] HTTP connection test successful: ${response.statusCode}');
      return true;
    } catch (e) {
      print('❌ [DEBUG] HTTP connection test failed: $e');
      return false;
    }
  }

  /// 测试目标API
  static Future<bool> testTargetApi() async {
    try {
      print('🔍 [DEBUG] Testing target API...');
      final response = await _dio!.get('https://nodeapi.histreams.net/api/f1/compage/493');
      print('✅ [DEBUG] Target API test successful: ${response.statusCode}');
      return true;
    } catch (e) {
      print('❌ [DEBUG] Target API test failed: $e');
      return false;
    }
  }

  /// 创建原生Dio实例（不使用任何配置）
  static Dio createRawDio() {
    final rawDio = Dio();
    rawDio.options.connectTimeout = const Duration(seconds: 10);
    rawDio.options.receiveTimeout = const Duration(seconds: 10);
    
    rawDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          print('🔧 [RAW] Request: ${options.method} ${options.uri}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          print('✅ [RAW] Response: ${response.statusCode}');
          handler.next(response);
        },
        onError: (error, handler) {
          print('❌ [RAW] Error: ${error.type} - ${error.message}');
          handler.next(error);
        },
      ),
    );
    
    return rawDio;
  }

  /// 运行完整的诊断测试
  static Future<Map<String, bool>> runDiagnostics() async {
    final results = <String, bool>{};
    
    print('🔍 [DEBUG] Starting network diagnostics...');
    
    // 测试1: 原生Dio
    try {
      final rawDio = createRawDio();
      final response = await rawDio.get('https://httpbin.org/get');
      results['raw_dio'] = response.statusCode == 200;
    } catch (e) {
      results['raw_dio'] = false;
      print('❌ [DEBUG] Raw Dio test failed: $e');
    }
    
    // 测试2: HTTP连接
    results['http_connection'] = await testHttpConnection();
    
    // 测试3: HTTPS连接
    results['https_connection'] = await testConnection();
    
    // 测试4: 目标API
    results['target_api'] = await testTargetApi();
    
    print('🔍 [DEBUG] Diagnostics complete: $results');
    return results;
  }

  /// 释放资源
  static void dispose() {
    _dio?.close();
    _dio = null;
    print('🗑️ [DEBUG] HttpDebugService disposed');
  }
}

/// 简化的HTTP请求方法
class HttpDebug {
  static Future<Response<T>> get<T>(String path) {
    return HttpDebugService.dio.get<T>(path);
  }

  static Future<Response<T>> post<T>(String path, {dynamic data}) {
    return HttpDebugService.dio.post<T>(path, data: data);
  }
}
