import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiplus/services/formula1_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'formula1_reese84_token': 'stale-challenge',
    });
  });

  Dio transport(
    List<RequestOptions> requests,
    List<int> statuses, {
    Object? body,
  }) {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          final status = statuses[requests.length - 1];
          final response = Response<dynamic>(
            requestOptions: request,
            statusCode: status,
            data:
                body ??
                (status == 200
                    ? {
                        'data': {'subscriptionToken': 'test-token'},
                      }
                    : 'sensitive server response'),
          );
          if (status >= 200 && status < 300) {
            handler.resolve(response);
          } else {
            handler.reject(
              DioException(
                requestOptions: request,
                response: response,
                type: DioExceptionType.badResponse,
              ),
            );
          }
        },
      ),
    );
    return dio;
  }

  test('accepts JSON text with a successful non-200 status', () async {
    final requests = <RequestOptions>[];
    final result = await Formula1Service.login(
      'test@example.com',
      'password',
      client: transport(
        requests,
        [201],
        body: jsonEncode({
          'data': {'subscriptionToken': 'test-token'},
        }),
      ),
    );
    expect(result?['data']['subscriptionToken'], 'test-token');
  });

  test(
    'HTTP 200 business error is rejected without saving account data',
    () async {
      final requests = <RequestOptions>[];
      await expectLater(
        Formula1Service.login(
          'test@example.com',
          'password',
          client: transport(requests, [200], body: {'ResponseCode': 117}),
        ),
        throwsA(predicate((Object e) => e.toString().contains('HTTP 200'))),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('formula1_user_data'), isNull);
      expect(requests.length, 1);
    },
  );

  test('403 renews challenge once and retries the same device', () async {
    final requests = <RequestOptions>[];
    var renewals = 0;
    final result = await Formula1Service.login(
      'test@example.com',
      'password',
      client: transport(requests, [403, 200]),
      prepareChallenge: () async {
        renewals++;
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('formula1_reese84_token'), isNull);
        return 'fresh-challenge';
      },
    );
    expect(result?['data']['subscriptionToken'], 'test-token');
    expect(renewals, 1);
    expect(requests[0].headers['X-D-Token'], 'stale-challenge');
    expect(requests[1].headers['X-D-Token'], 'fresh-challenge');
    expect(
      requests[0].data['PhysicalDevice'],
      requests[1].data['PhysicalDevice'],
    );
  });

  for (final statuses in [
    [403, 403],
    [401],
  ]) {
    test('$statuses stops without leaking response details', () async {
      final requests = <RequestOptions>[];
      var renewals = 0;
      await expectLater(
        Formula1Service.login(
          'test@example.com',
          'password',
          client: transport(requests, statuses),
          prepareChallenge: () async {
            renewals++;
            return 'fresh-challenge';
          },
        ),
        throwsA(
          predicate(
            (Object e) =>
                e.toString().contains('${statuses.last}') &&
                !e.toString().contains('sensitive server response'),
          ),
        ),
      );
      expect(requests.length, statuses.length);
      expect(renewals, statuses.length - 1);
    });
  }

  test('failed challenge renewal does not repeat the login request', () async {
    final requests = <RequestOptions>[];
    await expectLater(
      Formula1Service.login(
        'test@example.com',
        'password',
        client: transport(requests, [403]),
        prepareChallenge: () async => null,
      ),
      throwsA(
        predicate((Object e) => e.toString().contains('could not be renewed')),
      ),
    );
    expect(requests.length, 1);
  });
}
