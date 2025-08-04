import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_process/UserAccount/login_page.dart';
import 'package:image_process/home_page.dart';
import 'package:image_process/pages/all_image_page.dart';
import 'package:image_process/tools/system_set.dart';
import 'package:image_process/user_session.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 仅在非 Web 环境（Windows/macOS/Linux）下初始化窗口管理
  if (!kIsWeb && Platform.isWindows) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = WindowOptions(
      minimumSize: Size(1400, 850),
      center: true,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  await UserSession().loadFromPrefs();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 58, 143, 183),
        ),
        fontFamily: 'YeHei',
      ),
      home: isLogin() ? const HomePage() : const LoginPage(),
      routes: {
        '/home': (context) => const HomePage(),
        '/login': (context) => LoginPage(),
        '/systemSet': (context) => SystemSet(),
        '/allImage':(context)=>AllImagePage(),
      },
    );
  }

  bool isLogin() {
    if (UserSession().token != null) {
      return true;
    } else {
      return false;
    }
  }
}
