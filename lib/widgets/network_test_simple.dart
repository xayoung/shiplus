import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/http_service_simple.dart';
import '../services/http_debug.dart';

/// 简化版网络测试页面
class NetworkTestPage extends StatefulWidget {
  const NetworkTestPage({super.key});

  @override
  State<NetworkTestPage> createState() => _NetworkTestPageState();
}

class _NetworkTestPageState extends State<NetworkTestPage> {
  final List<String> _logs = [];
  bool _isLoading = false;

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  Future<void> _testBasicRequest() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _addLog('🚀 开始测试基本请求...');

      final response = await HttpService.dio.get('https://httpbin.org/get');

      if (response.statusCode == 200) {
        _addLog('✅ 基本请求成功: ${response.statusCode}');
        _addLog('📥 响应数据长度: ${response.data.toString().length}');
      } else {
        _addLog('❌ 请求失败: ${response.statusCode}');
      }
    } catch (e) {
      _addLog('❌ 请求异常: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testHeaders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _addLog('📋 开始测试请求头...');

      final response = await HttpService.dio.get('https://httpbin.org/headers');

      if (response.statusCode == 200) {
        _addLog('✅ 请求头测试成功');
        final headers = response.data['headers'];
        if (headers != null) {
          _addLog('📋 User-Agent: ${headers['User-Agent']}');
          _addLog('📋 Accept: ${headers['Accept']}');
        }
      } else {
        _addLog('❌ 请求头测试失败: ${response.statusCode}');
      }
    } catch (e) {
      _addLog('❌ 请求头测试异常: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testPostRequest() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _addLog('📤 开始测试 POST 请求...');

      final response = await HttpService.dio.post(
        'https://httpbin.org/post',
        data: {
          'test_key': 'test_value',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );

      if (response.statusCode == 200) {
        _addLog('✅ POST 请求成功: ${response.statusCode}');
        final json = response.data['json'];
        if (json != null) {
          _addLog('📥 服务器收到的数据: ${json['test_key']}');
        }
      } else {
        _addLog('❌ POST 请求失败: ${response.statusCode}');
      }
    } catch (e) {
      _addLog('❌ POST 请求异常: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testErrorHandling() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _addLog('⚠️ 开始测试错误处理...');

      // 测试 404 错误
      final response =
          await HttpService.dio.get('https://httpbin.org/status/404');
      _addLog('📊 404 响应: ${response.statusCode}');
    } catch (e) {
      _addLog('✅ 错误处理正常: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testApiRequest() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _addLog('🎯 开始测试实际API请求...');

      final response = await HttpService.dio
          .get('https://nodeapi.histreams.net/api/f1/compage/493');

      if (response.statusCode == 200) {
        _addLog('✅ API请求成功: ${response.statusCode}');
        _addLog('📥 响应数据长度: ${response.data.toString().length}');
      } else {
        _addLog('❌ API请求失败: ${response.statusCode}');
      }
    } catch (e) {
      _addLog('❌ API请求异常: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testSimpleConnection() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _addLog('🔌 开始测试简单连接...');

      // 使用一个简单的HTTP请求测试连接
      final response = await HttpService.dio.get('http://httpbin.org/get');

      if (response.statusCode == 200) {
        _addLog('✅ HTTP连接成功: ${response.statusCode}');
        _addLog('📥 响应数据长度: ${response.data.toString().length}');
      } else {
        _addLog('❌ HTTP连接失败: ${response.statusCode}');
      }
    } catch (e) {
      _addLog('❌ HTTP连接异常: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testRawDio() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _addLog('🔧 开始测试原生Dio...');

      // 创建一个全新的Dio实例，不使用全局配置
      final rawDio = Dio();
      rawDio.options.connectTimeout = const Duration(seconds: 10);
      rawDio.options.receiveTimeout = const Duration(seconds: 10);

      final response = await rawDio.get('https://httpbin.org/get');

      if (response.statusCode == 200) {
        _addLog('✅ 原生Dio请求成功: ${response.statusCode}');
        _addLog('📥 响应数据长度: ${response.data.toString().length}');
      } else {
        _addLog('❌ 原生Dio请求失败: ${response.statusCode}');
      }
    } catch (e) {
      _addLog('❌ 原生Dio请求异常: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _addLog('🔍 开始运行网络诊断...');

      // 初始化调试服务
      await HttpDebugService.init();

      // 运行完整诊断
      final results = await HttpDebugService.runDiagnostics();

      _addLog('📊 诊断结果:');
      results.forEach((test, success) {
        final status = success ? '✅' : '❌';
        _addLog('$status $test: ${success ? '成功' : '失败'}');
      });
    } catch (e) {
      _addLog('❌ 诊断异常: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('网络配置测试'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 测试按钮区域
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '网络功能测试',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _testBasicRequest,
                          icon: const Icon(Icons.http),
                          label: const Text('基本请求'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _testHeaders,
                          icon: const Icon(Icons.list_alt),
                          label: const Text('请求头'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _testPostRequest,
                          icon: const Icon(Icons.send),
                          label: const Text('POST 请求'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _testErrorHandling,
                          icon: const Icon(Icons.error),
                          label: const Text('错误处理'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _testApiRequest,
                          icon: const Icon(Icons.api),
                          label: const Text('API 测试'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _testSimpleConnection,
                          icon: const Icon(Icons.link),
                          label: const Text('简单连接'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _testRawDio,
                          icon: const Icon(Icons.build),
                          label: const Text('原生Dio'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _runDiagnostics,
                            icon: const Icon(Icons.medical_services),
                            label: const Text('完整诊断'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _clearLogs,
                            icon: const Icon(Icons.delete),
                            label: const Text('清除日志'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 日志显示区域
            Expanded(
              child: Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.terminal),
                          const SizedBox(width: 8),
                          const Text(
                            '测试日志',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (_isLoading)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: _logs.isEmpty
                            ? const Center(
                                child: Text(
                                  '点击上方按钮开始测试',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _logs.length,
                                itemBuilder: (context, index) {
                                  final log = _logs[index];
                                  return Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    child: Text(
                                      log,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        color: log.contains('❌')
                                            ? Colors.red
                                            : log.contains('✅')
                                                ? Colors.green
                                                : Colors.black87,
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
