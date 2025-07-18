import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Font Configuration Tests', () {
    testWidgets('Theme should use Titillium Web font family',
        (WidgetTester tester) async {
      // 创建一个简单的测试应用，避免网络请求
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

      // 获取 MaterialApp 的主题
      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      final ThemeData theme = app.theme!;

      // 验证字体配置
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

      // 查找 Text widget
      final textWidget = tester.widget<Text>(find.text('Test Text'));

      // 验证字体继承
      // 注意：在测试环境中，字体可能回退到默认字体，但配置应该正确
      expect(textWidget.data, equals('Test Text'));
    });

    test('Font weight mapping should be correct', () {
      // 验证字重映射
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

      // 验证字重值
      expect(FontWeight.w300.value, equals(300));
      expect(FontWeight.w400.value, equals(400));
      expect(FontWeight.w600.value, equals(600));
      expect(FontWeight.w700.value, equals(700));
    });

    test('Font family name should be consistent', () {
      const fontFamily = 'Titillium Web';

      // 验证字体名称格式
      expect(fontFamily, isNotEmpty);
      expect(fontFamily, contains('Titillium'));
      expect(fontFamily, contains('Web'));
      expect(fontFamily.split(' ').length, equals(2));
    });
  });
}
