// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiplus/main.dart';

void main() {
  testWidgets('Material pages have a ScaffoldMessenger ancestor', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(home: _SnackBarProbe()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Show message'));
    await tester.pump();

    expect(find.text('Download started'), findsOneWidget);
  });
}

class _SnackBarProbe extends StatelessWidget {
  const _SnackBarProbe();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Download started')));
          },
          child: const Text('Show message'),
        ),
      ),
    );
  }
}
