import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/socket_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';
import '../auth/login_screen.dart';

// ─── Notifications ────────────────────────────────────────────────────────────
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = ApiService();
  final _socket = SocketService();
  List _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _socket.onNewNotification(_onSocketNotification);
  }

  void _onSocketNotification(dynamic data) {
    if (mounted) {
      _load();
    }
  }

  @override
  void dispose() {
    _socket.removeListener('notification:new', _onSocketNotification);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await _api.get('/notifications');
      setState(() => _notifications = res.data['data'] ?? []);
    } catch (_) {} finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications'), actions: [
        TextButton(onPressed: () async { await _api.patch('/notifications/read-all'); _load(); },
          child: const Text('Mark all read', style: TextStyle(color: Colors.white, fontSize: 12))),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _notifications.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.notifications_none, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  const Text('No notifications', style: TextStyle(color: AppColors.textGrey)),
                ]))
              : ListView.separated(
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final n = _notifications[i];
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: n['isRead'] ? Colors.grey[100] : AppColors.lightGreen, shape: BoxShape.circle),
                        child: Icon(_iconForType(n['type']), color: n['isRead'] ? Colors.grey : AppColors.primary, size: 20),
                      ),
                      title: Text(n['title'] ?? '', style: TextStyle(fontWeight: n['isRead'] ? FontWeight.normal : FontWeight.w600, fontSize: 14)),
                      subtitle: Text(n['body'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                      onTap: () async { await _api.patch('/notifications/${n['id']}/read'); _load(); },
                    );
                  },
                ),
    );
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'order': return Icons.shopping_bag_outlined;
      case 'appointment': return Icons.calendar_today_outlined;
      case 'prescription': return Icons.description_outlined;
      default: return Icons.notifications_outlined;
    }
  }
}

// ─── Profile ──────────────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _profileDetails;
  bool _loading = false;
  bool _fetching = true;

  // Basic info controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Patient controllers
  final _addressCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  String? _selectedBloodType;
  DateTime? _selectedDob;

  // Doctor controllers
  final _hospitalCtrl = TextEditingController();
  final _specialtyCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  // Pharmacist controllers
  final _pharmacyNameCtrl = TextEditingController();
  final _pharmacyAddressCtrl = TextEditingController();
  String _pharmacyCategory = 'Officine';
  final _openingHoursCtrl = TextEditingController();

  // Driver controllers
  final _vehicleInfoCtrl = TextEditingController();
  bool _driverIsOnline = true;

  final List<String> _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Unknown'];
  final List<String> _pharmacyCategories = ['Officine', 'Hospitalière', 'Grossiste / Dépositaire', 'Clinique Privée'];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().user;
    _nameCtrl.text = user?['name'] ?? '';
    _emailCtrl.text = user?['email'] ?? '';
    _phoneCtrl.text = user?['phone'] ?? '';
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final res = await _api.get('/users/me');
      if (res.data != null && res.data['data'] != null) {
        final data = res.data['data'] as Map<String, dynamic>;
        setState(() {
          _profileDetails = data;
          _nameCtrl.text = data['name'] ?? _nameCtrl.text;
          _emailCtrl.text = data['email'] ?? _emailCtrl.text;
          _phoneCtrl.text = data['phone'] ?? _phoneCtrl.text;

          // Populate Patient
          final patient = data['patientProfile'];
          if (patient != null) {
            _addressCtrl.text = patient['address'] ?? '';
            _allergiesCtrl.text = patient['allergies'] ?? '';
            _selectedBloodType = patient['bloodType'] ?? patient['bloodGroup'];
            if (patient['dateOfBirth'] != null) {
              _selectedDob = DateTime.tryParse(patient['dateOfBirth'].toString());
            }
          }

          // Populate Doctor
          final doc = data['doctorProfile'];
          if (doc != null) {
            _hospitalCtrl.text = doc['hospital'] ?? '';
            _specialtyCtrl.text = doc['specialty'] ?? '';
            _bioCtrl.text = doc['bio'] ?? '';
          }

          // Populate Pharmacist
          final pharm = data['pharmacistProfile'];
          if (pharm != null) {
            _pharmacyNameCtrl.text = pharm['pharmacyName'] ?? '';
            _pharmacyAddressCtrl.text = pharm['pharmacyAddress'] ?? '';
            _pharmacyCategory = pharm['pharmacyCategory'] ?? 'Officine';
            _openingHoursCtrl.text = pharm['openingHours'] ?? 'Mon-Sat: 08:00 - 20:00';
          }

          // Populate Driver
          final driver = data['driverProfile'];
          if (driver != null) {
            _vehicleInfoCtrl.text = driver['vehicleInfo'] ?? '';
            _driverIsOnline = driver['isOnline'] ?? true;
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _allergiesCtrl.dispose();
    _hospitalCtrl.dispose();
    _specialtyCtrl.dispose();
    _bioCtrl.dispose();
    _pharmacyNameCtrl.dispose();
    _pharmacyAddressCtrl.dispose();
    _openingHoursCtrl.dispose();
    _vehicleInfoCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    final role = (_profileDetails?['role'] ?? context.read<AuthService>().user?['role'] ?? 'patient').toString();

    final Map<String, dynamic> payload = {
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
    };

    if (role == 'patient') {
      payload.addAll({
        'address': _addressCtrl.text.trim(),
        'allergies': _allergiesCtrl.text.trim(),
        if (_selectedBloodType != null) 'bloodType': _selectedBloodType,
        if (_selectedDob != null) 'dateOfBirth': _selectedDob!.toIso8601String(),
      });
    } else if (role == 'doctor') {
      payload.addAll({
        'hospital': _hospitalCtrl.text.trim(),
        'specialty': _specialtyCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
      });
    } else if (role == 'pharmacist') {
      payload.addAll({
        'pharmacyName': _pharmacyNameCtrl.text.trim(),
        'pharmacyAddress': _pharmacyAddressCtrl.text.trim(),
        'pharmacyCategory': _pharmacyCategory,
        'openingHours': _openingHoursCtrl.text.trim(),
      });
    } else if (role == 'delivery_driver') {
      payload.addAll({
        'vehicleInfo': _vehicleInfoCtrl.text.trim(),
        'isOnline': _driverIsOnline,
      });
    }

    try {
      final res = await _api.put('/users/me', data: payload);
      if (!mounted) return;
      if (res.data != null && res.data['data'] != null) {
        setState(() {
          _profileDetails = res.data['data'];
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Profile information updated successfully!'), backgroundColor: AppColors.primary),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile. Please check your inputs.'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _profileDetails ?? context.watch<AuthService>().user;
    final name = _nameCtrl.text.isNotEmpty ? _nameCtrl.text : (user?['name'] ?? 'User');
    final role = (user?['role']?.toString() ?? 'patient').toLowerCase();
    final docProfile = user?['doctorProfile'];
    final pharmProfile = user?['pharmacistProfile'];

    final bool isOnmcVerified = docProfile?['isOnmcVerified'] == true;
    final bool isOnpcVerified = pharmProfile?['isOnpcVerified'] == true;
    final bool isUserVerified = user?['isVerified'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('My Profile & Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload profile',
            onPressed: () {
              setState(() => _fetching = true);
              _fetchProfile();
            },
          ),
        ],
      ),
      body: _fetching
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Header Card ──────────────────────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: AppColors.lightGreen,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                            if (isUserVerified || isOnmcVerified || isOnpcVerified)
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                child: const Icon(Icons.verified, color: Colors.white, size: 18),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            role.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ─── 1. Personal & Contact Info ──────────────────────────────
                  _sectionHeader('1. Personal & Contact Information', Icons.person_outline),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PharmaField(label: 'Full Name', hint: 'Enter your full name', prefixIcon: Icons.person_outline, controller: _nameCtrl),
                        const SizedBox(height: 12),
                        PharmaField(label: 'Email Address', hint: 'Enter email address', prefixIcon: Icons.mail_outline, controller: _emailCtrl, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 12),
                        PharmaField(label: 'Phone Number', hint: 'e.g. +237 6xx xxx xxx', prefixIcon: Icons.phone_outlined, controller: _phoneCtrl, keyboardType: TextInputType.phone),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ─── 2. Role-Specific Profile Details ─────────────────────────
                  if (role == 'patient') ...[
                    _sectionHeader('2. Health & Delivery Profile', Icons.health_and_safety_outlined),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _cardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PharmaField(
                            label: 'Residential / Delivery Address',
                            hint: 'e.g. Bastos, Yaoundé (near Embassy)',
                            prefixIcon: Icons.location_on_outlined,
                            controller: _addressCtrl,
                          ),
                          const SizedBox(height: 12),
                          const Text('Blood Group / Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedBloodType,
                                hint: const Text('Select Blood Group', style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
                                items: _bloodTypes.map((bt) => DropdownMenuItem(value: bt, child: Text(bt, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
                                onChanged: (val) => setState(() => _selectedBloodType = val),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          PharmaField(
                            label: 'Known Allergies & Medical Conditions',
                            hint: 'e.g. Penicillin, Aspirin, Pollen, Asthmatic (or None)',
                            prefixIcon: Icons.warning_amber_outlined,
                            controller: _allergiesCtrl,
                          ),
                          const SizedBox(height: 12),
                          const Text('Date of Birth', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _selectedDob ?? DateTime(1995, 1, 1),
                                firstDate: DateTime(1920),
                                lastDate: DateTime.now(),
                              );
                              if (d != null) setState(() => _selectedDob = d);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primary),
                                  const SizedBox(width: 10),
                                  Text(
                                    _selectedDob != null ? '${_selectedDob!.day}/${_selectedDob!.month}/${_selectedDob!.year}' : 'Select Date of Birth',
                                    style: TextStyle(fontSize: 13, color: _selectedDob != null ? AppColors.textDark : AppColors.textGrey, fontWeight: _selectedDob != null ? FontWeight.w600 : FontWeight.normal),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  if (role == 'doctor') ...[
                    _sectionHeader('2. Medical Practice & Workplace Details', Icons.medical_services_outlined),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _cardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Workplace / Hospital Affiliation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                          const SizedBox(height: 6),
                          Autocomplete<String>(
                            initialValue: TextEditingValue(text: _hospitalCtrl.text),
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return AppConstants.cameroonHospitals.take(6);
                              }
                              return AppConstants.cameroonHospitals.where(
                                (h) => h.toLowerCase().contains(textEditingValue.text.toLowerCase()),
                              );
                            },
                            onSelected: (String selection) {
                              _hospitalCtrl.text = selection;
                            },
                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                              return TextFormField(
                                controller: controller,
                                focusNode: focusNode,
                                onChanged: (v) => _hospitalCtrl.text = v,
                                decoration: InputDecoration(
                                  hintText: 'e.g. Hôpital Central de Yaoundé',
                                  hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                                  prefixIcon: const Icon(Icons.apartment_rounded, color: AppColors.primary, size: 20),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          const Text('Medical Specialty', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                          const SizedBox(height: 6),
                          Autocomplete<String>(
                            initialValue: TextEditingValue(text: _specialtyCtrl.text),
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return AppConstants.cameroonMedicalSpecialties.take(6);
                              }
                              return AppConstants.cameroonMedicalSpecialties.where(
                                (s) => s.toLowerCase().contains(textEditingValue.text.toLowerCase()),
                              );
                            },
                            onSelected: (String selection) {
                              _specialtyCtrl.text = selection;
                            },
                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                              return TextFormField(
                                controller: controller,
                                focusNode: focusNode,
                                onChanged: (v) => _specialtyCtrl.text = v,
                                decoration: InputDecoration(
                                  hintText: 'e.g. Cardiology, Pediatrics, General Medicine',
                                  hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                                  prefixIcon: const Icon(Icons.local_hospital_outlined, color: AppColors.primary, size: 20),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          PharmaField(
                            label: 'Clinical Bio & Credentials Summary',
                            hint: 'e.g. Senior Resident Physician with 8+ years experience in internal medicine.',
                            prefixIcon: Icons.notes_outlined,
                            controller: _bioCtrl,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.verified, size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                isOnmcVerified ? 'ONMC Official Accreditation: Verified ✓' : 'ONMC Verification: In Progress / Verified by Admin',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isOnmcVerified ? Colors.green.shade800 : Colors.orange.shade800),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  if (role == 'pharmacist') ...[
                    _sectionHeader('2. Pharmacy Business Profile', Icons.local_pharmacy_outlined),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _cardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PharmaField(
                            label: 'Pharmacy Business Name',
                            hint: 'e.g. Pharmacie du Centre, Yaoundé',
                            prefixIcon: Icons.storefront_outlined,
                            controller: _pharmacyNameCtrl,
                          ),
                          const SizedBox(height: 12),
                          PharmaField(
                            label: 'Physical Pharmacy Address',
                            hint: 'e.g. Avenue Kennedy, Yaoundé',
                            prefixIcon: Icons.location_on_outlined,
                            controller: _pharmacyAddressCtrl,
                          ),
                          const SizedBox(height: 12),
                          const Text('Pharmacy Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _pharmacyCategory,
                                items: _pharmacyCategories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _pharmacyCategory = val);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          PharmaField(
                            label: 'Operating / Opening Hours',
                            hint: 'e.g. Mon-Sat: 08:00 - 21:00, Sun: 09:00 - 15:00',
                            prefixIcon: Icons.access_time_outlined,
                            controller: _openingHoursCtrl,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  if (role == 'delivery_driver') ...[
                    _sectionHeader('2. Courier & Vehicle Profile', Icons.delivery_dining_outlined),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _cardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PharmaField(
                            label: 'Assigned Vehicle Description & Plate',
                            hint: 'e.g. Yamaha 125cc Motorbike (LT 4921-A)',
                            prefixIcon: Icons.two_wheeler,
                            controller: _vehicleInfoCtrl,
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Available for Delivery Requests', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: Text(_driverIsOnline ? '🟢 Online (Receiving nearby pharmacy orders)' : '⚪ Offline', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                            value: _driverIsOnline,
                            activeColor: AppColors.primary,
                            onChanged: (val) => setState(() => _driverIsOnline = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ─── Save Changes Button ──────────────────────────────────────
                  PharmaButton(
                    label: 'Save Profile Changes',
                    onPressed: _save,
                    isLoading: _loading,
                  ),
                  const SizedBox(height: 16),

                  // ─── Privacy Shield Notice ────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.shield_outlined, size: 20, color: AppColors.primary),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'PharmaLink Privacy Shield: Your medical and personal data is encrypted. Sensitive credentials and raw license IDs are securely protected and never exposed to unauthorized parties.',
                            style: TextStyle(fontSize: 11, color: AppColors.textGrey, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ─── Sign Out ─────────────────────────────────────────────────
                  PharmaButton(
                    label: 'Sign Out of Account',
                    outlined: true,
                    onPressed: () async {
                      final nav = Navigator.of(context);
                      await context.read<AuthService>().logout();
                      nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
      ],
    );
  }
}

