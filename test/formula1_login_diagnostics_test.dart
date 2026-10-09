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
}
