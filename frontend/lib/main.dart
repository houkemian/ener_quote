import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 👈 引入
import 'l10n/app_localizations.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/legal_document_page.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'app_routes.dart';
import 'package:sentry_flutter/sentry_flutter.dart'; // 🌟 新增：引入探针
import 'core/auth/token_manager.dart';


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

  final token = await TokenManager.getAccessToken();
  final isLoggedIn = token != null && token.isNotEmpty;

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
    appRunner: () => runApp(PvEssQuoteApp(isLoggedIn: isLoggedIn)), // 你的主程序放这里
  );
}


class PvEssQuoteApp extends StatelessWidget {
  final bool isLoggedIn;

  const PvEssQuoteApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: globalNavigatorKey, // 🌟 核心：把这把钥匙插进 App 的大门上！
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

      onGenerateTitle: (context) => AppLocalizations.of(context)!.appWindowTitle,
      theme: AppTheme.light(),
      home: isLoggedIn ? const DashboardScreen() : const LoginScreen(),
      routes: {
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.terms: (context) => LegalDocumentPage(
              htmlFile: 'terms.html',
              title: AppLocalizations.of(context)!.termsOfServiceTitle,
            ),
        AppRoutes.privacy: (context) => LegalDocumentPage(
              htmlFile: 'privacy.html',
              title: AppLocalizations.of(context)!.privacyPolicyTitle,
            ),
        AppRoutes.refund: (context) => LegalDocumentPage(
              htmlFile: 'refund.html',
              title: AppLocalizations.of(context)!.refundPolicyTitle,
            ),
      },
    );
  }
}
