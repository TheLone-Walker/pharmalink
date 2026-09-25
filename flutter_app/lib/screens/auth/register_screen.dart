import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  
  // Professional fields
  final _licenseNumberCtrl = TextEditingController();
  final _specialtyCtrl = TextEditingController();
  final _hospitalCtrl = TextEditingController();
  final _pharmacyNameCtrl = TextEditingController();
  final _pharmacyAddressCtrl = TextEditingController();
  final _pharmacyCategoryCtrl = TextEditingController(text: 'Officine');
  final _vehicleInfoCtrl = TextEditingController();

  String _role = 'patient';
  bool _obscure = true;

  final _roles = ['Patient', 'Doctor', 'Pharmacist', 'Delivery'];
  final _roleMap = {'Patient': 'patient', 'Doctor': 'doctor', 'Pharmacist': 'pharmacist', 'Delivery': 'delivery_driver'};

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _licenseNumberCtrl.dispose();
    _specialtyCtrl.dispose();
    _hospitalCtrl.dispose();
    _pharmacyNameCtrl.dispose();
    _pharmacyAddressCtrl.dispose();
    _pharmacyCategoryCtrl.dispose();
    _vehicleInfoCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthService>();
    
    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'password': _passwordCtrl.text,
      'role': _role,
    };

    if (_role == 'doctor') {
      data['licenseNumber'] = _licenseNumberCtrl.text.trim();
      if (_specialtyCtrl.text.trim().isNotEmpty) data['specialty'] = _specialtyCtrl.text.trim();
      if (_hospitalCtrl.text.trim().isNotEmpty) data['hospital'] = _hospitalCtrl.text.trim();
    } else if (_role == 'pharmacist') {
      data['licenseNumber'] = _licenseNumberCtrl.text.trim();
      data['pharmacyName'] = _pharmacyNameCtrl.text.trim();
      data['pharmacyAddress'] = _pharmacyAddressCtrl.text.trim();
      data['pharmacyCategory'] = _pharmacyCategoryCtrl.text.trim();
    } else if (_role == 'delivery_driver') {
      if (_vehicleInfoCtrl.text.trim().isNotEmpty) data['vehicleInfo'] = _vehicleInfoCtrl.text.trim();
    }

    final ok = await auth.register(data);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_role == 'patient'
              ? 'Account created successfully!'
              : 'Professional account created! Please sign in to upload your verification documents.'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.lastError ?? 'Registration failed'), backgroundColor: AppColors.error),
      );
    }
  }

  Widget _buildActorBanner() {
    String imagePath;
    String title;
    String subtitle;
    Color accentColor;
    IconData iconData;

    switch (_role) {
      case 'doctor':
        imagePath = 'assets/images/doctor_consultation_scene.jpg';
        title = 'Medical Doctor & Specialist';
        subtitle = 'ONMC teleconsultation, digital e-prescriptions & lab ordering';
        accentColor = const Color(0xFF0F766E);
        iconData = Icons.medical_services_rounded;
        break;
      case 'pharmacist':
        imagePath = 'assets/images/pharmacy_store_banner.jpg';
        title = 'Licensed Community Pharmacist';
        subtitle = 'Dispense orders, validate prescriptions & 24/7 night guard services';
        accentColor = const Color(0xFF0284C7);
        iconData = Icons.local_pharmacy_rounded;
        break;
      case 'delivery_driver':
        imagePath = 'assets/images/express_delivery_driver.jpg';
        title = 'Certified Medical Dispatch Courier';
        subtitle = 'Fast delivery of urgent medicines with live tracking & delivery OTP';
        accentColor = const Color(0xFFD97706);
        iconData = Icons.delivery_dining_rounded;
        break;
      default:
        imagePath = 'assets/images/patient_portrait_hero.jpg';
        title = 'Patient & Family Healthcare';
        subtitle = 'Search pharmacy stock, upload prescriptions & book doctor visits';
        accentColor = AppColors.primary;
        iconData = Icons.person_rounded;
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey<String>(_role),
        width: double.infinity,
        height: 135,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: accentColor.withValues(alpha: 0.2)),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.82),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(iconData, size: 13, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(
                            title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.92),
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PharmaScaffold(
      showLogo: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Create Account',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Join our unified digital health network in Cameroon',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textGrey),
            ),
            const SizedBox(height: 18),
            RoleTabSelector(
              roles: _roles,
              selected: _role == 'delivery_driver' ? 'delivery' : _role,
              onSelect: (v) => setState(() => _role = v == 'delivery' ? 'delivery_driver' : v),
            ),
            const SizedBox(height: 16),
            _buildActorBanner(),
            
            // Basic Account Info
            PharmaField(
              label: 'Full name',
              hint: _role == 'doctor' ? 'e.g. Dr. Paul Biya' : 'e.g. Marie Nguema',
              prefixIcon: Icons.person_outline,
              controller: _nameCtrl,
              validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            PharmaField(
              label: 'Email',
              hint: 'e.g. contact@email.cm',
              prefixIcon: Icons.mail_outline,
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            PharmaField(
              label: 'Phone number (Cameroon)',
              hint: 'e.g. +237 6XX XXX XXX',
              prefixIcon: Icons.phone_outlined,
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            PharmaField(
              label: 'Password',
              hint: 'Create a strong password',
              prefixIcon: Icons.lock_outline,
              controller: _passwordCtrl,
              obscure: _obscure,
              obscureToggle: _obscure,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              validator: (v) => (v?.length ?? 0) < 6 ? 'At least 6 characters' : null,
            ),

            // ─── Doctor Professional Details ──────────────────────────────────────────
            if (_role == 'doctor') ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lightGreen.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(children: const [
                  Icon(Icons.medical_services_outlined, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ONMC Medical Credentials (Ordre National des Médecins du Cameroun)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              PharmaField(
                label: 'ONMC License / Registration Number *',
                hint: 'e.g. ONMC/2023/8492',
                prefixIcon: Icons.badge_outlined,
                controller: _licenseNumberCtrl,
                validator: (v) => (_role == 'doctor' && (v?.isEmpty ?? true)) ? 'ONMC License number is required' : null,
              ),
              const SizedBox(height: 14),
              PharmaField(
                label: 'Specialty',
                hint: 'e.g. General Practitioner, Cardiology, Pediatrics',
                prefixIcon: Icons.local_hospital_outlined,
                controller: _specialtyCtrl,
              ),
              const SizedBox(height: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hospital / Practice (Yaoundé)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark)),
                  const SizedBox(height: 6),
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: _hospitalCtrl.text),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return AppConstants.cameroonHospitals.take(5);
                      }
                      return AppConstants.cameroonHospitals.where((String option) {
                        return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    onSelected: (String selection) {
                      _hospitalCtrl.text = selection;
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      controller.addListener(() {
                        _hospitalCtrl.text = controller.text;
                      });
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: 'e.g. Hôpital Central de Yaoundé (type for suggestions)',
                          prefixIcon: const Icon(Icons.apartment_outlined, color: AppColors.primary),
                          filled: true,
                          fillColor: AppColors.fieldBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.fieldRadius), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.fieldRadius), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.fieldRadius), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 6.0,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 220, maxWidth: 330),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEEEEEE))),
                            child: ListView.separated(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (BuildContext context, int index) {
                                final String option = options.elementAt(index);
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.local_hospital, size: 16, color: AppColors.primary),
                                  title: Text(option, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],

            // ─── Pharmacist Professional Details ──────────────────────────────────────
            if (_role == 'pharmacist') ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lightGreen.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(children: const [
                  Icon(Icons.local_pharmacy_outlined, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ONPC Pharmacy Credentials (Ordre National des Pharmaciens du Cameroun)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              PharmaField(
                label: 'ONPC License / Authorization Number *',
                hint: 'e.g. ONPC/PHARM/2022/104',
                prefixIcon: Icons.badge_outlined,
                controller: _licenseNumberCtrl,
                validator: (v) => (_role == 'pharmacist' && (v?.isEmpty ?? true)) ? 'ONPC License number is required' : null,
              ),
              const SizedBox(height: 14),
              PharmaField(
                label: 'Pharmacy Name *',
                hint: 'e.g. Pharmacie du Centre, Pharmacie Bastos',
                prefixIcon: Icons.storefront_outlined,
                controller: _pharmacyNameCtrl,
                validator: (v) => (_role == 'pharmacist' && (v?.isEmpty ?? true)) ? 'Pharmacy name is required' : null,
              ),
              const SizedBox(height: 14),
              PharmaField(
                label: 'Pharmacy Address in Yaoundé *',
                hint: 'e.g. Rue Joseph Essono Balla, Bastos, Yaoundé',
                prefixIcon: Icons.location_on_outlined,
                controller: _pharmacyAddressCtrl,
                validator: (v) => (_role == 'pharmacist' && (v?.isEmpty ?? true)) ? 'Pharmacy address is required' : null,
              ),
            ],

            // ─── Delivery Driver Details ──────────────────────────────────────────────
            if (_role == 'delivery_driver') ...[
              const SizedBox(height: 14),
              PharmaField(
                label: 'Vehicle Information',
                hint: 'e.g. Motorbike CG 125 (Matricule CE-482-AB)',
                prefixIcon: Icons.two_wheeler_outlined,
                controller: _vehicleInfoCtrl,
              ),
            ],

            const SizedBox(height: 24),
            Consumer<AuthService>(
              builder: (_, auth, __) => PharmaButton(label: 'Register Account', onPressed: _register, isLoading: auth.isLoading),
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: RichText(text: const TextSpan(
                  text: 'Already have an account? ',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                  children: [TextSpan(text: 'Login', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600))],
                )),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
