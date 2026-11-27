import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shiplus/services/app_notification_service.dart';
import 'package:shiplus/widgets/play_detail_page.dart';
import 'package:shiplus/widgets/ui/app_notification_overlay.dart';

class _StubHttpResponse {
  const _StubHttpResponse({
    required this.statusCode,
    this.data,
    this.headers = const {},
  });

  final int statusCode;
  final Object? data;
  final Map<String, List<String>> headers;
}

Dio _mockDio(
  FutureOr<_StubHttpResponse> Function(RequestOptions options) handlerFn,
) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final stub = await handlerFn(options);
          final response = Response<dynamic>(
            requestOptions: options,
            statusCode: stub.statusCode,
            data: stub.data,
            headers: Headers.fromMap(stub.headers),
          );
          if (stub.statusCode >= 400) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: response,
                type: DioExceptionType.badResponse,
              ),
            );
            return;
          }
          handler.resolve(response);
        } on DioException catch (e) {
          handler.reject(e);
        } catch (e) {
          handler.reject(
            DioException(
              requestOptions: options,
              error: e,
              type: DioExceptionType.unknown,
            ),
          );
        }
      },
    ),
  );
  return dio;
}

Widget _wrapWithApp(
  Widget child, {
  ThemeMode themeMode = ThemeMode.light,
  AppNotificationService? notificationService,
}) {
  return ShadApp.custom(
    themeMode: themeMode,
    theme: ShadThemeData(
      brightness: Brightness.light,
      colorScheme: const ShadZincColorScheme.light(),
    ),
    darkTheme: ShadThemeData(
      brightness: Brightness.dark,
      colorScheme: const ShadZincColorScheme.dark(),
    ),
    appBuilder: (context) => MaterialApp(
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: ShadTheme.of(context).brightness,
        ),
      ),
      builder: (context, appChild) => ShadAppBuilder(
        child: AppNotificationOverlay(
          service: notificationService,
          child: appChild!,
        ),
      ),
      home: child,
    ),
  );
}

Map<String, dynamic> _videoDetailResponse({
  String? title = 'Bahrain Grand Prix',
  String pictureUrl = 'pic-123',
  List<Map<String, dynamic>> additionalStreams = const [],
}) {
  return {
    'resultObj': {
      'containers': [
        {
          'metadata': {
            if (title != null) 'title': title,
            'titleBrief': 'Race',
            'longDescription': 'Full race replay',
            'pictureUrl': pictureUrl,
            'additionalStreams': additionalStreams,
          },
        },
      ],
    },
  };
}

const String _sampleM3u8 = '''#EXTM3U
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="English",LANGUAGE="eng",URI="audio_eng.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=6000000,RESOLUTION=1920x1080,CODECS="avc1.64002a"
video_1080.m3u8
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AppNotificationService.instance.clear();
  });

  group('AppNotificationService', () {
    test('updates keyed notification in place without queueing behind', () {
      final service = AppNotificationService();

      service.showLoading(id: 'cover', title: 'Downloading cover...');
      expect(service.items, hasLength(1));
      final firstRevision = service.items.single.revision;

      service.showSuccess(
        id: 'cover',
        title: 'Cover saved',
        description: 'test.png',
        actionLabel: 'Open Folder',
        onAction: () {},
      );

      expect(service.items, hasLength(1));
      expect(service.items.single.type, AppNotificationType.success);
      expect(service.items.single.title, 'Cover saved');
      expect(service.items.single.revision, greaterThan(firstRevision));
    });

    test('evicts oldest notification beyond maxVisible so bar never blocks', () {
      final service = AppNotificationService();

      service.showInfo(id: 'n1', title: 'First');
      service.showInfo(id: 'n2', title: 'Second');
      service.showInfo(id: 'n3', title: 'Third');
      service.showError(id: 'n4', title: 'Fourth Error');

      expect(service.items, hasLength(AppNotificationService.maxVisible));
      expect(service.items.map((e) => e.id), ['n2', 'n3', 'n4']);
    });

    test('formatError produces concise messages and strips raw HTML', () {
      final req = RequestOptions(path: 'https://example.com');

      expect(
        AppNotificationService.formatError(
          DioException(
            requestOptions: req,
            type: DioExceptionType.connectionTimeout,
          ),
        ),
        contains('timed out'),
      );

      expect(
        AppNotificationService.formatError(
          DioException(
            requestOptions: req,
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: req,
              statusCode: 502,
              data: '<!DOCTYPE html><html><body>Bad Gateway</body></html>',
            ),
          ),
        ),
        'Server returned HTTP 502.',
      );

      expect(
        AppNotificationService.formatError(
          DioException(
            requestOptions: req,
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: req,
              statusCode: 400,
              data: {'message': 'Playback unavailable in region'},
            ),
          ),
        ),
        'HTTP 400: Playback unavailable in region',
      );
    });
  });

  group('AppNotificationOverlay', () {
    testWidgets(
      'auto-dismisses notifications with actions and does not block taps outside card',
      (tester) async {
        final service = AppNotificationService();
        var backgroundTapCount = 0;

        await tester.pumpWidget(
          _wrapWithApp(
            notificationService: service,
            Scaffold(
              body: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 20),
                  child: ElevatedButton(
                    onPressed: () => backgroundTapCount++,
                    child: const Text('Corner Button'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        service.showSuccess(
          id: 'cover_download',
          title: 'Cover saved',
          description: 'cover.jpg',
          actionLabel: 'Open Folder',
          onAction: () {},
          duration: const Duration(seconds: 3),
        );
        await tester.pump();

        expect(find.text('Cover saved'), findsOneWidget);
        expect(find.text('Open Folder'), findsOneWidget);

        // Background controls outside the centered floating card stay clickable.
        await tester.tap(find.text('Corner Button'));
        await tester.pump();
        expect(backgroundTapCount, 1);

        // Auto-dismisses even when an action button is present (unlike Flutter SnackBar persist).
        await tester.pump(const Duration(seconds: 3));
        await tester.pump();
        expect(find.text('Cover saved'), findsNothing);
      },
    );

    testWidgets('pauses auto-dismiss on hover and closes on X tap', (
      tester,
    ) async {
      final service = AppNotificationService();

      await tester.pumpWidget(
        _wrapWithApp(
          notificationService: service,
          const Scaffold(body: SizedBox.expand()),
        ),
      );
      await tester.pumpAndSettle();

      service.showError(
        id: 'err_1',
        title: 'Stream error',
        description: 'Network offline',
        duration: const Duration(seconds: 2),
      );
      await tester.pump();
      expect(find.text('Stream error'), findsOneWidget);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.text('Stream error')));
      await tester.pump();

      // Still visible past duration while hovered.
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Stream error'), findsOneWidget);

      // Clicking close button dismisses immediately.
      await tester.tap(
        find.byKey(const ValueKey('app-notification-close-err_1')),
      );
      await tester.pump();
      expect(find.text('Stream error'), findsNothing);

      await gesture.removePointer();
    });

    testWidgets('renders error notification cleanly in dark mode', (
      tester,
    ) async {
      final service = AppNotificationService();

      await tester.pumpWidget(
        _wrapWithApp(
          themeMode: ThemeMode.dark,
          notificationService: service,
          const Scaffold(body: SizedBox.expand()),
        ),
      );
      await tester.pumpAndSettle();

      service.showError(
        id: 'dark_err',
        title: 'Dark mode error',
        description: 'Something failed',
      );
      await tester.pump();

      expect(find.text('Dark mode error'), findsOneWidget);
      expect(find.text('Something failed'), findsOneWidget);
    });
  });

  group('PlayDetailPage image and video download notifications', () {
    testWidgets(
      'cover download transitions immediately from loading to saved, infers png, and reveals folder',
      (tester) async {
        final tempDir = Directory.systemTemp.createTempSync('shiplus_cover_');
        addTearDown(() {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        });

        final imageGate = Completer<_StubHttpResponse>();
        String? revealedPath;
        String? revealedFolder;

        final dio = _mockDio((options) {
          if (options.path.contains('/CONTENT/VIDEO/')) {
            return _StubHttpResponse(
              statusCode: 200,
              data: _videoDetailResponse(title: 'Monaco GP'),
            );
          }
          if (options.path.contains('/image-resizer/')) {
            return imageGate.future;
          }
          return const _StubHttpResponse(statusCode: 404);
        });

        await tester.pumpWidget(
          _wrapWithApp(
            PlayDetailPage(
              itemId: 'item-1',
              dio: dio,
              getDownloadPath: () async => tempDir.path,
              onRevealFile: (filePath, folderPath) async {
                revealedPath = filePath;
                revealedFolder = folderPath;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Download Cover'));
        await tester.pump(const Duration(milliseconds: 20));

        expect(find.text('Downloading cover image...'), findsOneWidget);

        imageGate.complete(
          const _StubHttpResponse(
            statusCode: 200,
            data: [0x89, 0x50, 0x4E, 0x47],
            headers: {
              'content-type': ['image/png'],
            },
          ),
        );
        // Let Dio timers/microtasks reach File.writeAsBytes, then flush real disk I/O.
        await tester.pump(const Duration(milliseconds: 20));
        for (var i = 0; i < 50; i++) {
          if (find.text('Cover saved').evaluate().isNotEmpty) break;
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(find.text('Cover saved'), findsOneWidget);
        await tester.pumpAndSettle();

        // Replaces loading notification immediately without waiting 2s.
        expect(find.text('Downloading cover image...'), findsNothing);
        expect(find.text('Monaco_GP_cover.png'), findsOneWidget);

        final savedFile = File(p.join(tempDir.path, 'Monaco_GP_cover.png'));
        expect(savedFile.existsSync(), isTrue);

        await tester.tap(find.text('Open Folder'));
        await tester.pumpAndSettle();

        expect(revealedPath, savedFile.path);
        expect(revealedFolder, tempDir.path);
        expect(find.text('Cover saved'), findsNothing);
      },
    );

    testWidgets(
      'navigating away during cover download delivers notification without deactivated context error',
      (tester) async {
        final tempDir = Directory.systemTemp.createTempSync('shiplus_nav_');
        addTearDown(() {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        });

        final imageGate = Completer<_StubHttpResponse>();
        final dio = _mockDio((options) {
          if (options.path.contains('/CONTENT/VIDEO/')) {
            return _StubHttpResponse(
              statusCode: 200,
              data: _videoDetailResponse(title: 'Silverstone'),
            );
          }
          if (options.path.contains('/image-resizer/')) {
            return imageGate.future;
          }
          return const _StubHttpResponse(statusCode: 404);
        });

        await tester.pumpWidget(
          _wrapWithApp(
            Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PlayDetailPage(
                          itemId: 'item-nav',
                          dio: dio,
                          getDownloadPath: () async => tempDir.path,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Detail'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Detail'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Download Cover'));
        await tester.pump();
        expect(find.text('Downloading cover image...'), findsOneWidget);

        // Leave PlayDetailPage before image download completes.
        await tester.tap(find.byIcon(LucideIcons.arrowLeft));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        imageGate.complete(
          const _StubHttpResponse(
            statusCode: 200,
            data: [1, 2, 3, 4],
            headers: {
              'content-type': ['image/jpeg'],
            },
          ),
        );
        await tester.pump(const Duration(milliseconds: 20));
        for (var i = 0; i < 50; i++) {
          if (find.text('Cover saved').evaluate().isNotEmpty) break;
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(find.text('Cover saved'), findsOneWidget);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Cover saved'), findsOneWidget);
        expect(find.text('Silverstone_cover.jpg'), findsOneWidget);
      },
    );

    testWidgets(
      'video download immediately shows sign-in error instead of blocking behind loading bar',
      (tester) async {
        final dio = _mockDio((options) {
          if (options.path.contains('/CONTENT/VIDEO/')) {
            return _StubHttpResponse(
              statusCode: 200,
              data: _videoDetailResponse(title: 'Monza GP'),
            );
          }
          return const _StubHttpResponse(statusCode: 404);
        });

        await tester.pumpWidget(
          _wrapWithApp(
            PlayDetailPage(
              itemId: 'item-2',
              dio: dio,
              getSubscriptionToken: () async => null,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Download Video'));
        await tester.pumpAndSettle();

        expect(find.text('Getting streaming information...'), findsNothing);
        expect(find.text('F1TV sign-in required'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
      },
    );

    testWidgets(
      'stream fetch unexpected error does not falsely report sign-in required',
      (tester) async {
        final dio = _mockDio((options) {
          if (options.path.contains('/CONTENT/VIDEO/')) {
            return _StubHttpResponse(
              statusCode: 200,
              data: _videoDetailResponse(title: 'Suzuka GP'),
            );
          }
          if (options.path.contains('/CONTENT/PLAY')) {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            );
          }
          return const _StubHttpResponse(statusCode: 404);
        });

        await tester.pumpWidget(
          _wrapWithApp(
            PlayDetailPage(
              itemId: 'item-3',
              dio: dio,
              getSubscriptionToken: () async => 'valid-token',
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Download Video'));
        await tester.pumpAndSettle();

        expect(find.text('F1TV sign-in required'), findsNothing);
        expect(find.text('Failed to get streaming data'), findsOneWidget);
      },
    );

    testWidgets(
      'empty laUrl does not trigger false DRM error and completes video queue notification',
      (tester) async {
        String? queuedUrl;
        String? queuedTitle;

        final dio = _mockDio((options) {
          if (options.path.contains('/CONTENT/VIDEO/')) {
            return _StubHttpResponse(
              statusCode: 200,
              data: _videoDetailResponse(title: 'Spa GP'),
            );
          }
          if (options.path.contains('/CONTENT/PLAY')) {
            return const _StubHttpResponse(
              statusCode: 200,
              data: {
                'resultObj': {
                  'url': 'https://cdn.example.com/master.m3u8',
                  'laUrl': '',
                },
              },
            );
          }
          if (options.path.contains('master.m3u8')) {
            return const _StubHttpResponse(
              statusCode: 200,
              data: _sampleM3u8,
            );
          }
          return const _StubHttpResponse(statusCode: 404);
        });

        await tester.pumpWidget(
          _wrapWithApp(
            PlayDetailPage(
              itemId: 'item-4',
              dio: dio,
              getSubscriptionToken: () async => 'valid-token',
              onAddDownloadTask: ({required url, required title}) async {
                queuedUrl = url;
                queuedTitle = title;
                return 'task-42';
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Download Video'));
        await tester.pumpAndSettle();

        // Loading toast dismissed cleanly when options dialog opens.
        expect(find.text('Content is DRM protected'), findsNothing);
        expect(find.text('Download Configuration'), findsOneWidget);

        await tester.tap(find.text('Download'));
        await tester.pumpAndSettle();

        expect(queuedUrl, 'https://cdn.example.com/master.m3u8');
        expect(queuedTitle, 'Spa GP');
        expect(find.text('Added to download queue'), findsOneWidget);
        expect(find.text('Downloads'), findsOneWidget);
      },
    );

    testWidgets(
      'm3u8 fetch failure before dialog frame does not leave loading dialog stuck',
      (tester) async {
        final dio = _mockDio((options) {
          if (options.path.contains('/CONTENT/VIDEO/')) {
            return _StubHttpResponse(
              statusCode: 200,
              data: _videoDetailResponse(title: 'Imola GP'),
            );
          }
          if (options.path.contains('/CONTENT/PLAY')) {
            return const _StubHttpResponse(
              statusCode: 200,
              data: {
                'resultObj': {
                  'url': 'https://cdn.example.com/broken.m3u8',
                  'laUrl': null,
                },
              },
            );
          }
          if (options.path.contains('broken.m3u8')) {
            return const _StubHttpResponse(statusCode: 403, data: 'Forbidden');
          }
          return const _StubHttpResponse(statusCode: 404);
        });

        await tester.pumpWidget(
          _wrapWithApp(
            PlayDetailPage(
              itemId: 'item-5',
              dio: dio,
              getSubscriptionToken: () async => 'valid-token',
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Download Video'));
        await tester.pumpAndSettle();

        expect(find.text('Loading stream options'), findsNothing);
        expect(find.text('Failed to fetch stream options'), findsOneWidget);
      },
    );

    testWidgets(
      'additional stream with null main title omits null prefix and handles non-empty DRM laUrl',
      (tester) async {
        final requests = <String>[];
        final dio = _mockDio((options) {
          requests.add(options.path);
          if (options.path.contains('/CONTENT/VIDEO/')) {
            return _StubHttpResponse(
              statusCode: 200,
              data: _videoDetailResponse(
                title: null,
                additionalStreams: [
                  {
                    'title': 'F1 Live',
                    'type': 'additional',
                    'playbackUrl': 'CONTENT/PLAY?contentId=999',
                  },
                ],
              ),
            );
          }
          if (options.path.contains('contentId=999')) {
            return const _StubHttpResponse(
              statusCode: 200,
              data: {
                'resultObj': {
                  'url': 'https://cdn.example.com/drm.m3u8',
                  'laUrl': 'https://drm.example.com/license',
                },
              },
            );
          }
          return const _StubHttpResponse(statusCode: 404);
        });

        await tester.pumpWidget(
          _wrapWithApp(
            PlayDetailPage(
              itemId: 'item-6',
              dio: dio,
              getSubscriptionToken: () async => 'valid-token',
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('F1 Live'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('F1 Live'));
        await tester.pumpAndSettle();

        expect(find.text('Content is DRM protected'), findsOneWidget);
        expect(find.textContaining('null-'), findsNothing);
      },
    );

    testWidgets(
      'cover download error strips raw HTML and replaces loading notification immediately',
      (tester) async {
        final tempDir = Directory.systemTemp.createTempSync('shiplus_err_');
        addTearDown(() {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        });

        final dio = _mockDio((options) {
          if (options.path.contains('/CONTENT/VIDEO/')) {
            return _StubHttpResponse(
              statusCode: 200,
              data: _videoDetailResponse(title: 'Austin GP'),
            );
          }
          if (options.path.contains('/image-resizer/')) {
            return const _StubHttpResponse(
              statusCode: 502,
              data: '<html><body><h1>502 Bad Gateway</h1></body></html>',
            );
          }
          return const _StubHttpResponse(statusCode: 404);
        });

        await tester.pumpWidget(
          _wrapWithApp(
            PlayDetailPage(
              itemId: 'item-7',
              dio: dio,
              getDownloadPath: () async => tempDir.path,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Download Cover'));
        await tester.pumpAndSettle();

        expect(find.text('Downloading cover image...'), findsNothing);
        expect(find.text('Cover download failed'), findsOneWidget);
        expect(find.text('Server returned HTTP 502.'), findsOneWidget);
        expect(find.textContaining('<html>'), findsNothing);
      },
    );

    testWidgets(
      '401 stream response with failed refresh shows session expired notification',
      (tester) async {
        final dio = _mockDio((options) {
          if (options.path.contains('/CONTENT/VIDEO/')) {
            return _StubHttpResponse(
              statusCode: 200,
              data: _videoDetailResponse(title: 'Interlagos GP'),
            );
          }
          if (options.path.contains('/CONTENT/PLAY')) {
            return const _StubHttpResponse(
              statusCode: 401,
              data: {'message': 'Unauthorized'},
            );
          }
          return const _StubHttpResponse(statusCode: 404);
        });

        await tester.pumpWidget(
          _wrapWithApp(
            PlayDetailPage(
              itemId: 'item-8',
              dio: dio,
              getSubscriptionToken: () async => 'stale-token',
              refreshToken: () async => null,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Download Video'));
        await tester.pumpAndSettle();

        expect(find.text('Getting streaming information...'), findsNothing);
        expect(find.text('F1TV session expired'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
      },
    );

    testWidgets(
      'simultaneous cover and video downloads update independently without blocking',
      (tester) async {
        final tempDir = Directory.systemTemp.createTempSync('shiplus_simul_');
        addTearDown(() {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        });

        final imageGate = Completer<_StubHttpResponse>();
        final dio = _mockDio((options) {
          if (options.path.contains('/CONTENT/VIDEO/')) {
            return _StubHttpResponse(
              statusCode: 200,
              data: _videoDetailResponse(title: 'Zandvoort GP'),
            );
          }
          if (options.path.contains('/image-resizer/')) {
            return imageGate.future;
          }
          if (options.path.contains('/CONTENT/PLAY')) {
            return const _StubHttpResponse(
              statusCode: 200,
              data: {
                'resultObj': {
                  'url': 'https://cdn.example.com/zandvoort.m3u8',
                  'laUrl': '',
                },
              },
            );
          }
          if (options.path.contains('zandvoort.m3u8')) {
            return const _StubHttpResponse(statusCode: 200, data: _sampleM3u8);
          }
          return const _StubHttpResponse(statusCode: 404);
        });

        await tester.pumpWidget(
          _wrapWithApp(
            PlayDetailPage(
              itemId: 'item-9',
              dio: dio,
              getSubscriptionToken: () async => 'valid-token',
              getDownloadPath: () async => tempDir.path,
              onAddDownloadTask: ({required url, required title}) async =>
                  'task-9',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Start cover download (stays in flight) and immediately download video.
        await tester.tap(find.byTooltip('Download Cover'));
        await tester.pump(const Duration(milliseconds: 20));
        expect(find.text('Downloading cover image...'), findsOneWidget);

        await tester.tap(find.text('Download Video'));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 25));
          if (find.text('Download Configuration').evaluate().isNotEmpty) break;
        }
        expect(find.text('Download Configuration'), findsOneWidget);

        await tester.tap(find.text('Download'));
        await tester.pump(const Duration(milliseconds: 20));

        // Both cover loading and video queued notifications coexist non-blockingly.
        expect(find.text('Downloading cover image...'), findsOneWidget);
        expect(find.text('Added to download queue'), findsOneWidget);

        // Now complete cover download; it updates independently to Cover saved.
        imageGate.complete(
          const _StubHttpResponse(
            statusCode: 200,
            data: [1, 2, 3],
            headers: {
              'content-type': ['image/jpeg'],
            },
          ),
        );
        await tester.pump(const Duration(milliseconds: 20));
        for (var i = 0; i < 50; i++) {
          if (find.text('Cover saved').evaluate().isNotEmpty) break;
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(find.text('Cover saved'), findsOneWidget);
        expect(find.text('Added to download queue'), findsOneWidget);
        await tester.pumpAndSettle();
      },
    );
  });
}
