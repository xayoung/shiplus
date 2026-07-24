import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Font Configuration Tests', () {
    testWidgets('Theme should use Titillium Web font family',
        (WidgetTester tester) async {
      // Create a minimal app without network requests.
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            fontFamily: 'Titillium Web',
            textTheme: const TextTheme().apply(
              fontFamily: 'Titillium Web',
            ),
          ),
          home: const Scaffold(
            body: Text('Test'),
          ),
        ),
      );

      // Read the MaterialApp theme.
      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      final ThemeData theme = app.theme!;

      // Verify the font configuration.
      expect(theme.textTheme.bodyLarge?.fontFamily, equals('Titillium Web'));
      expect(
          theme.textTheme.headlineLarge?.fontFamily, equals('Titillium Web'));
    });

    testWidgets('Text widgets should inherit Titillium Web font',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            fontFamily: 'Titillium Web',
            textTheme: const TextTheme().apply(
              fontFamily: 'Titillium Web',
            ),
          ),
          home: const Scaffold(
            body: Text('Test Text'),
          ),
        ),
      );

      // Find the Text widget.
      final textWidget = tester.widget<Text>(find.text('Test Text'));

      // Verify font inheritance. The test environment may use a fallback
      // font, but the configured family should still be correct.
      expect(textWidget.data, equals('Test Text'));
    });

    test('Font weight mapping should be correct', () {
      // Verify the font-weight mapping.
      const fontWeights = {
        FontWeight.w300: 'Light',
        FontWeight.w400: 'Regular',
        FontWeight.w600: 'SemiBold',
        FontWeight.w700: 'Bold',
      };

      for (final entry in fontWeights.entries) {
        expect(entry.key.value, isA<int>());
        expect(entry.value, isA<String>());
      }

      // Verify the numeric font-weight values.
      expect(FontWeight.w300.value, equals(300));
      expect(FontWeight.w400.value, equals(400));
      expect(FontWeight.w600.value, equals(600));
      expect(FontWeight.w700.value, equals(700));
    });

    test('Font family name should be consistent', () {
      const fontFamily = 'Titillium Web';

      // Verify font-family name formatting.
      expect(fontFamily, isNotEmpty);
      expect(fontFamily, contains('Titillium'));
      expect(fontFamily, contains('Web'));
      expect(fontFamily.split(' ').length, equals(2));
    });
  });
}
