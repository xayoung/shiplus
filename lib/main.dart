import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
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
  const MyApp({super.key, this.home = const MainLayout()});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return ShadApp.custom(
      themeMode: ThemeMode.system,
      theme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadZincColorScheme.light(),
        textTheme: ShadTextTheme(family: 'Titillium Web'),
      ),
      darkTheme: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadZincColorScheme.dark(),
        textTheme: ShadTextTheme(family: 'Titillium Web'),
      ),
      appBuilder: (context) {
        final shad = ShadTheme.of(context);
        final materialTheme = Theme.of(context).copyWith(
          scaffoldBackgroundColor: shad.colorScheme.background,
          canvasColor: shad.colorScheme.background,
          dividerColor: shad.colorScheme.border,
          cardTheme: CardThemeData(
            elevation: 0,
            color: shad.colorScheme.card,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: shad.radius,
              side: BorderSide(color: shad.colorScheme.border),
            ),
          ),
          appBarTheme: AppBarTheme(
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            backgroundColor: shad.colorScheme.background,
            foregroundColor: shad.colorScheme.foreground,
            surfaceTintColor: Colors.transparent,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: shad.colorScheme.background,
            border: OutlineInputBorder(
              borderRadius: shad.radius,
              borderSide: BorderSide(color: shad.colorScheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: shad.radius,
              borderSide: BorderSide(color: shad.colorScheme.border),
            ),
          ),
        );
        return MaterialApp(
          title: 'shiplus',
          debugShowCheckedModeBanner: false,
          theme: materialTheme,
          localizationsDelegates: const [GlobalShadLocalizations.delegate],
          supportedLocales: const [Locale('en', 'US')],
          builder: (context, child) => ShadAppBuilder(child: child!),
          home: home,
        );
      },
    );
  }
}
