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
    final Completer<String?> completer = Completer<String?>();
    
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
        
        // 获取所有 cookie 并查找 reese84
        try {
          CookieManager cookieManager = CookieManager.instance();
          List<Cookie> cookies = await cookieManager.getCookies(url: WebUri("https://account.formula1.com/#/login"));
          
          String? reese84Token;
          for (Cookie cookie in cookies) {
            if (cookie.name == "reese84" && cookie.value.isNotEmpty) {
              reese84Token = cookie.value;
              break;
            }
          }
          
          if (!completer.isCompleted) {
            completer.complete(reese84Token);
          }
        } catch (e) {
          if (!completer.isCompleted) {
            completer.completeError("Failed to get cookies: $e");
          }
        }
      },
      onReceivedError: (controller, request, error) {
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
      }
      
      return token;
    } catch (e) {
      return null;
    } finally {
      // 确保 headless webview 被释放
      headlessWebView.dispose();
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
      }
    } catch (e) {
      // 初始化错误处理
    }
  }
  
  // 登录 Formula 1 API
  static Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final reese84Token = await getSavedReese84Token();
      if (reese84Token == null) {
        throw Exception('No authentication token available');
      }
      
      var uuid = const Uuid().v1();
      
      final dio = Dio();
      
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
      
      if (response.statusCode == 200 && response.data['data'] != null) {
        // 保存原始响应数据
        final responseData = response.data;
        
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
          userData['data'] = data;
          // 订阅状态
          userData['Status'] = data['subscriptionStatus'] ?? 'Unknown';
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
        
        // 更新全局变量
        _currentUserData = userData;
        print('currentUserData: $_currentUserData');
        
        // 保存到本地存储
        await _saveUserData(userData);
        return userData;
      } else {
        throw Exception('Login failed: ${response}');
      }
    } catch (e) {
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
        return null;
      }
      
      final authenticationKey = _currentUserData!['PhysicalDevice']['AuthenticationKey'];
      if (authenticationKey == null) {
        return null;
      }
      final deviceId = _currentUserData!['PhysicalDevice']['DeviceId'];
      
      final dio = Dio();
      
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
      
      if (response.statusCode == 200) {
        // 保存原始响应数据
        final responseData = response.data;
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
        throw Exception('Token refresh failed: ${response.statusCode}');
      }
    } catch (e) {
      return null;
    }
  }
  
  // 注销设备
  static Future<bool> unregisterDevice() async {
    try {
      if (_currentUserData == null || 
          _currentUserData!['PhysicalDevice'] == null || 
          _currentUserData!['rawResponse'] == null) {
        return false;
      }
      
      final deviceId = _currentUserData!['PhysicalDevice']['DeviceId'];
      final authenticationKey = _currentUserData!['PhysicalDevice']['AuthenticationKey'];
      final sessionId = _currentUserData!['rawResponse']['SessionId'];
      
      if (deviceId == null || authenticationKey == null || sessionId == null) {
        return false;
      }
      
      final dio = Dio();
      
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
      
      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
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
      // 注销设备错误处理
    } finally {
      // 无论注销是否成功，都清除本地数据
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_reese84Key);
      await prefs.remove(_userDataKey);
      _currentUserData = null;
    }
  }
}