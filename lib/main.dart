import 'package:flutter/material.dart';
import 'widgets/main_layout.dart';
import 'services/formula1_service.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Formula1Service, load user data from local storage
  await Formula1Service.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'M3U8 Downloader',
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
