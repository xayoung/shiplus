import 'package:flutter/material.dart';
import 'widgets/main_layout.dart';
import 'services/formula1_service.dart';

void main() async {
  // 确保Flutter绑定初始化
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化Formula1Service，从本地存储加载用户数据
  await Formula1Service.initialize();
  
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
