import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiplus/services/formula1_login_diagnostics.dart';

void main() {
  test(
    'diagnostics retain error codes and hide account and session values',
    () {
      final log = Formula1LoginDiagnostics.describe(200, {
        'ResponseCode': 117,
        'Password': 'password-secret',
        'SessionSummary': {
          'Email': 'private@example.com',
          'SubscriberId': 987654,
        },
        'PhysicalDevice': {'AuthenticationKey': 'device-secret'},
        'data': {'subscriptionToken': 'token-secret'},
        'Message': 'private@example.com password-secret',
      }, contentType: 'application/json');
      expect(log, contains('HTTP 200'));
      expect(log, contains('"ResponseCode":"117"'));
      expect(log, contains('subscriptionToken'));
      for (final secret in [
        'password-secret',
        'private@example.com',
        '987654',
        'device-secret',
        'token-secret',
      ]) {
        expect(log, isNot(contains(secret)));
      }
    },
  );

  test('JSON text is decoded before redaction', () {
    final log = Formula1LoginDiagnostics.describe(
      200,
      jsonEncode({
        'ErrorCode': 'INVALID_CREDENTIALS',
        'Login': 'private@example.com',
      }),
    );
    expect(log, contains('body=object'));
    expect(log, contains('INVALID_CREDENTIALS'));
    expect(log, isNot(contains('private@example.com')));
  });

  test('HTML and empty responses are safe to log', () {
    final log = Formula1LoginDiagnostics.describe(
      200,
      '<html>secret-cookie</html>',
    );
    expect(log, contains('body=text'));
    expect(log, isNot(contains('secret-cookie')));
    expect(
      Formula1LoginDiagnostics.describe(204, null),
      contains('body=empty'),
    );
  });

  test('OAuth responses retain error codes and hide tokens and device codes', () {
    final pendingLog = Formula1LoginDiagnostics.describe(400, {
      'error': 'authorization_pending',
      'error_description': 'Waiting for user code ABCD-EFGH',
    });
    expect(pendingLog, contains('"error":"authorization_pending"'));
    expect(pendingLog, isNot(contains('ABCD-EFGH')));

    final tokenLog = Formula1LoginDiagnostics.describe(200, {
      'access_token': 'jwt-access-secret',
      'refresh_token': 'jwt-refresh-secret',
      'device_code': 'device-code-secret',
      'token_type': 'Bearer',
      'expires_in': 3600,
    });
    expect(tokenLog, contains('HTTP 200'));
    for (final secret in [
      'jwt-access-secret',
      'jwt-refresh-secret',
      'device-code-secret',
    ]) {
      expect(tokenLog, isNot(contains(secret)));
    }
  });
}
