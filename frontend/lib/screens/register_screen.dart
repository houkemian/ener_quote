import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../l10n/app_localizations.dart'; // 🌟 引入多语言
import '../theme/app_colors.dart';
import '../widgets/marketing_footer.dart';
import 'register_otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const double _uiScale = 0.8;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String _errorMessage = '';

  Future<void> _sendOtp() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = l10n.errEmpty); // 🌟 动态错误提示
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = l10n.errPasswordLength);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });


    try {
      if (!mounted) return;
      final langCode = Localizations.localeOf(context).languageCode;
      await ApiClient().sendRegisterOtp(email, langCode);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RegisterOtpScreen(
            email: email,
            password: password,
          ),
        ),
      );
    } on DioException catch (e) {
      setState(() {
        if (e.response?.statusCode == 400 || e.response?.statusCode == 409) {
          _errorMessage = e.response?.data['detail'] ?? l10n.errRegisterFailedFallback;
        } else {
          _errorMessage = l10n.errNetwork(e.message ?? 'Unknown Error');
        }
      });
    } catch (e) {
      setState(() => _errorMessage = l10n.errSystem(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardInset > 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.onSurfaceVariant),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    32 * _uiScale,
                    8 * _uiScale,
                    32 * _uiScale,
                    8 * _uiScale + keyboardInset,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_add_alt_1,
                      size: 64 * _uiScale,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(width: 12 * _uiScale),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.registerTitle, // 🌟 动态注册标题
                            style: TextStyle(
                              fontSize: 24 * _uiScale,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                          ),
                          SizedBox(height: 8 * _uiScale),
                          Text(
                            l10n.registerSubtitle, // 🌟 动态注册副标题
                            style: TextStyle(
                              fontSize: 14 * _uiScale,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 40 * _uiScale),

                _buildTextField(_emailController, l10n.emailLabel, false),
                SizedBox(height: 16 * _uiScale),
                _buildTextField(_passwordController, l10n.passwordLabel, true),

                SizedBox(height: 12 * _uiScale),
                if (_errorMessage.isNotEmpty)
                  Text(
                    _errorMessage,
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 14 * _uiScale,
                    ),
                    textAlign: TextAlign.center,
                  ),
                SizedBox(height: 24 * _uiScale),

                ElevatedButton(
                  onPressed: _isLoading ? null : _sendOtp,
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2 * _uiScale,
                          ),
                        )
                      : Text(
                    "Get verification code",
                    style: TextStyle(
                      fontSize: 16 * _uiScale,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 20 * _uiScale),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!isKeyboardVisible) const MarketingFooter(),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, bool isPassword) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? !_isPasswordVisible : false,
      style: TextStyle(
        color: AppColors.onSurface,
        fontSize: 16 * _uiScale,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 14 * _uiScale),
        suffixIcon: isPassword
            ? IconButton(
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                  size: 18 * _uiScale,
                ),
              )
            : null,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12 * _uiScale,
          vertical: 14 * _uiScale,
        ),
      ),
    );
  }
}