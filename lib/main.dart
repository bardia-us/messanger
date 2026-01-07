import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/theme_manager.dart';
import 'screens/inbox_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ThemeManager())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        // تنظیم تم (تاریک/روشن)
        Brightness brightness;
        if (themeManager.themeMode == ThemeMode.system) {
          brightness = MediaQuery.platformBrightnessOf(context);
        } else {
          brightness = themeManager.themeMode == ThemeMode.dark
              ? Brightness.dark
              : Brightness.light;
        }

        return CupertinoApp(
          debugShowCheckedModeBanner: false,
          title: 'Messages Pro',
          theme: CupertinoThemeData(
            brightness: brightness,
            primaryColor: CupertinoColors.activeBlue,
            scaffoldBackgroundColor: brightness == Brightness.dark
                ? const Color(0xFF000000)
                : CupertinoColors.white,
            barBackgroundColor: brightness == Brightness.dark
                ? const Color(0xFF1E1E1E)
                : const Color(0xF0F9F9F9),
          ),
          home: const InboxScreen(),
        );
      },
    );
  }
}
