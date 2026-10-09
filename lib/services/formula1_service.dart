import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'formula1_login_diagnostics.dart';

class Formula1Service {
  static const String _accountLoginUrl = 'https://account.formula1.com/#/login';
  static const String _reese84Key = 'formula1_reese84_token';
  static const String _userDataKey = 'formula1_user_data';
  static const String _apiKey = 'BPhVa4xbZoebPNdxRor9rouq6gzMoPyZ';
  static const String _systemId = '60a9ad84-e93d-480f-80d6-af37494f2e22';

  static String? _challengeUserAgent;

  static Future<String?> getReese84Token(BuildContext context) =>
      _prepareChallenge();

  static Future<String?> _prepareChallenge() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_reese84Key);
    _challengeUserAgent = null;
    final Completer<String?> completer = Completer<String?>();
    Timer? timeoutTimer;
    var cookieLookupStarted = false;

    final headlessWebView = HeadlessInAppWebView(
      initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
      onWebViewCreated: (controller) {
        controller.loadUrl(
          urlRequest: URLRequest(url: WebUri(_accountLoginUrl)),
        );
      },
      onLoadStop: (controller, url) async {
        if (cookieLookupStarted || completer.isCompleted) return;
        cookieLookupStarted = true;

        try {
          final userAgent = await controller.evaluateJavascript(
            source: 'navigator.userAgent',
          );
          if (userAgent is String && userAgent.isNotEmpty) {
            _challengeUserAgent = userAgent;
          }
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
      // The challenge can be set on the parent domain, not just account.
      // Deleting only the default host cookie can leave a stale token behind.
      for (final domain in [
        '.formula1.com',
        'formula1.com',
        'account.formula1.com',
        '.account.formula1.com',
      ]) {
        await CookieManager.instance().deleteCookie(
          url: WebUri(_accountLoginUrl),
          name: 'reese84',
          domain: domain,
        );
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
      await headlessWebView.dispose();
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
    String password, {
    Dio? client,
    Future<String?> Function()? prepareChallenge,
  }) async {
    try {
      var reese84Token = await getSavedReese84Token();
      if (reese84Token == null || reese84Token.isEmpty) {
        throw Exception('No authentication token available');
      }

      final uuid = const Uuid().v4();

      final dio = client ?? Dio();
      Future<Response<dynamic>> register() async {
        debugPrint('[F1TV login] RegisterDevice request started');
        try {
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
                if (_challengeUserAgent != null)
                  'User-Agent': _challengeUserAgent,
                'apikey': _apiKey,
                'CD-SystemID': _systemId,
                'Content-Type': 'application/json',
              },
            ),
          );

          debugPrint(
            Formula1LoginDiagnostics.describe(
              response.statusCode,
              response.data,
              contentType: response.headers.value('content-type'),
            ),
          );
          return response;
        } on DioException catch (e) {
          debugPrint(
            Formula1LoginDiagnostics.describe(
              e.response?.statusCode,
              e.response?.data,
              contentType: e.response?.headers.value('content-type'),
            ),
          );
          debugPrint('[F1TV login] Transport error: ${e.type.name}');
          rethrow;
        }
      }

      late final Response<dynamic> response;
      try {
        response = await register();
      } on DioException catch (e) {
        if (e.response?.statusCode != 403) rethrow;
        debugPrint('[F1TV login] HTTP 403; renewing browser challenge once');
        // Refresh the challenge once; keep the device ID stable for the retry.
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_reese84Key);
        reese84Token = await (prepareChallenge ?? _prepareChallenge)();
        if (reese84Token == null || reese84Token.isEmpty) {
          throw Exception(
            'F1TV rejected sign-in (403) and browser verification could not '
            'be renewed. Please try signing in again.',
          );
        }
        response = await register();
      }

      final responseData = Formula1LoginDiagnostics.decodeBody(response.data);
      final status = response.statusCode ?? 0;
      if (status >= 200 &&
          status < 300 &&
          responseData is Map<String, dynamic> &&
          responseData['data'] is Map &&
          responseData['data']['subscriptionToken'] is String &&
          (responseData['data']['subscriptionToken'] as String).isNotEmpty) {
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

        await _saveUserData(userData);
        return userData;
      } else {
        debugPrint(
          '[F1TV login] Response rejected: expected a successful '
          'JSON object with a non-empty data.subscriptionToken. '
          'No account data was saved.',
        );
        throw Exception(
          'Invalid F1TV login response (HTTP $status). '
          'See the [F1TV login] console log for response diagnostics',
        );
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      throw Exception(
        'F1TV login request failed'
        '${statusCode == null ? '' : ' ($statusCode)'}.'
        '${statusCode == 403 ? ' Sign-in was rejected after renewed browser verification. Please try again or check your network.' : ''}',
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
