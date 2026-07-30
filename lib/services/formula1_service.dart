import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class Formula1Service {
  static const String _accountLoginUrl = 'https://account.formula1.com/#/login';
  static const String _reese84Key = 'formula1_reese84_token';
  static const String _userDataKey = 'formula1_user_data';
  static const String _apiKey = 'BPhVa4xbZoebPNdxRor9rouq6gzMoPyZ';
  static const String _systemId = '60a9ad84-e93d-480f-80d6-af37494f2e22';

  static Future<String?> getReese84Token(BuildContext context) async {
    final Completer<String?> completer = Completer<String?>();
    Timer? timeoutTimer;
    var cookieLookupStarted = false;

    final headlessWebView = HeadlessInAppWebView(
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        userAgent:
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      ),
      onWebViewCreated: (controller) {
        controller.loadUrl(
          urlRequest: URLRequest(url: WebUri(_accountLoginUrl)),
        );
      },
      onLoadStop: (controller, url) async {
        if (cookieLookupStarted || completer.isCompleted) return;
        cookieLookupStarted = true;

        try {
          final reese84Token = await _waitForReese84Cookie();

          if (!completer.isCompleted) {
            if (reese84Token != null) {
              completer.complete(reese84Token);
            } else {
              completer.completeError(
                'Timed out waiting for the F1TV authentication token',
              );
            }
          }
        } catch (e) {
          if (!completer.isCompleted) {
            completer.completeError("Failed to get cookies: $e");
          }
        }
      },
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame == true && !completer.isCompleted) {
          completer.completeError("Failed to load page: ${error.description}");
        }
      },
    );

    try {
      try {
        await CookieManager.instance().deleteCookie(
          url: WebUri(_accountLoginUrl),
          name: 'reese84',
        );
      } catch (_) {
        // Cookie cleanup is best-effort; loading the page can still refresh it.
      }
      await headlessWebView.run();
      timeoutTimer = Timer(const Duration(seconds: 30), () {
        if (!completer.isCompleted) {
          completer.completeError('Timeout getting reese84 token');
        }
      });

      final token = await completer.future;

      if (token != null) {
        await _saveReese84Token(token);
      }

      return token;
    } catch (e) {
      return null;
    } finally {
      timeoutTimer?.cancel();
      headlessWebView.dispose();
    }
  }

  static Future<String?> _waitForReese84Cookie() async {
    final cookieManager = CookieManager.instance();
    final deadline = DateTime.now().add(const Duration(seconds: 20));

    while (DateTime.now().isBefore(deadline)) {
      try {
        final cookies = await cookieManager.getCookies(
          url: WebUri(_accountLoginUrl),
        );

        for (final cookie in cookies) {
          if (cookie.name == 'reese84' && cookie.value.isNotEmpty) {
            return cookie.value;
          }
        }
      } catch (_) {
        // The cookie store may briefly be unavailable while WebView starts.
      }

      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    return null;
  }

  static Future<void> _saveReese84Token(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reese84Key, token);
  }

  static Future<String?> getSavedReese84Token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_reese84Key);
  }

  static Map<String, dynamic>? _currentUserData;

  static Map<String, dynamic>? get currentUserData => _currentUserData;

  static Future<void> initialize() async {
    try {
      final userData = await getSavedUserData();
      if (userData != null) {
        _currentUserData = userData;

        if (userData['rawResponse'] != null) {
          final rawResponse = userData['rawResponse'];
        }
      }
    } catch (e) {}
  }

  static Future<Map<String, dynamic>?> login(
    String email,
    String password,
  ) async {
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
            'DeviceId': '$uuid-tvOS',
            'PhysicalDeviceTypeCode': 1002,
          },
        },
        options: Options(
          headers: {
            'X-D-Token': reese84Token,
            'apikey': _apiKey,
            'CD-SystemID': _systemId,
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['data'] != null) {
        final responseData = response.data;

        final Map<String, dynamic> userData = {'rawResponse': responseData};

        if (responseData['PhysicalDevice'] != null) {
          userData['PhysicalDevice'] = responseData['PhysicalDevice'];
        }

        if (responseData['RemainingDeviceAssociations'] != null) {
          userData['RemainingDeviceAssociations'] =
              responseData['RemainingDeviceAssociations'];
        }

        if (responseData['SessionSummary'] != null) {
          final sessionSummary = responseData['SessionSummary'];
          userData['Email'] = sessionSummary['Email'] ?? email;
          userData['SubscriberId'] = sessionSummary['SubscriberId'] ?? '';
          userData['FirstName'] = sessionSummary['FirstName'] ?? '';
          userData['LastName'] = sessionSummary['LastName'] ?? '';
          userData['HomeCountry'] = sessionSummary['HomeCountry'] ?? '';
          userData['SubscriberLanguage'] =
              sessionSummary['SubscriberLanguage'] ?? 'en-GB';
          userData['Title'] = sessionSummary['Title'] ?? '';

          if (sessionSummary['ExternalAuthorizations'] != null) {
            userData['ExternalAuthorizations'] =
                sessionSummary['ExternalAuthorizations'];
          }

          if (sessionSummary['TermsAndConditionsAccepted'] != null) {
            userData['TermsAndConditionsAccepted'] =
                sessionSummary['TermsAndConditionsAccepted'];
          }
        }

        if (responseData['data'] != null) {
          final data = responseData['data'];
          userData['data'] = data;
          userData['Status'] = data['subscriptionStatus'] ?? 'Unknown';
        }

        if (userData['Entitlements'] == null) {
          userData['Entitlements'] = [
            {'Name': 'PREMIUM', 'Country': userData['HomeCountry'] ?? ''},
            {'Name': 'REG', 'Country': userData['HomeCountry'] ?? ''},
          ];
        }

        if (userData['SubscriptionInfo'] == null) {
          userData['SubscriptionInfo'] = {
            'SubscriptionName': 'F1 TV Premium',
            'SubscriptionStatus': 'active',
            'ExpiryDate': DateTime.now()
                .add(const Duration(days: 30))
                .toString(),
          };
        }

        _currentUserData = userData;
        print('currentUserData: $_currentUserData');

        await _saveUserData(userData);
        return userData;
      } else {
        throw Exception('Login failed: ${response}');
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final details = e.response?.data ?? e.message;
      throw Exception(
        'F1TV login request failed'
        '${statusCode == null ? '' : ' ($statusCode)'}: $details',
      );
    } catch (e) {
      throw Exception('F1TV login failed: $e');
    }
  }

  static Future<void> _saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userDataKey, jsonEncode(userData));
  }

  static Future<Map<String, dynamic>?> getSavedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString(_userDataKey);
    if (userDataString != null) {
      return jsonDecode(userDataString) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> refreshToken() async {
    try {
      if (_currentUserData == null ||
          _currentUserData!['PhysicalDevice'] == null) {
        return null;
      }

      final authenticationKey =
          _currentUserData!['PhysicalDevice']['AuthenticationKey'];
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
          'DeviceId': deviceId,
        },
        options: Options(
          headers: {'apikey': _apiKey, 'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        if (_currentUserData != null) {
          if (responseData['AuthenticationKey'] != null) {
            _currentUserData!['SessionId'] = responseData['AuthenticationKey'];
            _currentUserData!['PhysicalDevice']['AuthenticationKey'] =
                responseData['AuthenticationKey'];
          }

          if (responseData['data'] != null) {
            _currentUserData!['data'] = responseData['data'];
          }

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

  static Future<bool> unregisterDevice() async {
    try {
      if (_currentUserData == null ||
          _currentUserData!['PhysicalDevice'] == null ||
          _currentUserData!['rawResponse'] == null) {
        return false;
      }

      final deviceId = _currentUserData!['PhysicalDevice']['DeviceId'];
      final authenticationKey =
          _currentUserData!['PhysicalDevice']['AuthenticationKey'];
      final sessionId = _currentUserData!['rawResponse']['SessionId'];

      if (deviceId == null || authenticationKey == null || sessionId == null) {
        return false;
      }

      final dio = Dio();

      final response = await dio.post(
        'https://api.formula1.com/v1/account/Subscriber/UnregisterDevice',
        data: {'DeviceId': deviceId, 'AuthenticationKey': authenticationKey},
        options: Options(
          headers: {
            'apikey': _apiKey,
            'CD-SessionID': sessionId,
            'CD-SystemID': _systemId,
            'Content-Type': 'application/json',
          },
        ),
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

  static Future<void> clearAllData() async {
    try {
      if (_currentUserData != null) {
        await unregisterDevice();
      }
    } catch (e) {
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_reese84Key);
      await prefs.remove(_userDataKey);
      _currentUserData = null;
    }
  }
}
