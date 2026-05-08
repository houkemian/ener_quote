import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../widgets/marketing_footer.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const double _uiScale = 0.8;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String _errorMessage = '';

  Future<void> _register() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = l10n.errEmpty);
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
      final langCode = Localizations.localeOf(context).languageCode;
      try {
        await _firebaseAuth.setLanguageCode(langCode);
      } catch (_) {
        // setLanguageCode may throw on some platforms; safe to ignore.
      }

      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(code: 'unknown');
      }

      await user.sendEmailVerification();
      // Sign out so the next /auth/firebase call (after verification) carries
      // a fresh ID token with email_verified=true.
      await _firebaseAuth.signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.msgVerifyEmailSent),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _firebaseRegisterErrorMessage(e, l10n);
      });
    } catch (e) {
      setState(() => _errorMessage = l10n.errSystem(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _firebaseRegisterErrorMessage(
    FirebaseAuthException e,
    AppLocalizations l10n,
  ) {
    switch (e.code) {
      case 'email-already-in-use':
        return l10n.errEmailAlreadyInUse;
      case 'invalid-email':
        return l10n.errInvalidEmail;
      case 'weak-password':
        return l10n.errPasswordLength;
      case 'operation-not-allowed':
        return l10n.errSystem(
          'Email/password sign-in is disabled in Firebase Console.',
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
                            l10n.registerTitle,
                            style: TextStyle(
                              fontSize: 24 * _uiScale,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                          ),
                          SizedBox(height: 8 * _uiScale),
                          Text(
                            l10n.registerSubtitle,
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
                  onPressed: _isLoading ? null : _register,
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
                    l10n.freeRegisterBtn,
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
