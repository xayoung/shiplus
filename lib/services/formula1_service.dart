import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/dio_helper.dart';
import 'formula1_login_diagnostics.dart';

enum DeviceSignInErrorType {
  expired,
  denied,
  invalidResponse,
  unavailable,
  rejected,
  cancelled,
}

class DeviceSignInException implements Exception {
  const DeviceSignInException(this.type, this.message, {this.statusCode});

  final DeviceSignInErrorType type;
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class DeviceAuthorization {
  const DeviceAuthorization({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.verificationUriComplete,
    required this.expiresAt,
    required this.intervalSeconds,
    required this.attemptId,
  });

  final String deviceCode;
  final String userCode;
  final Uri verificationUri;
  final Uri verificationUriComplete;
  final DateTime expiresAt;
  final double intervalSeconds;
  final int attemptId;

  bool get hasPrefilledUserCode =>
      verificationUriComplete.queryParameters['user_code'] == userCode;
}

class DeviceAccountSession {
  const DeviceAccountSession({
    required this.refreshToken,
    required this.expiresAt,
    required this.playbackExpiresAt,
    required this.sessionId,
    required this.subscriptionToken,
    required this.userData,
  });

  final String refreshToken;
  final DateTime expiresAt;
  final DateTime playbackExpiresAt;
  final String sessionId;
  final String subscriptionToken;
  final Map<String, dynamic> userData;

  static Map<String, dynamic>? decodeJwtClaims(String token) {
    final parts = token.split('.');
    if (parts.length != 3 || parts[0].isEmpty || parts[2].isEmpty) {
      return null;
    }
    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final parsed = jsonDecode(decoded);
      if (parsed is Map) {
        return Map<String, dynamic>.from(parsed);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static DeviceAccountSession decode(
    dynamic body, {
    DeviceAccountSession? previous,
    DateTime? now,
  }) {
    final currentTime = (now ?? DateTime.now()).toUtc();
    final decoded = Formula1LoginDiagnostics.decodeBody(body);
    if (decoded is! Map) {
      throw const DeviceSignInException(
        DeviceSignInErrorType.invalidResponse,
        'F1TV returned an invalid token response.',
      );
    }
    final map = Map<String, dynamic>.from(decoded);
    final accessToken = map['access_token'];
    final tokenType = map['token_type'];
    final expiresInRaw = map['expires_in'];
    final rawRefreshToken = map['refresh_token'];

    if (accessToken is! String ||
        accessToken.isEmpty ||
        tokenType is! String ||
        tokenType.toLowerCase() != 'bearer' ||
        expiresInRaw is! num ||
        !expiresInRaw.isFinite ||
        expiresInRaw <= 0) {
      throw const DeviceSignInException(
        DeviceSignInErrorType.invalidResponse,
        'F1TV returned an incomplete token response.',
      );
    }

    final accessClaims = decodeJwtClaims(accessToken);
    if (accessClaims == null) {
      throw const DeviceSignInException(
        DeviceSignInErrorType.invalidResponse,
        'F1TV returned a malformed access token.',
      );
    }

    final rawSubscription = accessClaims['subscriptionToken'];
    final subscriptionToken =
        (rawSubscription is String && rawSubscription.isNotEmpty)
        ? rawSubscription
        : previous?.subscriptionToken;

    if (subscriptionToken == null || subscriptionToken.isEmpty) {
      throw const DeviceSignInException(
        DeviceSignInErrorType.invalidResponse,
        'F1TV response did not include a subscription token.',
      );
    }

    final claims = decodeJwtClaims(subscriptionToken);
    if (claims == null) {
      throw const DeviceSignInException(
        DeviceSignInErrorType.invalidResponse,
        'F1TV returned a malformed subscription token.',
      );
    }

    final sessionId = claims['SessionId'];
    final expiryRaw = claims['exp'];
    final subscriberId = _parsePositiveInt(claims['SubscriberId']);
    final refreshToken =
        (rawRefreshToken is String && rawRefreshToken.isNotEmpty)
        ? rawRefreshToken
        : previous?.refreshToken;

    if (sessionId is! String ||
        sessionId.isEmpty ||
        expiryRaw is! num ||
        !expiryRaw.isFinite ||
        subscriberId == null ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      throw const DeviceSignInException(
        DeviceSignInErrorType.invalidResponse,
        'F1TV subscription token is missing required account claims.',
      );
    }

    final nowSeconds = currentTime.millisecondsSinceEpoch / 1000.0;
    if (expiryRaw <= nowSeconds) {
      throw const DeviceSignInException(
        DeviceSignInErrorType.expired,
        'Your F1TV session has expired. Please sign in again.',
      );
    }

    final playbackExpiresAt = DateTime.fromMillisecondsSinceEpoch(
      (expiryRaw * 1000).round(),
      isUtc: true,
    );
    final oauthTokenExpiry = currentTime.add(
      Duration(milliseconds: (expiresInRaw * 1000).round()),
    );
    final effectiveExpiry = oauthTokenExpiry.isBefore(playbackExpiresAt)
        ? oauthTokenExpiry
        : playbackExpiresAt;

    final firstName =
        claims['FirstName']?.toString() ??
        previous?.userData['FirstName']?.toString() ??
        '';
    final lastName =
        claims['LastName']?.toString() ??
        previous?.userData['LastName']?.toString() ??
        '';
    final email =
        claims['Email']?.toString() ??
        accessClaims['email']?.toString() ??
        previous?.userData['Email']?.toString() ??
        '';
    final homeCountry =
        claims['HomeCountry']?.toString() ??
        previous?.userData['HomeCountry']?.toString() ??
        '';
    final subscriptionStatus =
        claims['SubscriptionStatus']?.toString() ??
        previous?.userData['Status']?.toString() ??
        'Unknown';
    final subscribedProduct =
        claims['SubscribedProduct']?.toString() ??
        previous?.userData['SubscriptionInfo']?['SubscriptionName']?.toString();

    final userData = <String, dynamic>{
      'authType': Formula1Service.oauthAuthType,
      'SessionId': sessionId,
      'refreshToken': refreshToken,
      'oauthExpiresAt': effectiveExpiry.toIso8601String(),
      'playbackExpiresAt': playbackExpiresAt.toIso8601String(),
      'Email': email,
      'SubscriberId': subscriberId,
      'FirstName': firstName,
      'LastName': lastName,
      'HomeCountry': homeCountry,
      'SubscriberLanguage': claims['SubscriberLanguage']?.toString() ?? 'en-GB',
      'Status': subscriptionStatus,
      'data': <String, dynamic>{
        'subscriptionToken': subscriptionToken,
        'subscriptionStatus': subscriptionStatus,
      },
      'SubscriptionInfo': <String, dynamic>{
        'SubscriptionName':
            (subscribedProduct != null && subscribedProduct.isNotEmpty)
            ? subscribedProduct
            : 'F1 TV',
        'SubscriptionStatus': subscriptionStatus,
      },
    };

    final rawEntitlements =
        claims['Entitlements'] ?? claims['ExternalAuthorizations'];
    if (rawEntitlements is List && rawEntitlements.isNotEmpty) {
      userData['Entitlements'] = rawEntitlements;
    } else if (previous?.userData['Entitlements'] is List &&
        (previous!.userData['Entitlements'] as List).isNotEmpty) {
      userData['Entitlements'] = previous.userData['Entitlements'];
    }

    return DeviceAccountSession(
      refreshToken: refreshToken,
      expiresAt: effectiveExpiry,
      playbackExpiresAt: playbackExpiresAt,
      sessionId: sessionId,
      subscriptionToken: subscriptionToken,
      userData: userData,
    );
  }

  static DeviceAccountSession? fromSavedUserData(
    Map<String, dynamic>? userData,
  ) {
    if (userData == null ||
        userData['authType'] != Formula1Service.oauthAuthType) {
      return null;
    }
    final refreshToken = userData['refreshToken'];
    final sessionId = userData['SessionId'];
    final data = userData['data'];
    final subscriptionToken = data is Map ? data['subscriptionToken'] : null;
    final expiresAt = DateTime.tryParse(
      userData['oauthExpiresAt']?.toString() ?? '',
    )?.toUtc();
    final playbackExpiresAt = DateTime.tryParse(
      userData['playbackExpiresAt']?.toString() ?? '',
    )?.toUtc();

    if (refreshToken is! String ||
        refreshToken.isEmpty ||
        sessionId is! String ||
        sessionId.isEmpty ||
        subscriptionToken is! String ||
        subscriptionToken.isEmpty ||
        expiresAt == null ||
        playbackExpiresAt == null) {
      return null;
    }

    return DeviceAccountSession(
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      playbackExpiresAt: playbackExpiresAt,
      sessionId: sessionId,
      subscriptionToken: subscriptionToken,
      userData: Map<String, dynamic>.from(userData),
    );
  }

  static int? _parsePositiveInt(dynamic value) {
    if (value is int) {
      return value > 0 ? value : null;
    }
    if (value is num && value.isFinite && value > 0) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
  }
}

class Formula1Service {
  // Public TV OAuth client identifier published by account.formula1.com.
  static const String oauthClientId = '13c21153-f2f3-484b-a642-f2a2927e55de';
  static const String oauthScope = 'openid f1tv_groups';
  static const String oauthBaseUrl = 'https://id.formula1.com/as';
  static const String oauthAuthType = 'oauth_device';

  static const String _reese84Key = 'formula1_reese84_token';
  static const String _userDataKey = 'formula1_user_data';
  static const String _apiKey = 'BPhVa4xbZoebPNdxRor9rouq6gzMoPyZ';
  static const String _systemId = '60a9ad84-e93d-480f-80d6-af37494f2e22';
  static const String _distributionChannel =
      '40500b92-005d-4e10-972f-b41850d6125b';

  static Map<String, dynamic>? _currentUserData;
  static int _authEpoch = 0;
  static int _activeAttemptId = 0;
  static Future<Map<String, dynamic>?>? _inFlightRefresh;

  static Map<String, dynamic>? get currentUserData => _currentUserData;

  static String? get currentSessionId {
    final userData = _currentUserData;
    if (userData == null) return null;
    final direct = userData['SessionId'];
    if (direct is String && direct.isNotEmpty) return direct;
    final raw = userData['rawResponse'];
    if (raw is Map &&
        raw['SessionId'] is String &&
        (raw['SessionId'] as String).isNotEmpty) {
      return raw['SessionId'] as String;
    }
    return null;
  }

  static Future<void> initialize() async {
    try {
      final userData = await getSavedUserData();
      if (userData != null) {
        _currentUserData = userData;
      }
    } catch (_) {}
  }

  static Uri? validateVerificationUri(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme.toLowerCase() != 'https') return null;
    if (uri.userInfo.isNotEmpty) return null;
    final host = uri.host.toLowerCase();
    final isFormula1Host =
        host == 'f1.com' ||
        host.endsWith('.f1.com') ||
        host == 'formula1.com' ||
        host.endsWith('.formula1.com');
    if (!isFormula1Host) return null;
    return uri;
  }

  static bool isBrowserCompletionUrl(Uri? uri) {
    if (uri == null) return false;
    if (uri.scheme.toLowerCase() != 'https') return false;
    if (uri.host.toLowerCase() != 'account.formula1.com') return false;
    if (uri.hasPort && uri.port != 443) return false;
    if (uri.userInfo.isNotEmpty) return false;
    if (uri.path.isNotEmpty && uri.path != '/') return false;
    return RegExp(
      r'^/(?:[a-z]{2}/|/)?tv-account-welcome(?:\?.*)?$',
    ).hasMatch(uri.fragment);
  }

  static String buildWebsiteLanguageScript({String languageCode = 'en'}) {
    const supported = {'en', 'de', 'es', 'fr', 'nl', 'pt'};
    final normalized = supported.contains(languageCode) ? languageCode : 'en';
    final encoded = jsonEncode([normalized]);
    return r'''
(() => {
  if (window.top !== window) return;
  if (location.protocol !== 'https:' || location.hostname !== 'account.formula1.com') return;
  try { localStorage.setItem('user-language', JSON.stringify(__LANG__[0])); } catch (_) {}
})();
'''.replaceFirst('__LANG__', encoded);
  }

  static String buildVerificationScript(
    String userCode, {
    String completionMessage = 'Completing sign-in...',
  }) {
    final encoded = jsonEncode([userCode, completionMessage]);
    return r'''
(() => {
  if (window.top !== window) return;
  if (location.protocol !== 'https:' || location.hostname !== 'account.formula1.com') return;
  const values = __VALUES__;
  const expected = values[0].replace(/[^a-zA-Z0-9]/g, '').toUpperCase();
  let attempted = false;
  const attempt = () => {
    if (attempted || !/^#\/(?:[a-z]{2}\/|\/)?tv-account-sync(?:[?/]|$)/.test(location.hash)) return;
    const form = document.querySelector('.tv-account-sync-wrapper');
    const fields = form && Array.from(form.querySelectorAll('.otp-input'));
    const button = form && form.querySelector('.tv-account-sync');
    if (!fields || fields.length !== 8 || fields.map(field => field.value).join('').toUpperCase() !== expected ||
        !button || button.disabled || button.getAttribute('aria-disabled') === 'true') return;
    attempted = true;
    button.click();
    const status = document.createElement('p');
    status.textContent = values[1];
    status.setAttribute('role', 'status');
    status.style.visibility = 'visible';
    form.style.visibility = 'hidden';
    form.appendChild(status);
    const restore = () => { form.style.visibility = ''; status.remove(); };
    const errors = new MutationObserver(() => {
      const error = form.querySelector('.error-container');
      if (error && error.textContent.trim()) { restore(); errors.disconnect(); }
    });
    errors.observe(form, { childList: true, subtree: true, characterData: true });
    setTimeout(() => { restore(); errors.disconnect(); }, 15000);
  };
  const observer = new MutationObserver(attempt);
  observer.observe(document.documentElement, { childList: true, subtree: true });
  addEventListener('hashchange', attempt);
  const timer = setInterval(attempt, 250);
  setTimeout(() => { clearInterval(timer); observer.disconnect(); removeEventListener('hashchange', attempt); }, 600000);
  attempt();
})();
'''.replaceFirst('__VALUES__', encoded);
  }

  static String buildCompletionWatcherScript() {
    return r'''
(() => {
  if (window.top !== window) return;
  if (location.protocol !== 'https:' || location.hostname !== 'account.formula1.com') return;
  if (window.__shiplusCompletionHooked) return;
  window.__shiplusCompletionHooked = true;
  const notify = () => {
    if (/^#\/(?:[a-z]{2}\/|\/)?tv-account-welcome(?:\?.*)?$/.test(location.hash)) {
      if (window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function') {
        window.flutter_inappwebview.callHandler('f1Completion', location.href);
      }
    }
  };
  addEventListener('hashchange', notify);
  addEventListener('popstate', notify);
  const wrapHistory = (methodName) => {
    const original = history[methodName];
    if (typeof original !== 'function') return;
    history[methodName] = function() {
      const result = original.apply(this, arguments);
      notify();
      return result;
    };
  };
  wrapHistory('pushState');
  wrapHistory('replaceState');
  notify();
})();
''';
  }

  static Future<DeviceAuthorization> beginDeviceSignIn({
    Dio? client,
    DateTime Function()? now,
  }) async {
    final currentTime = (now ?? DateTime.now)();
    final attemptId = ++_activeAttemptId;
    _authEpoch++;
    _inFlightRefresh = null;

    final response = await _postOAuthForm('device_authorization', const {
      'client_id': oauthClientId,
      'scope': oauthScope,
    }, client: client);

    if (attemptId != _activeAttemptId) {
      throw const DeviceSignInException(
        DeviceSignInErrorType.cancelled,
        'Sign-in was cancelled.',
      );
    }

    if (response.statusCode != 200) {
      throw DeviceSignInException(
        DeviceSignInErrorType.unavailable,
        'F1TV sign-in service is unavailable (HTTP ${response.statusCode ?? 'unknown'}).',
        statusCode: response.statusCode,
      );
    }

    final decoded = Formula1LoginDiagnostics.decodeBody(response.data);
    if (decoded is! Map) {
      throw const DeviceSignInException(
        DeviceSignInErrorType.invalidResponse,
        'F1TV returned an invalid device authorization response.',
      );
    }

    final map = Map<String, dynamic>.from(decoded);
    final deviceCode = map['device_code'];
    final userCode = map['user_code'];
    final expiresIn = map['expires_in'];
    final intervalRaw = map['interval'] ?? 5.0;
    final verificationUri = validateVerificationUri(
      map['verification_uri']?.toString(),
    );
    final verificationUriComplete = validateVerificationUri(
      (map['verification_uri_complete'] ?? map['verification_uri'])?.toString(),
    );

    if (deviceCode is! String ||
        deviceCode.isEmpty ||
        userCode is! String ||
        userCode.isEmpty ||
        expiresIn is! num ||
        !expiresIn.isFinite ||
        expiresIn <= 0 ||
        expiresIn > 86400 ||
        intervalRaw is! num ||
        !intervalRaw.isFinite ||
        intervalRaw <= 0 ||
        verificationUri == null ||
        verificationUriComplete == null) {
      throw const DeviceSignInException(
        DeviceSignInErrorType.invalidResponse,
        'F1TV returned incomplete device pairing information.',
      );
    }

    return DeviceAuthorization(
      deviceCode: deviceCode,
      userCode: userCode,
      verificationUri: verificationUri,
      verificationUriComplete: verificationUriComplete,
      expiresAt: currentTime.toUtc().add(
        Duration(milliseconds: (expiresIn * 1000).round()),
      ),
      intervalSeconds: intervalRaw.toDouble(),
      attemptId: attemptId,
    );
  }

  static Future<Map<String, dynamic>> completeDeviceSignIn(
    DeviceAuthorization authorization, {
    bool browserApproved = false,
    Dio? client,
    DateTime Function()? now,
    Future<void> Function(Duration)? wait,
    bool Function()? isCancelled,
  }) async {
    final clock = now ?? DateTime.now;
    final sleep = wait ?? Future<void>.delayed;
    final cancelled = isCancelled ?? () => false;

    final generation = _authEpoch;
    var interval = authorization.intervalSeconds;
    var firstRequest = true;

    while (true) {
      if (cancelled() ||
          authorization.attemptId != _activeAttemptId ||
          generation != _authEpoch) {
        throw const DeviceSignInException(
          DeviceSignInErrorType.cancelled,
          'Sign-in was cancelled.',
        );
      }

      final remaining = authorization.expiresAt.difference(clock().toUtc());
      if (remaining <= Duration.zero) {
        throw const DeviceSignInException(
          DeviceSignInErrorType.expired,
          'This sign-in code has expired. Request a new code to try again.',
        );
      }

      if (!firstRequest || !browserApproved) {
        final intervalDuration = Duration(
          milliseconds: (interval * 1000).round(),
        );
        final delay = intervalDuration < remaining
            ? intervalDuration
            : remaining;
        await sleep(delay);
      }
      firstRequest = false;

      if (cancelled() ||
          authorization.attemptId != _activeAttemptId ||
          generation != _authEpoch) {
        throw const DeviceSignInException(
          DeviceSignInErrorType.cancelled,
          'Sign-in was cancelled.',
        );
      }

      if (!authorization.expiresAt.isAfter(clock().toUtc())) {
        throw const DeviceSignInException(
          DeviceSignInErrorType.expired,
          'This sign-in code has expired. Request a new code to try again.',
        );
      }

      late final _OAuthHttpResult response;
      try {
        response = await _postOAuthForm('token', {
          'client_id': oauthClientId,
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          'device_code': authorization.deviceCode,
        }, client: client);
      } on DioException catch (e) {
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          interval = math.min(interval * 2, 60.0);
          continue;
        }
        throw DeviceSignInException(
          DeviceSignInErrorType.unavailable,
          'F1TV sign-in request failed (${e.type.name}).',
        );
      }

      if (cancelled() ||
          authorization.attemptId != _activeAttemptId ||
          generation != _authEpoch) {
        throw const DeviceSignInException(
          DeviceSignInErrorType.cancelled,
          'Sign-in was cancelled.',
        );
      }

      final status = response.statusCode ?? 0;
      if (status == 200) {
        final session = DeviceAccountSession.decode(
          response.data,
          now: clock(),
        );
        if (cancelled() ||
            authorization.attemptId != _activeAttemptId ||
            generation != _authEpoch) {
          throw const DeviceSignInException(
            DeviceSignInErrorType.cancelled,
            'Sign-in was cancelled.',
          );
        }
        final nextEpoch = ++_authEpoch;
        _activeAttemptId++;
        _inFlightRefresh = null;
        await _saveUserData(session.userData);
        if (cancelled() || _authEpoch != nextEpoch) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_userDataKey);
          _currentUserData = null;
          throw const DeviceSignInException(
            DeviceSignInErrorType.cancelled,
            'Sign-in was cancelled.',
          );
        }
        _currentUserData = session.userData;
        return session.userData;
      }

      if (status >= 500) {
        interval = math.min(interval * 2, 60.0);
        continue;
      }

      switch (_extractOAuthError(response.data)) {
        case 'authorization_pending':
          continue;
        case 'slow_down':
          interval += 5.0;
          continue;
        case 'access_denied':
          throw const DeviceSignInException(
            DeviceSignInErrorType.denied,
            'Sign-in was denied in the browser.',
          );
        case 'expired_token':
          throw const DeviceSignInException(
            DeviceSignInErrorType.expired,
            'This sign-in code has expired. Request a new code to try again.',
          );
        default:
          throw DeviceSignInException(
            DeviceSignInErrorType.rejected,
            'F1TV rejected the sign-in request (HTTP $status).',
            statusCode: status,
          );
      }
    }
  }

  static Future<String?> getValidSubscriptionToken({
    Dio? client,
    DateTime Function()? now,
  }) async {
    _currentUserData ??= await getSavedUserData();
    final userData = _currentUserData;
    if (userData == null) return null;

    final session = DeviceAccountSession.fromSavedUserData(userData);
    if (session != null) {
      final currentTime = (now ?? DateTime.now)().toUtc();
      if (!session.playbackExpiresAt.isAfter(currentTime)) {
        await clearAllData(client: client);
        return null;
      }
      if (session.expiresAt.difference(currentTime) <=
          const Duration(seconds: 30)) {
        await refreshToken(client: client, now: now);
      }
    }

    final token = _currentUserData?['data']?['subscriptionToken'];
    return token is String && token.isNotEmpty ? token : null;
  }

  static Future<Map<String, dynamic>?> refreshToken({
    Dio? client,
    DateTime Function()? now,
  }) async {
    _currentUserData ??= await getSavedUserData();
    final userData = _currentUserData;
    if (userData == null) return null;

    final oauthSession = DeviceAccountSession.fromSavedUserData(userData);
    if (oauthSession != null) {
      if (_inFlightRefresh != null) {
        return await _inFlightRefresh;
      }
      final generation = _authEpoch;
      final task = _performOAuthRefresh(
        oauthSession,
        generation,
        client: client,
        now: now,
      );
      _inFlightRefresh = task;
      try {
        return await task;
      } finally {
        if (identical(_inFlightRefresh, task)) {
          _inFlightRefresh = null;
        }
      }
    }

    return _refreshLegacyDeviceToken(client: client);
  }

  static Future<Map<String, dynamic>?> _performOAuthRefresh(
    DeviceAccountSession snapshot,
    int generation, {
    Dio? client,
    DateTime Function()? now,
  }) async {
    try {
      final response = await _postOAuthForm('token', {
        'client_id': oauthClientId,
        'grant_type': 'refresh_token',
        'refresh_token': snapshot.refreshToken,
      }, client: client);

      if (_authEpoch != generation) return null;

      if (response.statusCode == 400 &&
          _extractOAuthError(response.data) == 'invalid_grant') {
        await _discardLocalSessionIfGeneration(generation);
        return null;
      }

      if (response.statusCode != 200) {
        return null;
      }

      final DeviceAccountSession renewed;
      try {
        renewed = DeviceAccountSession.decode(
          response.data,
          previous: snapshot,
          now: now?.call(),
        );
      } on DeviceSignInException catch (e) {
        if (e.type == DeviceSignInErrorType.expired) {
          await _discardLocalSessionIfGeneration(generation);
        }
        return null;
      }

      if (_authEpoch != generation) return null;

      await _saveUserData(renewed.userData);
      if (_authEpoch != generation) {
        await _discardLocalSessionIfGeneration(_authEpoch);
        return null;
      }
      _currentUserData = renewed.userData;
      return _currentUserData;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _refreshLegacyDeviceToken({
    Dio? client,
  }) async {
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

      final dio = client ?? await DioHelper.createPlainDio();
      try {
        final response = await dio.post(
          'https://api.formula1.com/v2/account/subscriber/authenticate/by-device',
          data: {
            'DistributionChannel': _distributionChannel,
            'Language': 'en-GB',
            'AuthenticationKey': authenticationKey,
            'DeviceId': deviceId,
          },
          options: Options(
            headers: {'apikey': _apiKey, 'Content-Type': 'application/json'},
          ),
        );

        if (response.statusCode == 200) {
          final responseData = Formula1LoginDiagnostics.decodeBody(
            response.data,
          );
          if (_currentUserData != null && responseData is Map) {
            if (responseData['AuthenticationKey'] != null) {
              _currentUserData!['SessionId'] =
                  responseData['AuthenticationKey'];
              _currentUserData!['PhysicalDevice']['AuthenticationKey'] =
                  responseData['AuthenticationKey'];
            }

            if (responseData['data'] != null) {
              _currentUserData!['data'] = responseData['data'];
            }

            await _saveUserData(_currentUserData!);
          }

          return _currentUserData;
        }
        return null;
      } finally {
        if (client == null) {
          dio.close();
        }
      }
    } catch (_) {
      return null;
    }
  }

  static Future<void> _discardLocalSessionIfGeneration(int generation) async {
    if (_authEpoch != generation) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userDataKey);
    await prefs.remove(_reese84Key);
    _currentUserData = null;
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

  static Future<bool> unregisterDevice({Dio? client}) async {
    try {
      if (_currentUserData == null ||
          _currentUserData!['authType'] == oauthAuthType ||
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

      final dio = client ?? await DioHelper.createPlainDio();
      try {
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

        return response.statusCode == 200;
      } finally {
        if (client == null) {
          dio.close();
        }
      }
    } catch (_) {
      return false;
    }
  }

  static Future<void> clearAllData({Dio? client}) async {
    _authEpoch++;
    _activeAttemptId++;
    _inFlightRefresh = null;

    try {
      if (_currentUserData != null &&
          _currentUserData!['authType'] != oauthAuthType) {
        await unregisterDevice(client: client);
      }
    } catch (_) {
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_reese84Key);
      await prefs.remove(_userDataKey);
      _currentUserData = null;
    }
  }

  static Future<_OAuthHttpResult> _postOAuthForm(
    String path,
    Map<String, String> values, {
    Dio? client,
  }) async {
    final dio = client ?? await DioHelper.createPlainDio();
    final encodedBody = encodeForm(values);
    debugPrint('[F1TV login] POST $oauthBaseUrl/$path started');
    try {
      final response = await dio.post<dynamic>(
        '$oauthBaseUrl/$path',
        data: encodedBody,
        options: Options(
          followRedirects: false,
          validateStatus: (_) => true,
          headers: const {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'application/json',
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
      return _OAuthHttpResult(
        statusCode: response.statusCode,
        data: response.data,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        debugPrint(
          Formula1LoginDiagnostics.describe(
            e.response?.statusCode,
            e.response?.data,
            contentType: e.response?.headers.value('content-type'),
          ),
        );
        return _OAuthHttpResult(
          statusCode: e.response?.statusCode,
          data: e.response?.data,
        );
      }
      debugPrint('[F1TV login] Transport error: ${e.type.name}');
      rethrow;
    } finally {
      if (client == null) {
        dio.close();
      }
    }
  }

  static String encodeForm(Map<String, String> values) {
    final keys = values.keys.toList()..sort();
    return keys
        .map(
          (key) =>
              '${_percentEncodeRfc3986(key)}=${_percentEncodeRfc3986(values[key]!)}',
        )
        .join('&');
  }

  static String _percentEncodeRfc3986(String input) {
    final bytes = utf8.encode(input);
    final buffer = StringBuffer();
    for (final byte in bytes) {
      final isUnreserved =
          (byte >= 0x41 && byte <= 0x5A) ||
          (byte >= 0x61 && byte <= 0x7A) ||
          (byte >= 0x30 && byte <= 0x39) ||
          byte == 0x2D ||
          byte == 0x2E ||
          byte == 0x5F ||
          byte == 0x7E;
      if (isUnreserved) {
        buffer.writeCharCode(byte);
      } else {
        buffer.write('%');
        buffer.write(byte.toRadixString(16).toUpperCase().padLeft(2, '0'));
      }
    }
    return buffer.toString();
  }

  static String? _extractOAuthError(dynamic body) {
    final decoded = Formula1LoginDiagnostics.decodeBody(body);
    if (decoded is Map && decoded['error'] is String) {
      return decoded['error'] as String;
    }
    return null;
  }
}

class _OAuthHttpResult {
  const _OAuthHttpResult({required this.statusCode, required this.data});

  final int? statusCode;
  final dynamic data;
}
