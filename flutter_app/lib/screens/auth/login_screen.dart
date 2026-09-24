import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../patient/patient_home_screen.dart';
import '../doctor/doctor_home_screen.dart';
import '../pharmacist/pharmacist_home_screen.dart';
import '../driver/driver_home_screen.dart';
import '../admin/admin_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthService>();
    final ok = await auth.login(_identifierCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;
    if (ok) {
      Widget next;
      switch (auth.role) {
        case 'doctor': next = const DoctorHomeScreen(); break;
        case 'pharmacist': next = const PharmacistHomeScreen(); break;
        case 'delivery_driver': next = const DriverHomeScreen(); break;
        case 'admin': next = const AdminHomeScreen(); break;
        default: next = const PatientHomeScreen();
      }
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.lastError ?? 'Login failed'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PharmaScaffold(
      showLogo: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome Back',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sign in to access your digital health dashboard',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textGrey,
                ),
              ),
              const SizedBox(height: 24),
              PharmaField(
                label: 'Email or Phone Number',
                hint: 'e.g. marie@patient.cm or +237 6xx xxx xxx',
                prefixIcon: Icons.alternate_email_rounded,
                controller: _identifierCtrl,
                validator: (v) => (v?.isEmpty ?? true) ? 'Please enter your email or phone' : null,
              ),
              const SizedBox(height: 16),
              PharmaField(
                label: 'Password',
                hint: '••••••••',
                prefixIcon: Icons.lock_outline_rounded,
                controller: _passwordCtrl,
                obscure: _obscure,
                obscureToggle: _obscure,
                onToggleObscure: () => setState(() => _obscure = !_obscure),
                validator: (v) => (v?.isEmpty ?? true) ? 'Password is required' : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                  child: Text(
                    'Forgot password?',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Consumer<AuthService>(
                builder: (_, auth, __) => PharmaButton(
                  label: 'Sign In to Account',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: _login,
                  isLoading: auth.isLoading,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: RichText(
                    text: TextSpan(
                      text: "Don't have an account? ",
                      style: GoogleFonts.plusJakartaSans(color: AppColors.textGrey, fontSize: 13),
                      children: [
                        TextSpan(
                          text: 'Register Now',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
