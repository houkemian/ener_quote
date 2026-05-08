import 'dart:async';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/network/api_client.dart';
import '../core/auth/token_manager.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
// 🌟 引入多语言引擎
import '../l10n/app_localizations.dart';
import 'project_list_screen.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/marketing_footer.dart';
import '../core/billing/revenuecat_service.dart';

const String _kGoogleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
  defaultValue: '',
);
const String _kMicrosoftFirebaseProviderId = String.fromEnvironment(
  'MICROSOFT_FIREBASE_PROVIDER_ID',
  defaultValue: 'microsoft.com',
);

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

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  String get _googleClientId => _kGoogleServerClientId.trim();

  /// Android: [android/app/build.gradle.kts] injects `default_web_client_id` from
  /// `GOOGLE_SERVER_CLIENT_ID` in [android/gradle.properties]; `serverClientId` may be null so
  /// the plugin uses that string. Other platforms need `--dart-define=GOOGLE_SERVER_CLIENT_ID`.
  bool get _googleServerClientIdFromGradle =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get _hasGoogleSignInClientId {
    if (_googleClientId.isNotEmpty) {
      return _googleClientId.endsWith('.apps.googleusercontent.com');
    }
    return _googleServerClientIdFromGradle;
  }

  /// Web client ID for [GoogleSignIn]; null on Android when using Gradle `resValue` only.
  String? get _googleServerClientIdForPlugin =>
      _googleClientId.isNotEmpty ? _googleClientId : null;

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
      // 走 Firebase Auth：邮箱密码 → ID token → 后端 /auth/firebase 同步用户
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(code: 'user-not-found');
      }

      // 后端 /auth/firebase 强制要求 email_verified=true，未验证就拦截在这里。
      if (!user.emailVerified) {
        await _firebaseAuth.signOut();
        setState(() {
          _errorMessage = l10n.errEmailNotVerified;
        });
        return;
      }

      final firebaseToken = await user.getIdToken();
      if (firebaseToken == null || firebaseToken.isEmpty) {
        throw Exception('Firebase did not return ID token');
      }

      final data = await ApiClient().authenticateWithFirebaseIdToken(
        firebaseIdToken: firebaseToken,
      );
      await _persistTokenAndNavigate(
        firebaseToken,
        tierHint: data['tier']?.toString(),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _firebaseAuthErrorMessage(e, l10n);
      });
    } on DioException catch (e) {
      setState(() {
        _errorMessage = _dioOAuthExchangeMessage(e, l10n);
      });
    } catch (e) {
      setState(() {
        _errorMessage = l10n.errSystem(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _firebaseAuthErrorMessage(
    FirebaseAuthException e,
    AppLocalizations l10n,
  ) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'user-disabled':
      case 'invalid-login-credentials':
        return l10n.errAuthFailed401;
      case 'invalid-email':
        return l10n.errInvalidEmail;
      case 'too-many-requests':
        return l10n.errSystem(
          'Too many sign-in attempts. Please wait a moment before retrying.',
        );
      case 'network-request-failed':
        return l10n.errNetwork(e.message ?? 'network-request-failed');
      default:
        return l10n.errSystem('${e.code}: ${e.message ?? ''}');
    }
  }

  Future<void> _persistTokenAndNavigate(String token, {String? tierHint}) async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = _firebaseAuth.currentUser?.uid;
    await prefs.setString('user_tier', tierHint ?? 'FREE');
    await TokenManager.saveAccessToken(token);
    await RevenueCatService.initializeFromJwt(token);
    if (userId != null && userId.isNotEmpty) {
      await RevenueCatService.initializeForAppUser(userId);
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ProjectListScreen()),
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

  /// Firebase 登录同步接口若 404，多为线上 API 未部署 `/auth/firebase`。
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
      return 'Firebase auth API not found (404). Deploy backend route POST /auth/firebase '
          '(under /api/v1), or set ApiClient baseUrl to a server that has it.';
    }
    return _dioErrorMessage(e, l10n);
  }

  Future<void> _signInWithGoogle() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_hasGoogleSignInClientId) {
      setState(() => _errorMessage = l10n.errOAuthNotConfigured);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final google = GoogleSignIn(
        scopes: const ['email', 'openid'],
        serverClientId: _googleServerClientIdForPlugin,
      );
      final account = await google.signIn();
      if (account == null) {
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception(
          'Google did not return id_token.',
        );
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final authResult = await _firebaseAuth.signInWithCredential(credential);
      final firebaseToken = await authResult.user?.getIdToken();
      if (firebaseToken == null || firebaseToken.isEmpty) {
        throw Exception('Firebase did not return ID token');
      }
      final data = await ApiClient().authenticateWithFirebaseIdToken(
        firebaseIdToken: firebaseToken,
      );
      await _persistTokenAndNavigate(
        firebaseToken,
        tierHint: data['tier']?.toString(),
      );
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
          _errorMessage = l10n.errGoogleSignIn12500;
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
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final providerId = _kMicrosoftFirebaseProviderId.trim().isNotEmpty
          ? _kMicrosoftFirebaseProviderId.trim()
          : 'microsoft.com';
      debugPrint('[MS-Firebase] start sign-in, providerId=$providerId');
      final microsoftProvider = OAuthProvider(providerId)
        ..setScopes(const ['openid', 'profile', 'email']);
      UserCredential authResult;
      if (kIsWeb) {
        authResult = await _firebaseAuth
            .signInWithPopup(microsoftProvider)
            .timeout(const Duration(seconds: 60));
      } else {
        authResult = await _firebaseAuth
            .signInWithProvider(microsoftProvider)
            .timeout(const Duration(seconds: 60));
      }
      debugPrint('[MS-Firebase] provider returned, resolving Firebase token');
      final firebaseToken = await authResult.user?.getIdToken();
      if (firebaseToken == null || firebaseToken.isEmpty) {
        throw Exception('Firebase did not return ID token');
      }
      debugPrint('[MS-Firebase] got Firebase ID token, syncing backend user');
      final data = await ApiClient().authenticateWithFirebaseIdToken(
        firebaseIdToken: firebaseToken,
      );
      debugPrint('[MS-Firebase] backend sync success, navigating dashboard');
      await _persistTokenAndNavigate(
        firebaseToken,
        tierHint: data['tier']?.toString(),
      );
    } on TimeoutException {
      setState(() {
        _errorMessage = l10n.errSystem(
          'Microsoft sign-in timed out. Check Firebase provider config and redirect settings.',
        );
      });
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
          _errorMessage = l10n.errMicrosoftClientIdInvalid;
        });
        return;
      }
      if (msg.contains('invalid id token')) {
        setState(() {
          _errorMessage = l10n.errMicrosoftInvalidIdToken;
        });
        return;
      }
      if (msg.contains('personal account') || msg.contains('microsoft account')) {
        setState(() {
          _errorMessage = l10n.errMicrosoftPersonalAccountNotSupported;
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
                        height: 22 * _uiScale,
                        child: Image.asset(
                          'assets/icons/google_logo.png',
                          fit: BoxFit.contain,
                        ),
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
                        child: Image.asset(
                          'assets/icons/microsoft_logo.png',
                          fit: BoxFit.contain,
                        ),
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