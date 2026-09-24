import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';
import 'login_screen.dart';

// ─── Forgot Password ──────────────────────────────────────────────────────────
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phoneCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() { _phoneCtrl.dispose(); super.dispose(); }

  Future<void> _sendOtp() async {
    if (_phoneCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final api = ApiService();
      await api.post('/auth/send-otp', data: {'phone': _phoneCtrl.text.trim()});
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ResetPasswordScreen(phone: _phoneCtrl.text.trim())));
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send OTP. Check your phone number.'), backgroundColor: AppColors.error));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PharmaScaffold(
      showLogo: true,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 20),
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: AppColors.lightGreen, shape: BoxShape.circle),
              child: const Icon(Icons.lock_reset, color: AppColors.primary, size: 36),
            ),
          ),
          const SizedBox(height: 20),
          const Center(child: Text('Forgot Password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
          const SizedBox(height: 8),
          const Center(child: Text(
            'Enter your phone number and we\'ll send a verification code to reset your password.',
            style: TextStyle(color: AppColors.textGrey, fontSize: 13),
            textAlign: TextAlign.center,
          )),
          const SizedBox(height: 32),
          PharmaField(
            label: 'Phone number',
            hint: 'e.g. +237 6XX XXX XXX',
            prefixIcon: Icons.phone_outlined,
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 24),
          PharmaButton(label: 'Send Reset Code', onPressed: _sendOtp, isLoading: _loading, icon: Icons.send),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Login', style: TextStyle(color: AppColors.primary)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Reset Password ───────────────────────────────────────────────────────────
class ResetPasswordScreen extends StatefulWidget {
  final String phone;
  const ResetPasswordScreen({super.key, required this.phone});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  bool _otpVerified = false;
  final _api = ApiService();

  String get _otp => _otpControllers.map((c) => c.text).join();

  @override
  void dispose() {
    for (final c in _otpControllers) c.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    if (_otp.length < 6) return;
    setState(() => _loading = true);
    try {
      await _api.post('/auth/verify-otp', data: {'phone': widget.phone, 'otp': _otp});
      setState(() { _otpVerified = true; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP. Try again.'), backgroundColor: AppColors.error));
      setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_passwordCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match'), backgroundColor: AppColors.error));
      return;
    }
    if (_passwordCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters'), backgroundColor: AppColors.error));
      return;
    }
    setState(() => _loading = true);
    try {
      await _api.post('/auth/reset-password', data: {
        'phone': widget.phone,
        'otp': _otp,
        'newPassword': _passwordCtrl.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successfully!'), backgroundColor: AppColors.primary));
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (r) => false,
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset failed. Try again.'), backgroundColor: AppColors.error));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PharmaScaffold(
      showLogo: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 20),
          if (!_otpVerified) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: AppColors.lightGreen, shape: BoxShape.circle),
                child: const Icon(Icons.sms_outlined, color: AppColors.primary, size: 36),
              ),
            ),
            const SizedBox(height: 16),
            Center(child: Text('Code sent to ${widget.phone}',
              style: const TextStyle(fontSize: 14, color: AppColors.textGrey))),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) => Container(
                width: 44, height: 52,
                margin: EdgeInsets.only(right: i < 5 ? 8 : 0),
                child: TextFormField(
                  controller: _otpControllers[i],
                  focusNode: _otpFocusNodes[i],
                  maxLength: 1,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.lightGreen, width: 2)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                  ),
                  onChanged: (v) {
                    if (v.isNotEmpty && i < 5) _otpFocusNodes[i + 1].requestFocus();
                    if (v.isEmpty && i > 0) _otpFocusNodes[i - 1].requestFocus();
                    if (i == 5 && v.isNotEmpty) _verifyOtp();
                  },
                ),
              )),
            ),
            const SizedBox(height: 24),
            PharmaButton(label: 'Verify Code', onPressed: _verifyOtp, isLoading: _loading),
          ] else ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: AppColors.lightGreen, shape: BoxShape.circle),
                child: const Icon(Icons.lock_outline, color: AppColors.primary, size: 36),
              ),
            ),
            const SizedBox(height: 16),
            const Center(child: Text('Create New Password',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            const SizedBox(height: 24),
            PharmaField(
              label: 'New Password',
              hint: 'At least 6 characters',
              prefixIcon: Icons.lock_outline,
              controller: _passwordCtrl,
              obscure: _obscure,
              obscureToggle: _obscure,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
            ),
            const SizedBox(height: 14),
            PharmaField(
              label: 'Confirm Password',
              hint: 'Re-enter new password',
              prefixIcon: Icons.lock_outline,
              controller: _confirmCtrl,
              obscure: _obscureConfirm,
              obscureToggle: _obscureConfirm,
              onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            const SizedBox(height: 24),
            PharmaButton(label: 'Reset Password', onPressed: _resetPassword, isLoading: _loading, icon: Icons.check),
          ],
        ]),
      ),
    );
  }
}
