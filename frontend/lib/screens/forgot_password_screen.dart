import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../widgets/marketing_footer.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errInvalidEmail)),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final langCode = Localizations.localeOf(context).languageCode;
      try {
        await _firebaseAuth.setLanguageCode(langCode);
      } catch (_) {
        // setLanguageCode may throw on unsupported platforms; safe to ignore.
      }
      await _firebaseAuth.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.msgPasswordResetEmailSent),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // Firebase 在 user-not-found 时也会返回错误；为防止账号探测，统一展示成功
      // 与后端旧版"如果该邮箱已注册，验证码已发送"语义一致。
      if (e.code == 'user-not-found') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.msgPasswordResetEmailSent),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_firebaseResetErrorMessage(e, l10n)),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.errSystem(e.toString())),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _firebaseResetErrorMessage(
    FirebaseAuthException e,
    AppLocalizations l10n,
  ) {
    switch (e.code) {
      case 'invalid-email':
        return l10n.errInvalidEmail;
      case 'too-many-requests':
        return l10n.errSystem(
          'Too many reset attempts. Please wait a moment before retrying.',
        );
      case 'network-request-failed':
        return l10n.errNetwork(e.message ?? 'network-request-failed');
      default:
        return l10n.errSystem('${e.code}: ${e.message ?? ''}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.forgotPasswordTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.lock_reset,
                        size: 80,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(height: 32),
                      Text(
                        l10n.enterEmailPrompt,
                        style: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _emailController,
                        style: const TextStyle(color: AppColors.onSurface),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: l10n.emailLabel,
                          prefixIcon: const Icon(
                            Icons.email,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _sendResetEmail,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: AppColors.onSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                l10n.sendCodeBtn,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
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
