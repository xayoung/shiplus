import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiplus/services/formula1_service.dart';
import 'package:shiplus/widgets/f1_login_dialog.dart';

String _makeJwt(Map<String, dynamic> claims) {
  final header = base64Url
      .encode(utf8.encode('{"alg":"HS256"}'))
      .replaceAll('=', '');
  final payload = base64Url
      .encode(utf8.encode(jsonEncode(claims)))
      .replaceAll('=', '');
  return '$header.$payload.fixture';
}

class _Clock {
  _Clock(this.current);
  DateTime current;
  final List<Duration> delays = [];

  DateTime now() => current;

  Future<void> advance(Duration duration) async {
    delays.add(duration);
    current = current.add(duration);
  }
}

class _StubOAuthResponse {
  const _StubOAuthResponse(this.status, this.body);
  final int status;
  final Object body;
}

Dio _mockOAuthClient(
  List<RequestOptions> requests,
  List<FutureOr<_StubOAuthResponse>> responses,
) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        requests.add(options);
        if (responses.isEmpty) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.unknown,
            ),
          );
          return;
        }
        final item = await responses.removeAt(0);
        final response = Response<dynamic>(
          requestOptions: options,
          statusCode: item.status,
          data: item.body,
        );
        handler.resolve(response);
      },
    ),
  );
  return dio;
}

Map<String, String> _parseFormBody(dynamic raw) {
  final body = raw.toString();
  final result = <String, String>{};
  for (final pair in body.split('&')) {
    if (pair.isEmpty) continue;
    final idx = pair.indexOf('=');
    if (idx == -1) continue;
    final key = Uri.decodeComponent(pair.substring(0, idx));
    final value = Uri.decodeComponent(pair.substring(idx + 1));
    result[key] = value;
  }
  return result;
}

_StubOAuthResponse _challengeResponse({
  int expiresIn = 600,
  String verificationUri = 'https://f1.com/pair',
  String? verificationUriComplete,
}) {
  return _StubOAuthResponse(200, {
    'device_code': 'private-device-code',
    'user_code': 'ABCD-EFGH',
    'verification_uri': verificationUri,
    'verification_uri_complete':
        verificationUriComplete ?? '$verificationUri?user_code=ABCD-EFGH',
    'expires_in': expiresIn,
    'interval': 5,
  });
}

_StubOAuthResponse _tokenResponse(
  _Clock clock, {
  String sessionId = 'playback-session',
  String? refreshToken = 'refresh+one/token=',
  bool includeSubscriptionToken = true,
  double playbackTtlSeconds = 3600,
  double accessTtlSeconds = 3600,
  String email = '',
}) {
  final nowSec = clock.now().toUtc().millisecondsSinceEpoch / 1000.0;
  final subscription = _makeJwt({
    'SessionId': sessionId,
    'SubscriberId': '42',
    'FirstName': 'Fixture',
    'LastName': 'Account',
    if (email.isNotEmpty) 'Email': email,
    'HomeCountry': 'CH',
    'SubscriptionStatus': 'active',
    'exp': nowSec + playbackTtlSeconds,
  });
  final accessClaims = includeSubscriptionToken
      ? {'subscriptionToken': subscription}
      : {'sub': 'fixture', 'sid': 'oidc-session'};
  return _StubOAuthResponse(200, {
    'access_token': _makeJwt(accessClaims),
    'token_type': 'Bearer',
    'expires_in': accessTtlSeconds,
    if (refreshToken != null) 'refresh_token': refreshToken,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Formula1Service.clearAllData();
  });

  group('OAuth Device Authorization', () {
    test('beginDeviceSignIn uses public TV client and validates URLs', () async {
      final clock = _Clock(DateTime.utc(2026, 11, 25));
      final requests = <RequestOptions>[];
      final client = _mockOAuthClient(requests, [_challengeResponse()]);

      final auth = await Formula1Service.beginDeviceSignIn(
        client: client,
        now: clock.now,
      );

      expect(auth.userCode, 'ABCD-EFGH');
      expect(auth.deviceCode, 'private-device-code');
      expect(
        auth.verificationUriComplete.toString(),
        'https://f1.com/pair?user_code=ABCD-EFGH',
      );
      expect(auth.hasPrefilledUserCode, isTrue);
      expect(auth.expiresAt.difference(clock.now()).inSeconds, 600);

      expect(requests.length, 1);
      expect(
        requests.first.uri.toString(),
        'https://id.formula1.com/as/device_authorization',
      );
      expect(
        _parseFormBody(requests.first.data),
        {'client_id': Formula1Service.oauthClientId, 'scope': 'openid f1tv_groups'},
      );
      expect(requests.first.headers['Authorization'], isNull);
    });

    test('untrusted or insecure verification URLs are rejected', () async {
      for (final badUrl in [
        'https://formula1.com.attacker.invalid/pair',
        'http://f1.com/pair',
        'https://user@f1.com/pair',
      ]) {
        final requests = <RequestOptions>[];
        final client = _mockOAuthClient(requests, [
          _challengeResponse(verificationUri: badUrl),
        ]);
        await expectLater(
          Formula1Service.beginDeviceSignIn(client: client),
          throwsA(
            isA<DeviceSignInException>().having(
              (e) => e.type,
              'type',
              DeviceSignInErrorType.invalidResponse,
            ),
          ),
        );
      }
    });

    test('pending, slow_down, and 503 backoff honor intervals then persist session', () async {
      final clock = _Clock(DateTime.utc(2026, 11, 25));
      final requests = <RequestOptions>[];
      final client = _mockOAuthClient(requests, [
        _challengeResponse(),
        const _StubOAuthResponse(400, {'error': 'authorization_pending'}),
        const _StubOAuthResponse(400, {'error': 'slow_down'}),
        const _StubOAuthResponse(503, {'error': 'server_error'}),
        _tokenResponse(clock, email: 'driver@example.com'),
      ]);

      final auth = await Formula1Service.beginDeviceSignIn(
        client: client,
        now: clock.now,
      );
      final userData = await Formula1Service.completeDeviceSignIn(
        auth,
        client: client,
        now: clock.now,
        wait: clock.advance,
      );

      expect(
        clock.delays.map((d) => d.inSeconds).toList(),
        [5, 5, 10, 20],
      );
      expect(userData['SubscriberId'], 42);
      expect(userData['Email'], 'driver@example.com');
      expect(userData['Status'], 'active');
      expect(userData['data']['subscriptionToken'], isNotEmpty);
      expect(Formula1Service.currentSessionId, 'playback-session');

      final saved = await Formula1Service.getSavedUserData();
      expect(saved, isNotNull);
      expect(saved!['authType'], Formula1Service.oauthAuthType);
      expect(_parseFormBody(requests.last.data)['device_code'], 'private-device-code');
      expect(
        _parseFormBody(requests.last.data)['grant_type'],
        'urn:ietf:params:oauth:grant-type:device_code',
      );
    });

    test('browserApproved skips initial wait and still honors pending/slow_down', () async {
      final clock = _Clock(DateTime.utc(2026, 11, 25));
      final requests = <RequestOptions>[];
      final client = _mockOAuthClient(requests, [
        _challengeResponse(),
        const _StubOAuthResponse(400, {'error': 'authorization_pending'}),
        const _StubOAuthResponse(400, {'error': 'slow_down'}),
        _tokenResponse(clock),
      ]);

      final auth = await Formula1Service.beginDeviceSignIn(
        client: client,
        now: clock.now,
      );
      await Formula1Service.completeDeviceSignIn(
        auth,
        browserApproved: true,
        client: client,
        now: clock.now,
        wait: clock.advance,
      );

      expect(clock.delays.map((d) => d.inSeconds).toList(), [5, 10]);
    });

    test('access_denied, expired_token, and rejected stop without saving data', () async {
      for (final entry in {
        'access_denied': DeviceSignInErrorType.denied,
        'expired_token': DeviceSignInErrorType.expired,
        'invalid_client': DeviceSignInErrorType.rejected,
      }.entries) {
        final clock = _Clock(DateTime.utc(2026, 11, 25));
        final requests = <RequestOptions>[];
        final client = _mockOAuthClient(requests, [
          _challengeResponse(),
          _StubOAuthResponse(400, {'error': entry.key}),
        ]);
        final auth = await Formula1Service.beginDeviceSignIn(
          client: client,
          now: clock.now,
        );
        await expectLater(
          Formula1Service.completeDeviceSignIn(
            auth,
            client: client,
            now: clock.now,
            wait: clock.advance,
          ),
          throwsA(
            isA<DeviceSignInException>().having((e) => e.type, 'type', entry.value),
          ),
        );
        expect(await Formula1Service.getSavedUserData(), isNull);
      }
    });

    test('expired challenge stops polling at deadline', () async {
      final clock = _Clock(DateTime.utc(2026, 11, 25));
      final requests = <RequestOptions>[];
      final client = _mockOAuthClient(requests, [
        _challengeResponse(expiresIn: 10),
        const _StubOAuthResponse(400, {'error': 'authorization_pending'}),
      ]);

      final auth = await Formula1Service.beginDeviceSignIn(
        client: client,
        now: clock.now,
      );
      await expectLater(
        Formula1Service.completeDeviceSignIn(
          auth,
          client: client,
          now: clock.now,
          wait: clock.advance,
        ),
        throwsA(
          isA<DeviceSignInException>().having(
            (e) => e.type,
            'type',
            DeviceSignInErrorType.expired,
          ),
        ),
      );
      expect(requests.length, 2);
    });

    test('starting a new code cancels previous attempt polling', () async {
      final clock = _Clock(DateTime.utc(2026, 11, 25));
      final requests = <RequestOptions>[];
      final client = _mockOAuthClient(requests, [
        _challengeResponse(),
        _challengeResponse(),
      ]);

      final oldAuth = await Formula1Service.beginDeviceSignIn(
        client: client,
        now: clock.now,
      );
      await Formula1Service.beginDeviceSignIn(client: client, now: clock.now);

      await expectLater(
        Formula1Service.completeDeviceSignIn(
          oldAuth,
          client: client,
          now: clock.now,
          wait: clock.advance,
        ),
        throwsA(
          isA<DeviceSignInException>().having(
            (e) => e.type,
            'type',
            DeviceSignInErrorType.cancelled,
          ),
        ),
      );
      expect(requests.length, 2);
    });
  });

  group('Token decoding, refresh, and logout races', () {
    test('malformed and expired tokens are rejected', () {
      final clock = _Clock(DateTime.utc(2026, 11, 25));
      expect(
        () => DeviceAccountSession.decode({
          'access_token': 'opaque',
          'token_type': 'Bearer',
          'expires_in': 3600,
          'refresh_token': 'fixture',
        }, now: clock.now()),
        throwsA(isA<DeviceSignInException>()),
      );

      final expiredSub = _makeJwt({
        'SessionId': 's1',
        'SubscriberId': 42,
        'exp': (clock.now().millisecondsSinceEpoch / 1000.0) - 10,
      });
      expect(
        () => DeviceAccountSession.decode({
          'access_token': _makeJwt({'subscriptionToken': expiredSub}),
          'token_type': 'Bearer',
          'expires_in': 3600,
          'refresh_token': 'fixture',
        }, now: clock.now()),
        throwsA(
          isA<DeviceSignInException>().having(
            (e) => e.type,
            'type',
            DeviceSignInErrorType.expired,
          ),
        ),
      );
    });

    test('refresh rotates refresh token and preserves unexpired playback JWT', () async {
      final clock = _Clock(DateTime.utc(2026, 11, 25));
      final requests = <RequestOptions>[];
      final client = _mockOAuthClient(requests, [
        _challengeResponse(),
        _tokenResponse(
          clock,
          refreshToken: 'refresh+one/token=',
          playbackTtlSeconds: 345600,
          accessTtlSeconds: 3600,
        ),
        _tokenResponse(
          clock,
          refreshToken: 'rotated+token',
          includeSubscriptionToken: false,
          accessTtlSeconds: 3600,
        ),
      ]);

      final auth = await Formula1Service.beginDeviceSignIn(
        client: client,
        now: clock.now,
      );
      final initial = await Formula1Service.completeDeviceSignIn(
        auth,
        browserApproved: true,
        client: client,
        now: clock.now,
      );
      final originalSubToken = initial['data']['subscriptionToken'];

      clock.current = clock.current.add(const Duration(seconds: 3580));
      final validToken = await Formula1Service.getValidSubscriptionToken(
        client: client,
        now: clock.now,
      );

      expect(validToken, originalSubToken);
      final refreshBody = _parseFormBody(requests.last.data);
      expect(refreshBody['grant_type'], 'refresh_token');
      expect(refreshBody['refresh_token'], 'refresh+one/token=');
      expect(Formula1Service.currentUserData?['refreshToken'], 'rotated+token');
    });

    test('invalid_grant or expired playback JWT clears stale session', () async {
      final clock = _Clock(DateTime.utc(2026, 11, 25));
      final requests = <RequestOptions>[];
      final client = _mockOAuthClient(requests, [
        _challengeResponse(),
        _tokenResponse(clock, playbackTtlSeconds: 3600),
        const _StubOAuthResponse(400, {'error': 'invalid_grant'}),
      ]);

      final auth = await Formula1Service.beginDeviceSignIn(
        client: client,
        now: clock.now,
      );
      await Formula1Service.completeDeviceSignIn(
        auth,
        browserApproved: true,
        client: client,
        now: clock.now,
      );

      final refreshed = await Formula1Service.refreshToken(
        client: client,
        now: clock.now,
      );
      expect(refreshed, isNull);
      expect(Formula1Service.currentUserData, isNull);
      expect(await Formula1Service.getSavedUserData(), isNull);
    });

    test('concurrent refreshes share a single request and logout prevents resurrection', () async {
      final clock = _Clock(DateTime.utc(2026, 11, 25));
      final holdRefresh = Completer<void>();
      final requests = <RequestOptions>[];
      final client = _mockOAuthClient(requests, [
        _challengeResponse(),
        _tokenResponse(clock, playbackTtlSeconds: 10000),
        () async {
          await holdRefresh.future;
          return _tokenResponse(
            clock,
            refreshToken: 'rotated-after-logout',
            includeSubscriptionToken: false,
          );
        }(),
      ]);

      final auth = await Formula1Service.beginDeviceSignIn(
        client: client,
        now: clock.now,
      );
      await Formula1Service.completeDeviceSignIn(
        auth,
        browserApproved: true,
        client: client,
        now: clock.now,
      );

      final firstRefresh = Formula1Service.refreshToken(
        client: client,
        now: clock.now,
      );
      final secondRefresh = Formula1Service.refreshToken(
        client: client,
        now: clock.now,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        requests.where((r) => _parseFormBody(r.data)['grant_type'] == 'refresh_token').length,
        1,
      );

      await Formula1Service.clearAllData(client: client);
      holdRefresh.complete();

      expect(await firstRefresh, isNull);
      expect(await secondRefresh, isNull);
      expect(Formula1Service.currentUserData, isNull);
      expect(await Formula1Service.getSavedUserData(), isNull);
    });

    test('expired playback token during refresh clears stale session', () async {
      final clock = _Clock(DateTime.utc(2026, 11, 25));
      final requests = <RequestOptions>[];
      final client = _mockOAuthClient(requests, [
        _challengeResponse(),
        _tokenResponse(
          clock,
          playbackTtlSeconds: 3600,
          accessTtlSeconds: 3600,
        ),
        _tokenResponse(
          clock,
          refreshToken: 'rotated',
          includeSubscriptionToken: false,
          accessTtlSeconds: 3600,
        ),
      ]);

      final auth = await Formula1Service.beginDeviceSignIn(
        client: client,
        now: clock.now,
      );
      await Formula1Service.completeDeviceSignIn(
        auth,
        browserApproved: true,
        client: client,
        now: clock.now,
      );

      clock.current = clock.current.add(const Duration(seconds: 3601));
      final token = await Formula1Service.getValidSubscriptionToken(
        client: client,
        now: clock.now,
      );
      expect(token, isNull);
      expect(Formula1Service.currentUserData, isNull);
      expect(await Formula1Service.getSavedUserData(), isNull);
    });

    test('legacy PhysicalDevice session still supports refreshToken and clearAllData', () async {
      SharedPreferences.setMockInitialValues({
        'formula1_user_data': jsonEncode({
          'SessionId': 'legacy-session',
          'PhysicalDevice': {
            'DeviceId': 'dev-1-tvOS',
            'AuthenticationKey': 'auth-key-1',
          },
          'rawResponse': {'SessionId': 'legacy-session'},
          'data': {'subscriptionToken': 'legacy-sub-1'},
        }),
      });
      await Formula1Service.initialize();

      final dio = Dio();
      final requestedPaths = <String>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestedPaths.add(options.uri.path);
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'AuthenticationKey': 'auth-key-2',
                  'data': {'subscriptionToken': 'legacy-sub-2'},
                },
              ),
            );
          },
        ),
      );

      final refreshed = await Formula1Service.refreshToken(client: dio);
      expect(refreshed?['data']['subscriptionToken'], 'legacy-sub-2');
      expect(Formula1Service.currentSessionId, 'auth-key-2');
      expect(
        requestedPaths,
        ['/v2/account/subscriber/authenticate/by-device'],
      );

      await Formula1Service.clearAllData(client: dio);
      expect(
        requestedPaths,
        [
          '/v2/account/subscriber/authenticate/by-device',
          '/v1/account/Subscriber/UnregisterDevice',
        ],
      );
      expect(Formula1Service.currentUserData, isNull);
    });
  });

  group('Browser URL & script helpers', () {
    test('isBrowserCompletionUrl accepts only trusted F1 welcome fragments', () {
      for (final valid in [
        'https://account.formula1.com/#/en/tv-account-welcome',
        'https://account.formula1.com/#//tv-account-welcome?source=mac',
        'https://account.formula1.com/#/tv-account-welcome',
      ]) {
        expect(
          Formula1Service.isBrowserCompletionUrl(Uri.parse(valid)),
          isTrue,
          reason: valid,
        );
      }

      for (final invalid in [
        'http://account.formula1.com/#/en/tv-account-welcome',
        'https://account.formula1.com.attacker.invalid/#/en/tv-account-welcome',
        'https://user@account.formula1.com/#/en/tv-account-welcome',
        'https://account.formula1.com:8443/#/en/tv-account-welcome',
        'https://account.formula1.com/other#/en/tv-account-welcome',
        'https://account.formula1.com/#/en/tv-account-sync',
        'https://account.formula1.com/#/en/tv-account-welcome-attacker',
      ]) {
        expect(
          Formula1Service.isBrowserCompletionUrl(Uri.parse(invalid)),
          isFalse,
          reason: invalid,
        );
      }
    });

    test('verification and language scripts escape values and scope to main frame', () {
      final langScript = Formula1Service.buildWebsiteLanguageScript(
        languageCode: 'de',
      );
      expect(langScript, contains('window.top !== window'));
      expect(langScript, contains("location.hostname !== 'account.formula1.com'"));
      expect(langScript, contains('["de"][0]'));

      final verifyScript = Formula1Service.buildVerificationScript(
        'ABCD-EFGH',
        completionMessage: 'Completing "test" \\ done\n...',
      );
      expect(verifyScript, contains('window.top !== window'));
      expect(verifyScript, contains('tv-account-sync'));
      expect(verifyScript, contains(r'\n'));
      expect(verifyScript, contains(r'\"test\"'));
    });
  });

  group('F1LoginDialog widget', () {
    testWidgets('completes sign-in via external browser flow and returns userData', (
      tester,
    ) async {
      final openedUrls = <Uri>[];
      final completion = Completer<Map<String, dynamic>>();
      Map<String, dynamic>? dialogResult;

      final auth = DeviceAuthorization(
        deviceCode: 'device-123',
        userCode: 'WXYZ-1234',
        verificationUri: Uri.parse('https://f1.com/pair'),
        verificationUriComplete: Uri.parse(
          'https://f1.com/pair?user_code=WXYZ-1234',
        ),
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
        intervalSeconds: 5,
        attemptId: 1,
      );

      await tester.pumpWidget(
        ShadApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  dialogResult = await showDialog<Map<String, dynamic>>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => F1LoginDialog(
                      forceExternalBrowser: true,
                      beginSignIn: () async => auth,
                      completeSignIn: (
                        a, {
                        required bool browserApproved,
                        Future<void> Function(Duration)? wait,
                        bool Function()? isCancelled,
                      }) => completion.future,
                      launchExternalUrl: (url) async {
                        openedUrls.add(url);
                        return true;
                      },
                    ),
                  );
                },
                child: const Text('Open Login'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Login'));
      await tester.pump();
      await tester.pump();

      expect(find.text('WXYZ-1234'), findsOneWidget);
      expect(find.text('Open F1 Sign-In Page'), findsOneWidget);

      await tester.tap(find.text('Open F1 Sign-In Page'));
      await tester.pump();
      expect(
        openedUrls,
        [Uri.parse('https://f1.com/pair?user_code=WXYZ-1234')],
      );

      completion.complete({
        'SubscriberId': 99,
        'Status': 'active',
        'data': {'subscriptionToken': 'oauth-sub-token'},
      });
      await tester.pumpAndSettle();

      expect(dialogResult?['SubscriberId'], 99);
      expect(find.text('WXYZ-1234'), findsNothing);
    });

    testWidgets('cancelling dialog invokes cancellation and returns null', (
      tester,
    ) async {
      var cancelledObserved = false;
      final neverDone = Completer<Map<String, dynamic>>();
      Map<String, dynamic>? dialogResult = const {'sentinel': true};

      final auth = DeviceAuthorization(
        deviceCode: 'device-123',
        userCode: 'CANCEL-01',
        verificationUri: Uri.parse('https://f1.com/pair'),
        verificationUriComplete: Uri.parse(
          'https://f1.com/pair?user_code=CANCEL-01',
        ),
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
        intervalSeconds: 5,
        attemptId: 1,
      );

      await tester.pumpWidget(
        ShadApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  dialogResult = await showDialog<Map<String, dynamic>>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => F1LoginDialog(
                      forceExternalBrowser: true,
                      beginSignIn: () async => auth,
                      completeSignIn: (
                        a, {
                        required bool browserApproved,
                        Future<void> Function(Duration)? wait,
                        bool Function()? isCancelled,
                      }) async {
                        await wait?.call(const Duration(seconds: 30));
                        cancelledObserved = isCancelled?.call() ?? false;
                        return neverDone.future;
                      },
                    ),
                  );
                },
                child: const Text('Open Login'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Login'));
      await tester.pump();
      await tester.pump();

      expect(find.text('CANCEL-01'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(dialogResult, isNull);
      expect(cancelledObserved, isTrue);
    });

    testWidgets('shows failure banner and completes after New Code', (
      tester,
    ) async {
      var attempt = 0;
      Map<String, dynamic>? dialogResult;

      await tester.pumpWidget(
        ShadApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  dialogResult = await showDialog<Map<String, dynamic>>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => F1LoginDialog(
                      forceExternalBrowser: true,
                      beginSignIn: () async {
                        attempt++;
                        return DeviceAuthorization(
                          deviceCode: 'dev-$attempt',
                          userCode: 'CODE-000$attempt',
                          verificationUri: Uri.parse('https://f1.com/pair'),
                          verificationUriComplete: Uri.parse(
                            'https://f1.com/pair?user_code=CODE-000$attempt',
                          ),
                          expiresAt: DateTime.now().toUtc().add(
                            const Duration(minutes: 10),
                          ),
                          intervalSeconds: 5,
                          attemptId: attempt,
                        );
                      },
                      completeSignIn: (
                        a, {
                        required bool browserApproved,
                        Future<void> Function(Duration)? wait,
                        bool Function()? isCancelled,
                      }) async {
                        if (a.attemptId == 1) {
                          throw const DeviceSignInException(
                            DeviceSignInErrorType.expired,
                            'This sign-in code has expired.',
                          );
                        }
                        return {
                          'SubscriberId': 77,
                          'Status': 'active',
                          'data': {'subscriptionToken': 'oauth-new-code'},
                        };
                      },
                    ),
                  );
                },
                child: const Text('Open Login'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Login'));
      await tester.pump();
      await tester.pump();

      expect(find.text('This sign-in code has expired.'), findsOneWidget);
      expect(find.text('CODE-0001'), findsOneWidget);

      await tester.tap(find.text('New Code'));
      await tester.pumpAndSettle();

      expect(dialogResult?['SubscriberId'], 77);
    });
  });
}
