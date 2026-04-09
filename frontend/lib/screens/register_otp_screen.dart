import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pinput/pinput.dart';

import '../core/auth/token_manager.dart';
import '../core/network/api_client.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import 'dashboard_screen.dart';

class RegisterOtpScreen extends StatefulWidget {
  final String email;
  final String password;

  const RegisterOtpScreen({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<RegisterOtpScreen> createState() => _RegisterOtpScreenState();
}

class _RegisterOtpScreenState extends State<RegisterOtpScreen> {
  static const int _resendCooldownSeconds = 60;
  final TextEditingController _otpController = TextEditingController();

  Timer? _timer;
  int _secondsLeft = _resendCooldownSeconds;
  bool _isSubmitting = false;
  bool _isResending = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() {
      _secondsLeft = _resendCooldownSeconds;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _secondsLeft = 0;
        });
      } else {
        setState(() {
          _secondsLeft -= 1;
        });
      }
    });
  }

  Future<void> _submitOtp([String? value]) async {
    final l10n = AppLocalizations.of(context)!;
    final otp = (value ?? _otpController.text).trim();
    if (otp.length != 6 || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    try {
      final result = await ApiClient().verifyOtpAndRegister(
        email: widget.email,
        password: widget.password,
        otpCode: otp,
      );
      await TokenManager.saveAccessToken(result.accessToken);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_tier', result.tier ?? 'FREE');

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    } on DioException catch (e) {
      setState(() {
        if (e.response?.statusCode == 400 ||
            e.response?.statusCode == 410 ||
            e.response?.statusCode == 409) {
          _errorMessage =
              (e.response?.data is Map<String, dynamic>)
                  ? ((e.response?.data['detail'] as String?) ?? l10n.errRegisterFailedFallback)
                  : l10n.errRegisterFailedFallback;
        } else {
          _errorMessage = l10n.errNetwork(e.message ?? 'Unknown Error');
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = l10n.errSystem(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_secondsLeft > 0 || _isResending) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isResending = true;
      _errorMessage = '';
    });
    try {
      final langCode = Localizations.localeOf(context).languageCode;
      await ApiClient().sendRegisterOtp(widget.email, langCode);
      _startCooldown();
    } on DioException catch (e) {
      setState(() {
        _errorMessage = l10n.errNetwork(e.message ?? 'Unknown Error');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.onSurfaceVariant),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.mark_email_read_outlined, size: 56),
                const SizedBox(height: 16),
                Text(
                  'Enter verification code',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We sent a 6-digit code to ${widget.email}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 24),
                Pinput(
                  controller: _otpController,
                  length: 6,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  onCompleted: _submitOtp,
                ),
                const SizedBox(height: 12),
                if (_errorMessage.isNotEmpty)
                  Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : () => _submitOtp(),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.secureLoginBtn),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: (_secondsLeft == 0 && !_isResending) ? _resendOtp : null,
                  child: Text(
                    _secondsLeft == 0
                        ? 'Resend code'
                        : 'Resend in ${_secondsLeft}s',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
