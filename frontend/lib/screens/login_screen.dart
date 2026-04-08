import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/auth/token_manager.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
// 🌟 引入多语言引擎
import '../l10n/app_localizations.dart';
import 'dashboard_screen.dart'; // 引入你的测算主页
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/marketing_footer.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController(
    text: '',
  );
  final TextEditingController _passwordController = TextEditingController(
    text: '',
  );
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final l10n = AppLocalizations.of(context)!;


    try {
      // 🌟 极致瘦身：不再需要写完整的 URL，不再需要手动处理 header！
      final response = await ApiClient().dio.post(
        '/auth/login', // 直接写路由短地址即可
        data: {
          'username': _emailController.text,
          'password': _passwordController.text,
        },
        // 告诉 Dio 我们发的是表单格式 (FastAPI 登录强依赖这个)
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );


      // Dio 的 response.statusCode 正常是 200，且 response.data 已经是解析好的 Map 了！不需要再 jsonDecode
      final token = response.data['access_token'];
      final prefs = await SharedPreferences.getInstance();

      // 🌟 核心：手动拆解 JWT，提取后端发给我们的 tier 权限！
      final parts = token.split('.');
      if (parts.length == 3) {
        // 补充 Base64 缺少的 '=' 补位，否则 Dart 会报错
        final payloadString = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
        final payloadMap = jsonDecode(payloadString);

        // 把权限等级和公司 ID 存入本地缓存
        await prefs.setString('user_tier', payloadMap['tier'] ?? 'FREE');
        print("🎉 登录成功！当前用户权限: ${payloadMap['tier']}");
      }

      await TokenManager.saveAccessToken(token);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } on DioException catch (e) {
      // Dio 捕获异常更优雅
      setState(() {
        if (e.response?.statusCode == 401) {
          _errorMessage = l10n.errAuthFailed401;
        } else {
          _errorMessage = l10n.errNetwork(e.message ?? 'Unknown Error');
        }
      });
    } catch (e) {
      // 捕获极其罕见的未知错误
      setState(() {
        _errorMessage = l10n.errSystem(e.toString());
      });
    } finally {
      // 增加 mounted 判断，防止组件被替换后还执行 setState
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 在 build 方法里召唤多语言字典
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                const _EnergyHeroIcon(),
                // const SizedBox(height: 5),
                // const Text(
                //   '光储大师 V1.0',
                // ... (保留你的注释)
                const SizedBox(height: 28),

                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: AppColors.onSurface),
                  decoration: InputDecoration(
                    labelText: l10n.emailLabel, // 🌟 动态多语言替换
                    hintText: l10n.emailPlaceholder,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: AppColors.onSurface),
                  decoration: InputDecoration(
                    labelText: l10n.passwordLabel, // 🌟 动态多语言替换
                  ),
                ),
                const SizedBox(height: 12),
                if (_errorMessage.isNotEmpty)
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Text(
                    l10n.secureLoginBtn, // 🌟 动态多语言替换
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16), // 👈 原有按钮下面的间距


                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()));
                  },
                  child: Text(l10n.forgotPasswordTitle, style: TextStyle(color: AppColors.onSurfaceVariant)),

                ),

                // 🌟 新增的注册入口按钮
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                  child: Text(
                    l10n.registerPrompt, // 🌟 动态多语言替换
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const MarketingFooter(),
        ],
      ),
    );
  }
}

class _EnergyHeroIcon extends StatelessWidget {
  const _EnergyHeroIcon();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primary.withValues(alpha: 0.14),
                    primary.withValues(alpha: 0.03),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconPill(
                icon: Icons.solar_power_rounded,
                color: primary,
              ),
              Container(
                width: 28,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: primary.withValues(alpha: 0.6),
              ),
              _IconPill(
                icon: Icons.battery_charging_full_rounded,
                color: primary,
              ),
              Container(
                width: 28,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: primary.withValues(alpha: 0.6),
              ),
              _IconPill(
                icon: Icons.analytics_rounded,
                color: primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconPill({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Icon(icon, size: 28, color: color),
    );
  }
}