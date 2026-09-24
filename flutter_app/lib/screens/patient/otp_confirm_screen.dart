import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:signature/signature.dart';
import 'dart:typed_data';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';
import 'delivery_success_screen.dart';

// ─── OTP Confirm ──────────────────────────────────────────────────────────────
class OtpConfirmScreen extends StatefulWidget {
  final String orderId;
  const OtpConfirmScreen({super.key, required this.orderId});
  @override
  State<OtpConfirmScreen> createState() => _OtpConfirmScreenState();
}

class _OtpConfirmScreenState extends State<OtpConfirmScreen> {
  final _api = ApiService();
  final _controllers = List.generate(4, (_) => TextEditingController());
  final _focusNodes = List.generate(4, (_) => FocusNode());
  bool _loading = false;

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otp.length < 4) return;
    setState(() => _loading = true);
    try {
      await _api.post('/orders/${widget.orderId}/otp/verify', data: {'otp': _otp});
      if (!mounted) return;
      Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => SignatureScreen(orderId: widget.orderId)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP. Please try again.'), backgroundColor: AppColors.error));
    } finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OTP Verification')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.lightGreen, shape: BoxShape.circle),
            child: const Icon(Icons.lock_outline, color: AppColors.primary, size: 40),
          ),
          const SizedBox(height: 20),
          const Text('Delivery Confirmation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Enter the OTP shared by your driver', style: TextStyle(color: AppColors.textGrey, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) => Container(
              width: 56, height: 60,
              margin: EdgeInsets.only(right: i < 3 ? 12 : 0),
              child: TextFormField(
                controller: _controllers[i],
                focusNode: _focusNodes[i],
                maxLength: 1,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
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
                  if (v.isNotEmpty && i < 3) _focusNodes[i + 1].requestFocus();
                  if (v.isEmpty && i > 0) _focusNodes[i - 1].requestFocus();
                },
              ),
            )),
          ),
          const SizedBox(height: 32),
          PharmaButton(label: 'Verify', onPressed: _verify, isLoading: _loading),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {},
            child: const Text('Resend OTP (00:45)', style: TextStyle(color: AppColors.textGrey)),
          ),
        ]),
      ),
    );
  }
}

// ─── Signature Screen ─────────────────────────────────────────────────────────
class SignatureScreen extends StatefulWidget {
  final String orderId;
  const SignatureScreen({super.key, required this.orderId});
  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  final _signatureCtrl = SignatureController(penStrokeWidth: 2, penColor: Colors.black, exportBackgroundColor: Colors.white);
  final _api = ApiService();
  bool _loading = false;

  Future<void> _confirm() async {
    if (_signatureCtrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide your signature'), backgroundColor: AppColors.error));
      return;
    }
    setState(() => _loading = true);
    try {
      final Uint8List? bytes = await _signatureCtrl.toPngBytes();
      if (bytes == null) return;
      final formData = FormData.fromMap({
        'signature': MultipartFile.fromBytes(bytes, filename: 'signature.png'),
      });
      await _api.postForm('/orders/${widget.orderId}/signature', formData);
      if (!mounted) return;
      Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => DeliverySuccessScreen(orderId: widget.orderId)));
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit signature'), backgroundColor: AppColors.error));
    } finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign to Confirm Delivery')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const SizedBox(height: 12),
          const Text('Please sign below to confirm receipt of your order.',
            style: TextStyle(color: AppColors.textGrey), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.lightGreen, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Signature(controller: _signatureCtrl, backgroundColor: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: PharmaButton(label: 'Clear', onPressed: () => _signatureCtrl.clear(), outlined: true)),
            const SizedBox(width: 12),
            Expanded(child: PharmaButton(label: 'Confirm Delivery', onPressed: _confirm, isLoading: _loading)),
          ]),
        ]),
      ),
    );
  }
}
