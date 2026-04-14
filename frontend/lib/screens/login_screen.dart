import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

/// 编译时注入（与后端 `.env` 中 OAuth Client 一致）：
/// `--dart-define=GOOGLE_SERVER_CLIENT_ID=xxx.apps.googleusercontent.com`
/// `--dart-define=MICROSOFT_OAUTH_CLIENT_ID=azure-application-id`
const String _kGoogleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
  defaultValue: '',
);
const String _kMicrosoftClientId = String.fromEnvironment(
  'MICROSOFT_OAUTH_CLIENT_ID',
  defaultValue: '',
);
const String _kMicrosoftRedirectUrl =
    'one.dothings.enerquote://oauth2redirect';
const String _kMicrosoftTenant = String.fromEnvironment(
  'MICROSOFT_TENANT',
  defaultValue: 'common',
);
const String _kMicrosoftDiscoveryUrl =
    'https://login.microsoftonline.com/$_kMicrosoftTenant/v2.0/.well-known/openid-configuration';

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

  final FlutterAppAuth _appAuth = const FlutterAppAuth();

  String get _googleClientId => _kGoogleServerClientId.trim();
  String get _microsoftClientId => _kMicrosoftClientId.trim();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  }

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
      final token = response.data['access_token'] as String;
      await _persistTokenAndNavigate(token);
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

  Future<void> _persistTokenAndNavigate(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final parts = token.split('.');
    if (parts.length == 3) {
      final payloadString = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final payloadMap = jsonDecode(payloadString) as Map<String, dynamic>;
      await prefs.setString('user_tier', payloadMap['tier']?.toString() ?? 'FREE');
    }
    await TokenManager.saveAccessToken(token);
    if (!mounted) return;
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  String _dioErrorMessage(DioException e, AppLocalizations l10n) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
    if (e.response?.statusCode == 401) {
      return l10n.errAuthFailed401;
    }
    return l10n.errNetwork(e.message ?? 'Unknown Error');
  }

  /// 换票接口若 404，多为线上 API 未部署 OAuth 路由（`detail` 常为 `Not Found`）。
  String _dioOAuthExchangeMessage(DioException e, AppLocalizations l10n) {
    final code = e.response?.statusCode;
    final data = e.response?.data;
    String? detail;
    if (data is Map && data['detail'] != null) {
      detail = data['detail'].toString();
    }
    final looksNotFound = code == 404 ||
        detail == 'Not Found' ||
        (detail != null && detail.toLowerCase().contains('not found'));
    if (looksNotFound) {
      return 'OAuth API not found (404). Deploy backend routes POST /auth/oauth/google and '
          '/auth/oauth/microsoft (under /api/v1), or set ApiClient baseUrl to a server that has them.';
    }
    return _dioErrorMessage(e, l10n);
  }

  String _oauthConfigHint() {
    return 'OAuth config error. '
        'Make sure GOOGLE_SERVER_CLIENT_ID and MICROSOFT_OAUTH_CLIENT_ID are passed via --dart-define.';
  }

  Future<void> _signInWithGoogle() async {
    final l10n = AppLocalizations.of(context)!;
    if (_googleClientId.isEmpty ||
        !_googleClientId.endsWith('.apps.googleusercontent.com')) {
      setState(() => _errorMessage = _oauthConfigHint());
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final google = GoogleSignIn(
        scopes: const ['email', 'openid'],
        serverClientId: _googleClientId,
      );
      await google.signOut();
      final account = await google.signIn();
      if (account == null) {
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception(
          'Google did not return id_token. Check GOOGLE_SERVER_CLIENT_ID and Android SHA-1.',
        );
      }
      final data = await ApiClient().exchangeOAuthIdToken(
        provider: 'google',
        idToken: idToken,
      );
      await _persistTokenAndNavigate(data['access_token'] as String);
    } on DioException catch (e) {
      setState(() {
        _errorMessage = _dioOAuthExchangeMessage(e, l10n);
      });
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_canceled' || e.code == 'canceled') {
        return;
      }
      final msg = (e.message ?? '').toLowerCase();
      if (msg.contains('12500') || msg.contains('developer_error')) {
        setState(() {
          _errorMessage =
              'Google Sign-In config mismatch (12500). Check Web Client ID, Android package name '
              '(one.dothings.enerquote), and SHA-1 in Google Cloud Console.';
        });
        return;
      }
      setState(() {
        _errorMessage = l10n.errSystem(e.message ?? e.toString());
      });
    } catch (e) {
      setState(() {
        _errorMessage = l10n.errSystem(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithMicrosoft() async {
    final l10n = AppLocalizations.of(context)!;
    final msId = _microsoftClientId;
    final msIdPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (msId.isEmpty || !msIdPattern.hasMatch(msId)) {
      setState(() => _errorMessage = _oauthConfigHint());
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final discoveryCandidates = <String>[
        _kMicrosoftDiscoveryUrl,
        'https://login.microsoftonline.com/consumers/v2.0/.well-known/openid-configuration',
        'https://login.microsoftonline.com/organizations/v2.0/.well-known/openid-configuration',
      ].toSet().toList();

      AuthorizationTokenResponse? result;
      Object? lastError;
      for (final discovery in discoveryCandidates) {
        try {
          result = await _appAuth.authorizeAndExchangeCode(
            AuthorizationTokenRequest(
              msId,
              _kMicrosoftRedirectUrl,
              discoveryUrl: discovery,
              scopes: const ['openid', 'profile', 'email', 'offline_access'],
              promptValues: const ['select_account'],
            ),
          );
          break;
        } catch (e) {
          lastError = e;
        }
      }

      if (result == null) {
        throw Exception(lastError?.toString() ?? 'Microsoft authorization failed');
      }
      final idToken = result.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Microsoft did not return id_token');
      }
      final data = await ApiClient().exchangeOAuthIdToken(
        provider: 'microsoft',
        idToken: idToken,
      );
      await _persistTokenAndNavigate(data['access_token'] as String);
    } on DioException catch (e) {
      setState(() {
        _errorMessage = _dioOAuthExchangeMessage(e, l10n);
      });
    } on PlatformException catch (e) {
      if (e.code == 'user_canceled' || e.code == 'canceled') {
        return;
      }
      final msg = (e.message ?? '').toLowerCase();
      if (msg.contains('client_id')) {
        setState(() {
          _errorMessage =
              'Microsoft OAuth missing/invalid client_id. Check --dart-define=MICROSOFT_OAUTH_CLIENT_ID and Azure App Registration.';
        });
        return;
      }
      if (msg.contains('invalid id token')) {
        setState(() {
          _errorMessage =
              'Microsoft returned an ID token that failed local validation. '
              'Check Azure redirect URI and account type; you can also try '
              '--dart-define=MICROSOFT_TENANT=consumers (personal) or organizations (work).';
        });
        return;
      }
      setState(() {
        _errorMessage = l10n.errSystem(e.message ?? e.toString());
      });
    } catch (e) {
      setState(() {
        _errorMessage = l10n.errSystem(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
                    'Sign in',
                    style: TextStyle(
                      fontSize: 16 * _uiScale,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 16 * _uiScale),
                Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.border.withValues(alpha: 0.6))),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12 * _uiScale),
                      child: Text(
                        l10n.dividerOr,
                        style: TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 13 * _uiScale,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: AppColors.border.withValues(alpha: 0.6))),
                  ],
                ),
                SizedBox(height: 14 * _uiScale),
                OutlinedButton(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14 * _uiScale),
                    side: BorderSide(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 22 * _uiScale,
                        child: const _GoogleLogo(),
                      ),
                      SizedBox(width: 10 * _uiScale),
                      Text(
                        l10n.loginWithGoogle,
                        style: TextStyle(fontSize: 15 * _uiScale, color: AppColors.onSurface),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10 * _uiScale),
                OutlinedButton(
                  onPressed: _isLoading ? null : _signInWithMicrosoft,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14 * _uiScale),
                    side: BorderSide(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18 * _uiScale,
                        height: 18 * _uiScale,
                        child: const _MicrosoftLogo(),
                      ),
                      SizedBox(width: 10 * _uiScale),
                      Text(
                        l10n.loginWithMicrosoft,
                        style: TextStyle(fontSize: 15 * _uiScale, color: AppColors.onSurface),
                      ),
                    ],
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
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10 * scale),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconPill(
                icon: Icons.solar_power_rounded,
                color: primary,
                scale: scale,
              ),
              Container(
                width: 20 * scale,
                height: 2,
                margin: EdgeInsets.symmetric(horizontal: 8 * scale),
                color: primary.withValues(alpha: 0.6),
              ),
              _IconPill(
                icon: Icons.battery_charging_full_rounded,
                color: primary,
                scale: scale,
              ),
              Container(
                width: 20 * scale,
                height: 2,
                margin: EdgeInsets.symmetric(horizontal: 8 * scale),
                color: primary.withValues(alpha: 0.6),
              ),
              _IconPill(
                icon: Icons.analytics_rounded,
                color: primary,
                scale: scale,
              ),
            ],
          ),
          SizedBox(height: 10 * scale),
          Text(
            'EnerQuote',
            style: TextStyle(
              fontSize: 18 * scale,
              fontWeight: FontWeight.w700,
              color: primary,
              letterSpacing: 0.4,
            ),
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

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(18, 18),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.20;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    paint.color = _red;
    canvas.drawArc(rect, -0.95, 1.35, false, paint);
    paint.color = _yellow;
    canvas.drawArc(rect, 0.42, 1.00, false, paint);
    paint.color = _green;
    canvas.drawArc(rect, 1.48, 1.18, false, paint);
    paint.color = _blue;
    canvas.drawArc(rect, 2.68, 2.64, false, paint);

    // "G" 横杠
    final barPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = _blue;
    final y = size.height * 0.50;
    canvas.drawLine(
      Offset(size.width * 0.50, y),
      Offset(size.width * 0.90, y),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MicrosoftLogo extends StatelessWidget {
  const _MicrosoftLogo();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(18, 18),
      painter: _MicrosoftLogoPainter(),
    );
  }
}

class _MicrosoftLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gap = size.width * 0.08;
    final tile = (size.width - gap) / 2;

    final paints = [
      Paint()..color = const Color(0xFFF25022),
      Paint()..color = const Color(0xFF7FBA00),
      Paint()..color = const Color(0xFF00A4EF),
      Paint()..color = const Color(0xFFFFB900),
    ];

    canvas.drawRect(Rect.fromLTWH(0, 0, tile, tile), paints[0]);
    canvas.drawRect(Rect.fromLTWH(tile + gap, 0, tile, tile), paints[1]);
    canvas.drawRect(Rect.fromLTWH(0, tile + gap, tile, tile), paints[2]);
    canvas.drawRect(Rect.fromLTWH(tile + gap, tile + gap, tile, tile), paints[3]);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}