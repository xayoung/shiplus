import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class Formula1Service {
  static const String _reese84Key = 'formula1_reese84_token';
  static const String _userDataKey = 'formula1_user_data';
  static const String _apiKey = 'BPhVa4xbZoebPNdxRor9rouq6gzMoPyZ';
  static const String _systemId = '60a9ad84-e93d-480f-80d6-af37494f2e22';
  
  // 获取 reese84 token - 静默模式，不显示对话框
  static Future<String?> getReese84Token(BuildContext context) async {
    print('开始静默获取 reese84 cookie...');
    final Completer<String?> completer = Completer<String?>();
    
    // 创建一个临时的 HeadlessInAppWebView
    final headlessWebView = HeadlessInAppWebView(
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      ),
      onWebViewCreated: (controller) {
        print('HeadlessInAppWebView 已创建，准备加载页面...');
        controller.loadUrl(
          urlRequest: URLRequest(
            url: WebUri("https://account.formula1.com/#/login"),
          ),
        );
      },
      onLoadStop: (controller, url) async {
        print('页面加载完成，等待生成 cookie...');
        // 页面加载完成后等待一段时间，确保 cookie 已经生成
        await Future.delayed(const Duration(seconds: 2));
        
        // 获取所有 cookie 并查找 reese84
        try {
          CookieManager cookieManager = CookieManager.instance();
          List<Cookie> cookies = await cookieManager.getCookies(url: WebUri("https://account.formula1.com/#/login"));
          
          print('===== Formula 1 Cookies =====');
          String? reese84Token;
          for (Cookie cookie in cookies) {
            print('Cookie: ${cookie.name} = ${cookie.value}');
            if (cookie.name == "reese84" && cookie.value.isNotEmpty) {
              reese84Token = cookie.value;
              break;
            }
          }
          print('===== End of Cookies =====');
          
          if (!completer.isCompleted) {
            print('找到 reese84 cookie: ${reese84Token != null}');
            completer.complete(reese84Token);
          }
        } catch (e) {
          print('获取 cookie 时出错: $e');
          if (!completer.isCompleted) {
            completer.completeError("Failed to get cookies: $e");
          }
        }
      },
      onReceivedError: (controller, request, error) {
        print('加载页面时出错: ${error.description}');
        if (!completer.isCompleted) {
          completer.completeError("Failed to load page: ${error.description}");
        }
      },
    );

    // 启动无头浏览器
    await headlessWebView.run();
    
    // 设置超时
    Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        print('获取 reese84 token 超时');
        completer.completeError("Timeout getting reese84 token");
        headlessWebView.dispose();
      }
    });

    try {
      // 等待获取 token
      final token = await completer.future;
      
      // 缓存 token
      if (token != null) {
        await _saveReese84Token(token);
        print('reese84 token 已保存到本地存储');
      }
      
      return token;
    } catch (e) {
      print('获取 reese84 token 失败: $e');
      return null;
    } finally {
      // 确保 headless webview 被释放
      headlessWebView.dispose();
      print('HeadlessInAppWebView 已释放');
    }
  }
  
  // 保存 reese84 token 到本地存储
  static Future<void> _saveReese84Token(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reese84Key, token);
  }
  
  // 从本地存储获取 reese84 token
  static Future<String?> getSavedReese84Token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_reese84Key);
  }
  
  // 全局变量，存储当前登录的用户数据
  static Map<String, dynamic>? _currentUserData;
  
  // 获取当前用户数据
  static Map<String, dynamic>? get currentUserData => _currentUserData;
  
  // 初始化方法，从本地存储加载数据到全局变量
  static Future<void> initialize() async {
    try {
      // 从本地存储加载用户数据
      final userData = await getSavedUserData();
      if (userData != null) {
        _currentUserData = userData;
        
        // 从用户数据中提取会话ID和订阅令牌
        if (userData['rawResponse'] != null) {
          final rawResponse = userData['rawResponse'];
        }
        
        print('Formula1Service 初始化完成，已从本地存储加载用户数据');
      } else {
        print('Formula1Service 初始化完成，没有找到保存的用户数据');
      }
    } catch (e) {
      print('Formula1Service 初始化出错: $e');
    }
  }
  
  // 登录 Formula 1 API
  static Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final reese84Token = await getSavedReese84Token();
      if (reese84Token == null) {
        print('登录失败: 没有获取到 reese84 token');
        throw Exception('No authentication token available');
      }
      
      print('===== Formula 1 登录请求信息 =====');
      print('登录 URL: https://api.formula1.com/v1/account/Subscriber/RegisterDevice');
      print('请求头:');
      print('X-D-Token: ${reese84Token.substring(0, 20)}...');
      print('apikey: $_apiKey');
      print('CD-SystemID: $_systemId');
      print('Content-Type: application/json');
      print('请求体:');
      print('Login: $email');
      print('Password: ${password.replaceAll(RegExp('.'), '*')}');
      var uuid = const Uuid().v1();
      
      final dio = Dio();
      
      // 添加请求拦截器，记录请求信息
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          print('发送请求: ${options.method} ${options.uri}');
          print('请求头: ${options.headers}');
          print('请求数据: ${options.data}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print('收到响应: ${response.statusCode}');
          print('响应头: ${response.headers}');
          print('响应数据: ${response.data}');
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          print('请求错误: ${e.message}');
          if (e.response != null) {
            print('错误状态码: ${e.response?.statusCode}');
            print('错误响应: ${e.response?.data}');
          }
          return handler.next(e);
        },
      ));
      
      final response = await dio.post(
        'https://api.formula1.com/v1/account/Subscriber/RegisterDevice',
        data: {
          'Login': email,
          'Password': password,
          'Nickname': 'shiplus',
          'PhysicalDevice': {
            'DeviceTypeCode': 12,
            'DeviceId':'$uuid-tvOS',
            'PhysicalDeviceTypeCode': 1002
          }
        },
        options: Options(
          headers: {
            'X-D-Token': reese84Token,
            'apikey': _apiKey,
            'CD-SystemID': _systemId,
            'Content-Type': 'application/json'
          }
        )
      );
      
      print('登录响应状态码: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // 保存原始响应数据
        final responseData = response.data;
        print('登录成功，原始响应数据: $responseData');
        
        
        // 构建用户数据结构
        final Map<String, dynamic> userData = {
          // 保存完整的原始响应数据
          'rawResponse': responseData,
        };
        
        // 从 PhysicalDevice 中提取设备信息
        if (responseData['PhysicalDevice'] != null) {
          userData['PhysicalDevice'] = responseData['PhysicalDevice'];
        }
        
        // 保存剩余设备关联数
        if (responseData['RemainingDeviceAssociations'] != null) {
          userData['RemainingDeviceAssociations'] = responseData['RemainingDeviceAssociations'];
        }
        
        // 从 SessionSummary 中提取基本信息
        if (responseData['SessionSummary'] != null) {
          final sessionSummary = responseData['SessionSummary'];
          userData['Email'] = sessionSummary['Email'] ?? email;
          userData['SubscriberId'] = sessionSummary['SubscriberId'] ?? '';
          userData['FirstName'] = sessionSummary['FirstName'] ?? '';
          userData['LastName'] = sessionSummary['LastName'] ?? '';
          userData['HomeCountry'] = sessionSummary['HomeCountry'] ?? '';
          userData['SubscriberLanguage'] = sessionSummary['SubscriberLanguage'] ?? 'en-GB';
          userData['Title'] = sessionSummary['Title'] ?? '';
          
          // 保存外部授权信息
          if (sessionSummary['ExternalAuthorizations'] != null) {
            userData['ExternalAuthorizations'] = sessionSummary['ExternalAuthorizations'];
          }
          
          // 保存条款接受时间
          if (sessionSummary['TermsAndConditionsAccepted'] != null) {
            userData['TermsAndConditionsAccepted'] = sessionSummary['TermsAndConditionsAccepted'];
          }
        }
        
        // 从 data 字段中提取订阅信息
        if (responseData['data'] != null) {
          final data = responseData['data'];
          
          // 订阅状态
          userData['Status'] = data['subscriptionStatus'] ?? 'Unknown';
          
          // 解析订阅令牌中的信息
          if (data['subscriptionToken'] != null) {
            try {
              // 解析 JWT token 的 payload 部分
              final String token = data['subscriptionToken'];
              final parts = token.split('.');
              if (parts.length > 1) {
                // 解码 base64
                final payload = parts[1];
                final normalized = base64Url.normalize(payload);
                final decodedPayload = utf8.decode(base64Url.decode(normalized));
                final payloadJson = jsonDecode(decodedPayload);
                
                // 保存完整的解码后的令牌数据
                userData['DecodedToken'] = payloadJson;
                
                // 提取订阅信息
                userData['SubscriptionInfo'] = {
                  'SubscriptionName': payloadJson['SubscribedProduct'] ?? 'F1 TV',
                  'SubscriptionStatus': payloadJson['SubscriptionStatus'] ?? 'active',
                  'ExpiryDate': payloadJson['exp'] != null 
                      ? DateTime.fromMillisecondsSinceEpoch(payloadJson['exp'] * 1000).toString()
                      : DateTime.now().add(const Duration(days: 30)).toString(),
                };
                
                // 提取权限信息
                if (payloadJson['ents'] != null && payloadJson['ents'] is List) {
                  final entitlements = payloadJson['ents'] as List;
                  userData['Entitlements'] = entitlements.map((ent) {
                    return {
                      'Name': ent['ent'] ?? 'Unknown',
                      'Country': ent['country'] ?? ''
                    };
                  }).toList();
                }
              }
            } catch (e) {
              print('解析订阅令牌时出错: $e');
              // 创建默认订阅信息
              userData['SubscriptionInfo'] = {
                'SubscriptionName': 'F1 TV Premium',
                'SubscriptionStatus': data['subscriptionStatus'] ?? 'active',
                'ExpiryDate': DateTime.now().add(const Duration(days: 30)).toString(),
              };
            }
          }
        }
        
        // 如果没有提取到权限信息，创建默认权限
        if (userData['Entitlements'] == null) {
          userData['Entitlements'] = [
            {'Name': 'PREMIUM', 'Country': userData['HomeCountry'] ?? ''},
            {'Name': 'REG', 'Country': userData['HomeCountry'] ?? ''}
          ];
        }
        
        // 如果没有提取到订阅信息，创建默认订阅信息
        if (userData['SubscriptionInfo'] == null) {
          userData['SubscriptionInfo'] = {
            'SubscriptionName': 'F1 TV Premium',
            'SubscriptionStatus': 'active',
            'ExpiryDate': DateTime.now().add(const Duration(days: 30)).toString(),
          };
        }
        
        print('处理后的用户数据: $userData');
        
        // 更新全局变量
        _currentUserData = userData;
        
        // 保存到本地存储
        await _saveUserData(userData);
        return userData;
      } else {
        print('登录失败，状态码: ${response.statusCode}');
        throw Exception('Login failed: ${response.statusCode}');
      }
    } catch (e) {
      print('登录异常: $e');
      if (e is DioException) {
        print('DioException 类型: ${e.type}');
        print('DioException 消息: ${e.message}');
        if (e.response != null) {
          print('错误响应状态码: ${e.response?.statusCode}');
          print('错误响应数据: ${e.response?.data}');
        }
      }
      return null;
    }
  }
  
  // 保存用户数据到本地存储
  static Future<void> _saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userDataKey, jsonEncode(userData));
  }
  
  // 从本地存储获取用户数据
  static Future<Map<String, dynamic>?> getSavedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString(_userDataKey);
    if (userDataString != null) {
      return jsonDecode(userDataString) as Map<String, dynamic>;
    }
    return null;
  }
  
  // 刷新令牌
  static Future<Map<String, dynamic>?> refreshToken() async {
    try {
      if (_currentUserData == null || _currentUserData!['PhysicalDevice'] == null) {
        print('刷新令牌失败: 没有用户数据或设备信息');
        return null;
      }
      
      final authenticationKey = _currentUserData!['PhysicalDevice']['AuthenticationKey'];
      if (authenticationKey == null) {
        print('刷新令牌失败: 没有找到 AuthenticationKey');
        return null;
      }
      final deviceId = _currentUserData!['PhysicalDevice']['DeviceId'];
      
      print('===== Formula 1 刷新令牌请求信息 =====');
      print('刷新令牌 URL: https://api.formula1.com/v2/account/subscriber/authenticate/by-device');
      print('请求头:');
      print('apikey: $_apiKey');
      print('Content-Type: application/json');
      print('请求体:');
      print('DistributionChannel: 40500b92-005d-4e10-972f-b41850d6125b');
      print('Language: en-GB');
      print('AuthenticationKey: ${authenticationKey.substring(0, 20)}...');
      
      final dio = Dio();
      
      // 添加请求拦截器，记录请求信息
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          print('发送请求: ${options.method} ${options.uri}');
          print('请求头: ${options.headers}');
          print('请求数据: ${options.data}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print('收到响应: ${response.statusCode}');
          print('响应头: ${response.headers}');
          print('响应数据: ${response.data}');
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          print('请求错误: ${e.message}');
          if (e.response != null) {
            print('错误状态码: ${e.response?.statusCode}');
            print('错误响应: ${e.response?.data}');
          }
          return handler.next(e);
        },
      ));
      
      final response = await dio.post(
        'https://api.formula1.com/v2/account/subscriber/authenticate/by-device',
        data: {
          'DistributionChannel': '40500b92-005d-4e10-972f-b41850d6125b',
          'Language': 'en-GB',
          'AuthenticationKey': authenticationKey,
          'DeviceId': deviceId
        },
        options: Options(
          headers: {
            'apikey': _apiKey,
            'Content-Type': 'application/json'
          }
        )
      );
      
      print('刷新令牌响应状态码: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // 保存原始响应数据
        final responseData = response.data;
        print('刷新令牌成功，原始响应数据: $responseData');
        // 更新用户数据
        if (_currentUserData != null) {
          
          // 更新会话ID
          if (responseData['AuthenticationKey'] != null) {
            _currentUserData!['SessionId'] = responseData['AuthenticationKey'];
            _currentUserData!['PhysicalDevice']['AuthenticationKey'] = responseData['AuthenticationKey'];
          }

          if (responseData['data'] != null) {
            _currentUserData!['data'] = responseData['data'];
          }
          
          // 保存更新后的用户数据
          await _saveUserData(_currentUserData!);
        }
        
        return _currentUserData;
      } else {
        print('刷新令牌失败，状态码: ${response.statusCode}');
        throw Exception('Token refresh failed: ${response.statusCode}');
      }
    } catch (e) {
      print('刷新令牌异常: $e');
      if (e is DioException) {
        print('DioException 类型: ${e.type}');
        print('DioException 消息: ${e.message}');
        if (e.response != null) {
          print('错误响应状态码: ${e.response?.statusCode}');
          print('错误响应数据: ${e.response?.data}');
        }
      }
      return null;
    }
  }
  
  // 注销设备
  static Future<bool> unregisterDevice() async {
    try {
      if (_currentUserData == null || 
          _currentUserData!['PhysicalDevice'] == null || 
          _currentUserData!['rawResponse'] == null) {
        print('注销设备失败: 没有用户数据或设备信息');
        return false;
      }
      
      final deviceId = _currentUserData!['PhysicalDevice']['DeviceId'];
      final authenticationKey = _currentUserData!['PhysicalDevice']['AuthenticationKey'];
      final sessionId = _currentUserData!['rawResponse']['SessionId'];
      
      if (deviceId == null || authenticationKey == null || sessionId == null) {
        print('注销设备失败: 缺少必要的设备信息');
        return false;
      }
      
      print('===== Formula 1 注销设备请求信息 =====');
      print('注销设备 URL: https://api.formula1.com/v1/account/Subscriber/UnregisterDevice');
      print('请求头:');
      print('apikey: $_apiKey');
      print('CD-SessionID: $sessionId');
      print('CD-SystemID: $_systemId');
      print('Content-Type: application/json');
      print('请求体:');
      print('DeviceId: $deviceId');
      print('AuthenticationKey: ${authenticationKey.substring(0, 20)}...');
      
      final dio = Dio();
      
      // 添加请求拦截器，记录请求信息
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          print('发送请求: ${options.method} ${options.uri}');
          print('请求头: ${options.headers}');
          print('请求数据: ${options.data}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print('收到响应: ${response.statusCode}');
          print('响应头: ${response.headers}');
          print('响应数据: ${response.data}');
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          print('请求错误: ${e.message}');
          if (e.response != null) {
            print('错误状态码: ${e.response?.statusCode}');
            print('错误响应: ${e.response?.data}');
          }
          return handler.next(e);
        },
      ));
      
      final response = await dio.post(
        'https://api.formula1.com/v1/account/Subscriber/UnregisterDevice',
        data: {
          'DeviceId': deviceId,
          'AuthenticationKey': authenticationKey
        },
        options: Options(
          headers: {
            'apikey': _apiKey,
            'CD-SessionID': sessionId,
            'CD-SystemID': _systemId,
            'Content-Type': 'application/json'
          }
        )
      );
      
      print('注销设备响应状态码: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        print('注销设备成功');
        return true;
      } else {
        print('注销设备失败，状态码: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('注销设备异常: $e');
      if (e is DioException) {
        print('DioException 类型: ${e.type}');
        print('DioException 消息: ${e.message}');
        if (e.response != null) {
          print('错误响应状态码: ${e.response?.statusCode}');
          print('错误响应数据: ${e.response?.data}');
        }
      }
      return false;
    }
  }
  
  // 清除所有缓存的数据
  static Future<void> clearAllData() async {
    try {
      // 先尝试注销设备
      if (_currentUserData != null) {
        await unregisterDevice();
      }
    } catch (e) {
      print('注销设备时出错: $e');
    } finally {
      // 无论注销是否成功，都清除本地数据
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_reese84Key);
      await prefs.remove(_userDataKey);
      _currentUserData = null;
    }
  }
}