import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../l10n/app_localizations.dart'; // 🌟 引入多语言

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _register() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = l10n.errEmpty); // 🌟 动态错误提示
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = l10n.errPasswordLength);
      return;
    }
    if (password != confirmPassword) {
      setState(() => _errorMessage = l10n.errPasswordMatch);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });


    try {
      await ApiClient().dio.post(
        '/auth/register',
        data: {'email': email, 'password': password},
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.msgRegisterSuccess), // 🌟 动态成功提示
          backgroundColor: const Color(0xFF00E676),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop();

    } on DioException catch (e) {
      setState(() {
        if (e.response?.statusCode == 400) {
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

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white54),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.person_add_alt_1, size: 64, color: Color(0xFF00E676)),
                const SizedBox(height: 20),
                Text(
                  l10n.registerTitle, // 🌟 动态注册标题
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.registerSubtitle, // 🌟 动态注册副标题
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.white54),
                ),
                const SizedBox(height: 40),

                _buildTextField(_emailController, l10n.emailLabel, false),
                const SizedBox(height: 16),
                _buildTextField(_passwordController, l10n.passwordLabel, true),
                const SizedBox(height: 16),
                _buildTextField(_confirmPasswordController, l10n.confirmPasswordLabel, true),

                const SizedBox(height: 12),
                if (_errorMessage.isNotEmpty)
                  Text(_errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 14), textAlign: TextAlign.center),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black))
                      : Text(
                    l10n.freeRegisterBtn, // 🌟 动态免费注册按钮
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, bool isPassword) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }
}