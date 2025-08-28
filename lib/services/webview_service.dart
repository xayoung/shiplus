import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebViewService {
  static Future<void> openF1LoginPage(BuildContext context) async {
    final Completer<List<Cookie>> completer = Completer<List<Cookie>>();
    
    // 创建一个临时的 HeadlessInAppWebView
    final headlessWebView = HeadlessInAppWebView(
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      ),
      onWebViewCreated: (controller) {
        controller.loadUrl(
          urlRequest: URLRequest(
            url: WebUri("https://account.formula1.com/#/login"),
          ),
        );
      },
      onLoadStop: (controller, url) async {
        // 页面加载完成后等待一段时间，确保 cookie 已经生成
        await Future.delayed(const Duration(seconds: 2));
        
        // 获取所有 cookie 并打印
        try {
          CookieManager cookieManager = CookieManager.instance();
          List<Cookie> cookies = await cookieManager.getCookies(url: WebUri("https://account.formula1.com/#/login"));
          
          print('===== Formula 1 Cookies =====');
          for (Cookie cookie in cookies) {
            print('Cookie: ${cookie.name} = ${cookie.value}');
          }
          print('===== End of Cookies =====');
          
          if (!completer.isCompleted) {
            completer.complete(cookies);
          }
        } catch (e) {
          developer.log('Error getting cookies: $e');
          if (!completer.isCompleted) {
            completer.completeError("Failed to get cookies: $e");
          }
        }
      },
      onReceivedError: (controller, request, error) {
        developer.log('Error loading page: ${error.description}');
        if (!completer.isCompleted) {
          completer.completeError("Failed to load page: ${error.description}");
        }
      },
    );

    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Loading Formula 1 Login Page'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Loading Formula 1 login page...'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  headlessWebView.dispose();
                  Navigator.of(context).pop();
                  if (!completer.isCompleted) {
                    completer.completeError("Operation cancelled by user");
                  }
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );

    // 启动无头浏览器
    await headlessWebView.run();
    
    // 设置超时
    Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        // 尝试获取 cookie
        CookieManager.instance().getCookies(
          url: WebUri("https://account.formula1.com/#/login")
        ).then((cookies) {
          completer.complete(cookies);
        }).catchError((e) {
          completer.completeError("Timeout: $e");
        });
        
        headlessWebView.dispose();
        Navigator.of(context, rootNavigator: true).pop();
      }
    });

    try {
      // 等待获取 cookie
      final cookies = await completer.future;
      
      // 关闭加载对话框
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      // 构建 cookie 信息字符串
      String cookieInfo = '';
      for (Cookie cookie in cookies) {
        cookieInfo += '${cookie.name} = ${cookie.value}\n\n';
      }
      
      // 显示 cookie 信息
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Formula 1 Cookies'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Cookies have been printed to console. Here are the cookies:'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      cookieInfo.isEmpty ? 'No cookies found' : cookieInfo,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      // 显示错误消息
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to get Formula 1 cookies: $e'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } finally {
      // 确保 headless webview 被释放
      headlessWebView.dispose();
    }
  }
}
