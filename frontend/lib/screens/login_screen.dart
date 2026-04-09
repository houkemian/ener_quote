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
  static const double _uiScale = 0.8;
  final TextEditingController _emailController = TextEditingController(
    text: '',
  );
  final TextEditingController _passwordController = TextEditingController(
    text: '',
  );
  bool _isLoading = false;
  String _errorMessage = '';

  bool _isValidEmail(String value) {
    final email = value.trim();
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(email);
  }

  Future<void> _login() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = l10n.errEmpty;
      });
      return;
    }

    if (!_isValidEmail(email)) {
      setState(() {
        _errorMessage = l10n.errInvalidEmail;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });


    try {
      // 🌟 极致瘦身：不再需要写完整的 URL，不再需要手动处理 header！
      final response = await ApiClient().dio.post(
        '/auth/login', // 直接写路由短地址即可
        data: {
          'username': email,
          'password': password,
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
                  padding: EdgeInsets.symmetric(
                    horizontal: 32.0 * _uiScale,
                    vertical: 24.0 * _uiScale,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                const _EnergyHeroIcon(scale: _uiScale),
                // const SizedBox(height: 5),
                // const Text(
                //   '光储大师 V1.0',
                // ... (保留你的注释)
                SizedBox(height: 28 * _uiScale),

                TextField(
                  controller: _emailController,
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 16 * _uiScale,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.emailLabel, // 🌟 动态多语言替换
                    hintText: l10n.emailPlaceholder,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12 * _uiScale,
                      vertical: 14 * _uiScale,
                    ),
                    labelStyle: TextStyle(fontSize: 14 * _uiScale),
                    hintStyle: TextStyle(fontSize: 14 * _uiScale),
                  ),
                ),
                SizedBox(height: 16 * _uiScale),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 16 * _uiScale,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.passwordLabel, // 🌟 动态多语言替换
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12 * _uiScale,
                      vertical: 14 * _uiScale,
                    ),
                    labelStyle: TextStyle(fontSize: 14 * _uiScale),
                  ),
                ),
                SizedBox(height: 12 * _uiScale),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _errorMessage.isNotEmpty
                          ? Text(
                              _errorMessage,
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 14 * _uiScale,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
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
                          fontSize: 14 * _uiScale,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8 * _uiScale),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16 * _uiScale),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8 * _uiScale),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                    height: 20 * _uiScale,
                    width: 20 * _uiScale,
                    child: CircularProgressIndicator(strokeWidth: 2 * _uiScale),
                  )
                      : Text(
                    l10n.secureLoginBtn, // 🌟 动态多语言替换
                    style: TextStyle(
                      fontSize: 16 * _uiScale,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 16 * _uiScale), // 👈 原有按钮下面的间距


                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()));
                  },
                  child: Text(
                    l10n.forgotPasswordTitle,
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 14 * _uiScale,
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
  final double scale;

  const _EnergyHeroIcon({this.scale = 1});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 80 * scale,
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
                scale: scale,
              ),
              Container(
                width: 28 * scale,
                height: 2,
                margin: EdgeInsets.symmetric(horizontal: 10 * scale),
                color: primary.withValues(alpha: 0.6),
              ),
              _IconPill(
                icon: Icons.battery_charging_full_rounded,
                color: primary,
                scale: scale,
              ),
              Container(
                width: 28 * scale,
                height: 2,
                margin: EdgeInsets.symmetric(horizontal: 10 * scale),
                color: primary.withValues(alpha: 0.6),
              ),
              _IconPill(
                icon: Icons.analytics_rounded,
                color: primary,
                scale: scale,
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
  final double scale;

  const _IconPill({required this.icon, required this.color, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52 * scale,
      height: 52 * scale,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14 * scale),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Icon(icon, size: 28 * scale, color: color),
    );
  }
}