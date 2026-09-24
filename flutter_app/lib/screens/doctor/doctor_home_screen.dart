import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/logout_button.dart';
import '../shared/notifications_screen.dart';
import '../shared/conversations_screen.dart';
import 'my_patients_screen.dart';
import 'doctor_appointments_screen.dart';
import 'write_prescription_screen.dart';
import '../../services/socket_service.dart';
import 'doctor_upload_license_screen.dart';
import 'set_availability_screen.dart';

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});
  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> with WidgetsBindingObserver {
  int _navIndex = 0;
  final _api = ApiService();
  final _socket = SocketService();
  List _todayAppointments = [];
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _socket.onAppointmentNew(_onSocketApt);
    _socket.onAppointmentUpdated(_onSocketApt);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthService>().refreshUser();
    });

    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) context.read<AuthService>().refreshUser();
    });
  }

  void _onSocketApt(dynamic data) {
    if (mounted) {
      _load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _socket.removeListener('appointment:new', _onSocketApt);
    _socket.removeListener('appointment:updated', _onSocketApt);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AuthService>().refreshUser();
    }
  }

  Future<void> _load() async {
    try {
      final res = await _api.get('/appointments');
      final all = res.data['data'] as List? ?? [];
      final today = DateTime.now();
      if (mounted) {
        setState(() => _todayAppointments = all.where((a) {
          final d = DateTime.tryParse(a['appointmentDate'] ?? '');
          return d != null && d.year == today.year && d.month == today.month && d.day == today.day;
        }).toList());
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_navIndex == 1) {
      return Scaffold(
        body: const MyPatientsScreen(),
        bottomNavigationBar: _buildBottomNav(),
      );
    }
    if (_navIndex == 2) {
      return Scaffold(
        body: const DoctorAppointmentsScreen(),
        bottomNavigationBar: _buildBottomNav(),
      );
    }
    if (_navIndex == 3) {
      return Scaffold(
        body: const ConversationsScreen(),
        bottomNavigationBar: _buildBottomNav(),
      );
    }
    if (_navIndex == 4) {
      return Scaffold(
        body: const ProfileScreen(),
        bottomNavigationBar: _buildBottomNav(),
      );
    }

    final user = context.watch<AuthService>().user;
    final docProfile = user?['doctorProfile'];
    final name = user?['name'] ?? 'Doctor';
    final specialty = docProfile?['specialty'] ?? 'General Practitioner';
    final approvalStatus = docProfile?['approvalStatus'] ?? 'pending';
    final isApproved = approvalStatus == 'approved';
    final isRejected = approvalStatus == 'rejected';
    final licenseNo = docProfile?['licenseNumber'] ?? '';
    final rejectionReason = docProfile?['rejectionReason'];

    return Scaffold(
      backgroundColor: const Color(0xFF0A583A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A583A), Color(0xFF064E3B), Color(0xFF0284C7)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                      ),
                      child: CircleAvatar(
                        backgroundColor: const Color(0xFF0284C7),
                        radius: 20,
                        child: Text(
                          'Dr',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.startsWith('Dr.') ? name : 'Dr. $name',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            specialty,
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white.withOpacity(0.85)),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isApproved
                                  ? const Color(0xFF10B981).withOpacity(0.3)
                                  : (isRejected ? Colors.redAccent.withOpacity(0.3) : Colors.amberAccent.withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isApproved ? '✓ ONMC VERIFIED' : (isRejected ? '✕ VERIFICATION REJECTED' : '⏳ ONMC PENDING REVIEW'),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConversationsScreen())),
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const HeaderLogoutButton(),
                  ],
                ),
              ),

              // White Content Sheet
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x1F000000),
                        blurRadius: 20,
                        offset: Offset(0, -6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Verification Alert Banner if not approved
                          if (!isApproved)
                            Container(
                              margin: const EdgeInsets.only(bottom: 18),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isRejected ? Colors.red.withOpacity(0.08) : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isRejected ? Colors.red.withOpacity(0.3) : Colors.orange.withOpacity(0.3)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(isRejected ? Icons.error_outline : Icons.hourglass_empty, color: isRejected ? Colors.red : Colors.orange, size: 22),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isRejected ? 'ONMC License Verification Rejected' : 'License Verification In Progress',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: isRejected ? Colors.red : Colors.orange,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isRejected
                                              ? 'Reason: ${rejectionReason ?? 'Document mismatch'}. Tap below to update your license.'
                                              : 'Your license #$licenseNo is under admin review with official ONMC registry records.',
                                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.black87),
                                        ),
                                        const SizedBox(height: 10),
                                        SizedBox(
                                          height: 34,
                                          child: ElevatedButton.icon(
                                            icon: const Icon(Icons.upload_file_rounded, size: 16),
                                            label: Text(
                                              isRejected ? 'Re-upload License Document' : 'View / Update License',
                                              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700),
                                            ),
                                            onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => DoctorUploadLicenseScreen(
                                                  initialLicenseNumber: licenseNo,
                                                  rejectionReason: rejectionReason,
                                                  approvalStatus: approvalStatus,
                                                ),
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isRejected ? Colors.red : AppColors.primary,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Doctor Consultation Hero Banner
                          PromoImageBanner(
                            imagePath: 'assets/images/doctor_consultation_scene.jpg',
                            tag: 'Clinical Workspace',
                            title: 'Digital Prescriptions & Consultation Workspace',
                            subtitle: 'Issue official e-prescriptions directly linked to Yaoundé pharmacies.',
                            ctaText: 'Write Prescription',
                            onCtaPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const WritePrescriptionScreen()),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Quick actions
                          const SectionHeader(title: 'Doctor Portal Actions'),
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 1.45,
                            children: [
                              _actionCard(
                                Icons.people_rounded,
                                'My Patients',
                                'Patient clinical records',
                                const Color(0xFF0D6E48),
                                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyPatientsScreen())),
                              ),
                              _actionCard(
                                Icons.calendar_today_rounded,
                                'Appointments',
                                "Today's patient queue",
                                const Color(0xFF0284C7),
                                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DoctorAppointmentsScreen())),
                              ),
                              _actionCard(
                                Icons.medical_services_rounded,
                                'Consult & Prescribe',
                                'Rx & Diagnosis',
                                const Color(0xFF7C3AED),
                                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WritePrescriptionScreen())),
                              ),
                              _actionCard(
                                Icons.badge_rounded,
                                'ONMC License',
                                isApproved ? 'Verified status' : 'Review credentials',
                                const Color(0xFFF59E0B),
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DoctorUploadLicenseScreen(
                                      initialLicenseNumber: licenseNo,
                                      rejectionReason: rejectionReason,
                                      approvalStatus: approvalStatus,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          const SectionHeader(title: "Today's Patient Schedule"),
                          const SizedBox(height: 12),
                          if (_loading)
                            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.primary)))
                          else if (_todayAppointments.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Center(
                                child: Text(
                                  'No appointments scheduled for today',
                                  style: GoogleFonts.plusJakartaSans(color: AppColors.textGrey, fontSize: 13),
                                ),
                              ),
                            )
                          else
                            ..._todayAppointments.map((a) => _appointmentTile(a)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return PharmaBottomNav(
      currentIndex: _navIndex,
      onTap: (i) => setState(() => _navIndex = i),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.people_outline_rounded), activeIcon: Icon(Icons.people_rounded), label: 'Patients'),
        BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today_rounded), label: 'Appointments'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline_rounded), activeIcon: Icon(Icons.chat_bubble_rounded), label: 'Messages'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), activeIcon: Icon(Icons.person_rounded), label: 'Profile'),
      ],
    );
  }

  Widget _actionCard(IconData icon, String title, String sub, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.textGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appointmentTile(Map a) {
    final time = a['appointmentDate'] != null ? DateTime.tryParse(a['appointmentDate']) : null;
    final patientId = a['patientId'] ?? a['patient']?['id'];
    final patientName = a['patient']?['name'] ?? 'Patient';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WritePrescriptionScreen(
              patientId: patientId,
              patientName: patientName,
              appointmentId: a['id'],
            ),
          ),
        ).then((_) => _load());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFEEEEEE)),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
        child: Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text(time != null ? '${time.hour.toString().padLeft(2,'0')}:${time.minute.toString().padLeft(2,'0')}' : '--',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(patientName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text(a['type'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(6)),
            child: Text(a['status'] ?? '', style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textGrey),
        ]),
      ),
    );
  }
}
