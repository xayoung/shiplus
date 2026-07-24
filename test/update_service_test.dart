import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiplus/services/update_service.dart';

void main() {
  test('parses the latest GitHub release response', () async {
    final dio = Dio()..httpClientAdapter = _ReleaseApiAdapter();
    final result = await UpdateService(
      dio: dio,
    ).checkForUpdates(currentVersion: '1.0.0');

    expect(result.updateAvailable, isTrue);
    expect(result.release.version, '1.1.2');
  });

  group('UpdateService version comparison', () {
    test('compares stable semantic versions', () {
      expect(UpdateService.compareVersions('1.2.0', '1.1.9'), greaterThan(0));
      expect(UpdateService.compareVersions('v1.1.2', '1.1.2+7'), 0);
      expect(UpdateService.compareVersions('1.1', '1.1.0'), 0);
    });

    test('compares pre-release versions', () {
      expect(UpdateService.compareVersions('1.2.0', '1.2.0-beta.2'), 1);
      expect(
        UpdateService.compareVersions('1.2.0-beta.10', '1.2.0-beta.2'),
        greaterThan(0),
      );
    });
  });
}

class _ReleaseApiAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({
        'tag_name': 'v1.1.2',
        'published_at': '2026-05-06T06:54:17Z',
        'body': 'Release notes',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
