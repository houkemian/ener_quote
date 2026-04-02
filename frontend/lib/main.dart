import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 👈 引入
import 'l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'package:flutter/services.dart'; // 🌟 1. 引入系统服务包
import 'screens/login_screen.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart'; // 🌟 新增：引入探针


// 🌟 新增：打造一把全局路由的“万能钥匙”
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // 🌟 1. 必须加这一行：确保 Flutter 引擎准备就绪
  WidgetsFlutterBinding.ensureInitialized();

  // 🌟 2. 强制锁死为横屏！
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // 🌟 启动 Sentry 监控探针
  await SentryFlutter.init(
        (options) {
      // ⚠️ 这里填入你在 Sentry 官网免费注册后拿到的专属 DSN 链接
      options.dsn = 'https://076f74fbdfa1fe859e616b25d86a0850@o4511063897604096.ingest.us.sentry.io/4511063903174656';

      // 设置为 1.0 代表 100% 收集性能追踪数据（初期强烈建议全量收集）
      options.tracesSampleRate = 1.0;

      // 开启未捕获异常的自动记录
      options.enableAutoSessionTracking = true;
    },
    appRunner: () => runApp(const PvEssQuoteApp()), // 你的主程序放这里
  );
}


class PvEssQuoteApp extends StatelessWidget {
  const PvEssQuoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: globalNavigatorKey, // 🌟 核心：把这把钥匙插进 App 的大门上！
      title: 'Quote Master',
      debugShowCheckedModeBanner: false, // 隐藏右上角的 Debug 标签

      // 🌟 核心：挂载多语言引擎
      localizationsDelegates: const [
        AppLocalizations.delegate, // 你的语言包字典
        GlobalMaterialLocalizations.delegate, // Flutter 基础组件的多语言
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // 🌟 声明你的 App 支持哪些语言
      supportedLocales: const [
        Locale('zh'), // 中文
        Locale('en'), // 英语
        Locale('es'), // 西班牙语 (拉美备用)
        Locale('pt'), // 葡萄牙语 (巴西备用)
      ],

      theme: ThemeData(
        brightness: Brightness.dark,
        // 极客深藏青底色
        scaffoldBackgroundColor: const Color(0xFF121826),
        // 全局字体：使用 Google Fonts 的 Inter 字体，数字部分极其工整
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme,
        ).apply(bodyColor: Colors.white, displayColor: Colors.white),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676), // 全局点缀色：代表收益与能量的荧光绿
          surface: Color(0xFF1E293B), // 卡片底色
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
