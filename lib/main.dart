import 'package:flutter/material.dart';
import 'widgets/main_layout.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'M3U8下载器',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'Titillium Web',
        textTheme: const TextTheme().apply(
          fontFamily: 'Titillium Web',
        ),
      ),
      home: const MainLayout(),
    );
  }
}
