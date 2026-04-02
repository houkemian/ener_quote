import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../l10n/app_localizations.dart'; // 🌟 引入字典
import '../main.dart'; // 👈 新增这行，为了拿到 globalNavigatorKey

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {

  final l10n = AppLocalizations.of(globalNavigatorKey.currentContext!)!;

  int _step = 1; // 1: 填邮箱, 2: 填验证码和新密码
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendCode() async {


    // 🌟 获取当前的语言代码 (比如 "zh" 或 "en")
    final langCode = Localizations.localeOf(context).languageCode;

    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errInvalidEmail)));
      return;
    }

    setState(() => _isLoading = true);
    await ApiClient().requestPasswordReset(email, langCode);
    setState(() {
      _isLoading = false;
      _step = 2; // 无脑进入第二步
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.msgCodeSent), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _submitNewPassword() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errCodeLength)));
      return;
    }
    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errNewPwdLength)));
      return;
    }

    setState(() => _isLoading = true);
    final success = await ApiClient().resetPassword(email, code, newPassword);
    setState(() => _isLoading = false);

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.msgResetSuccess), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // 回到登录页
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errCodeInvalid), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 召唤当前环境的翻译官
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.forgotPasswordTitle), backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.lock_reset, size: 80, color: Colors.amber),
                const SizedBox(height: 32),

                if (_step == 1) ...[
                  Text(l10n.enterEmailPrompt, style: const TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: l10n.emailLabel, // 🌟
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.email, color: Colors.white54),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _sendCode,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676), padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: _isLoading ? const CircularProgressIndicator() : Text(l10n.sendCodeBtn, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ] else ...[
                  Text(l10n.codeSentMsg(_emailController.text), style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center), // 🌟 带参数的翻译
                  const SizedBox(height: 24),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, letterSpacing: 8, fontSize: 20),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: l10n.codeInputHint, // 🌟
                      hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 2, fontSize: 16),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _newPasswordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: l10n.newPasswordLabel, // 🌟
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.lock, color: Colors.white54),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitNewPassword,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: _isLoading ? const CircularProgressIndicator() : Text(l10n.confirmResetBtn, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _step = 1),
                    child: Text(l10n.resendPrompt, style: const TextStyle(color: Colors.white54)), // 🌟
                  )
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}