import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otp.length < 6) return;
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    final ok = await auth.verifyOtp(widget.phone, _otp);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone verified!'), backgroundColor: AppColors.primary));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.lastError ?? 'Invalid OTP'), backgroundColor: AppColors.error));
    }
    setState(() => _loading = false);
  }

  Future<void> _resend() async {
    final auth = context.read<AuthService>();
    await auth.sendOtp(widget.phone);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OTP resent!'), backgroundColor: AppColors.primary));
  }

  @override
  Widget build(BuildContext context) {
    return PharmaScaffold(
      showLogo: true,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: AppColors.lightGreen, shape: BoxShape.circle),
            child: const Icon(Icons.sms_outlined, color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 20),
          const Text('Verify Phone Number', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Enter the 6-digit code sent to\n${widget.phone}',
            style: const TextStyle(color: AppColors.textGrey, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (i) => Container(
              width: 44, height: 52,
              margin: EdgeInsets.only(right: i < 5 ? 8 : 0),
              child: TextFormField(
                controller: _controllers[i],
                focusNode: _focusNodes[i],
                maxLength: 1,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.lightGreen, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
                onChanged: (v) {
                  if (v.isNotEmpty && i < 5) _focusNodes[i + 1].requestFocus();
                  if (v.isEmpty && i > 0) _focusNodes[i - 1].requestFocus();
                  if (i == 5 && v.isNotEmpty) _verify();
                },
              ),
            )),
          ),
          const SizedBox(height: 32),
          PharmaButton(label: 'Verify', onPressed: _verify, isLoading: _loading),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _resend,
            child: const Text('Resend OTP', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500)),
          ),
        ]),
      ),
    );
  }
}
