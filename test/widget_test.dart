// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:shiplus/main.dart';

void main() {
  testWidgets('App starts and shows navigation', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app starts with the main layout
    expect(find.text('shiplus'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('Can navigate to download page', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Find and tap the download navigation item
    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();

    // Verify that we're on the download page
    expect(find.text('下载管理'), findsOneWidget);
    expect(find.text('暂无下载任务'), findsOneWidget);
  });
}
