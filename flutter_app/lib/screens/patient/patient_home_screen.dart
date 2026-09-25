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
import 'search_medication_screen.dart';
import 'book_appointment_screen.dart';
import 'my_orders_screen.dart';
import 'my_prescriptions_screen.dart';
import 'medical_history_screen.dart';
import 'reminders_screen.dart';
import 'patient_appointments_screen.dart';
import 'chatbot_screen.dart';
import 'night_guard_screen.dart';
import '../shared/conversations_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});
  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> with WidgetsBindingObserver {
  final _api = ApiService();
  int _navIndex = 0;
  Timer? _refreshTimer;
  List<dynamic> _upcomingAppointments = [];
  bool _loadingAppointments = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Refresh immediately on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuthService>().refreshUser();
        _loadUpcomingAppointments();
      }
    });

    // Silent background refresh every 60 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) {
        context.read<AuthService>().refreshUser();
        _loadUpcomingAppointments();
      }
    });
  }

  Future<void> _loadUpcomingAppointments() async {
    try {
      final res = await _api.get('/appointments?role=patient');
      if (res.data['success'] == true && mounted) {
        final list = res.data['data'] as List<dynamic>? ?? [];
        final now = DateTime.now();
        final upcoming = list.where((a) {
          final status = a['status']?.toString();
          if (status == 'cancelled' || status == 'completed') return false;
          try {
            final dt = DateTime.parse(a['appointmentDate']);
            return dt.isAfter(now.subtract(const Duration(hours: 1)));
          } catch (_) {
            return false;
          }
        }).toList();

        setState(() => _upcomingAppointments = upcoming);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AuthService>().refreshUser();
      _loadUpcomingAppointments();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_navIndex == 1) {
      return Scaffold(
        body: const SearchMedicationScreen(),
        bottomNavigationBar: _buildBottomNav(),
      );
    }
    if (_navIndex == 2) {
      return Scaffold(
        body: const PatientAppointmentsScreen(),
        bottomNavigationBar: _buildBottomNav(),
      );
    }
    if (_navIndex == 3) {
      return Scaffold(
        body: const MyOrdersScreen(),
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
    final name = user?['name']?.toString().split(' ').first ?? 'there';

    return Scaffold(
      backgroundColor: const Color(0xFF0A583A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A583A), Color(0xFF064E3B), Color(0xFF0F766E)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Header
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
                        backgroundColor: const Color(0xFF10B981),
                        radius: 20,
                        child: Text(
                          (user?['name'] ?? 'P')[0].toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
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
                            'Hello, $name 👋',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'How are you feeling today?',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withOpacity(0.80),
                              fontSize: 12,
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

              // Content sheet
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
                          // Search Bar
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchMedicationScreen())),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withOpacity(0.04),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Search medications, doctors, pharmacies...',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF94A3B8),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // UPCOMING APPOINTMENT PROMINENT NOTIFICATION CARD
                          if (_upcomingAppointments.isNotEmpty) ...[
                            _buildUpcomingAppointmentsWidget(),
                            const SizedBox(height: 20),
                          ],

                          // Hero Healthcare Promo Banner
                          PromoImageBanner(
                            imagePath: 'assets/images/hero_healthcare_banner.jpg',
                            tag: '24/7 Digital Health',
                            title: 'Quality Healthcare\nRight here in Cameroon',
                            subtitle: 'Consult certified ONMC doctors & get meds delivered.',
                            ctaText: 'Explore Network',
                            onCtaPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const BookAppointmentScreen()),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 🌙 NIGHT GUARD & EMERGENCY QUICK BANNER
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NightGuardScreen())),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFF334155)),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x22000000),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.nightlight_round, color: Color(0xFFFBBF24), size: 22),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Night Guard & Urgences',
                                              style: GoogleFonts.plusJakartaSans(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFDC2626),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '24/7',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          'Pharmacies de garde & On-call doctors open right now',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: const Color(0xFF94A3B8),
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Quick Actions Header
                          const SectionHeader(title: 'Quick Services'),
                          const SizedBox(height: 14),

                          // Grid of Services
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 1.45,
                            children: [
                              _actionCard(
                                Icons.medication_rounded,
                                'Order Medicine',
                                'Official pharmacies',
                                const Color(0xFF0D6E48),
                                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchMedicationScreen())),
                              ),
                              _actionCard(
                                Icons.calendar_today_rounded,
                                'Book Doctor',
                                'ONMC verified specialists',
                                const Color(0xFF0284C7),
                                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookAppointmentScreen())),
                              ),
                              _actionCard(
                                Icons.receipt_long_rounded,
                                'My Prescriptions',
                                'Send Rx to pharmacy',
                                const Color(0xFF7C3AED),
                                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyPrescriptionsScreen())),
                              ),
                              _actionCard(
                                Icons.alarm_on_rounded,
                                'Pill Reminders',
                                'Medication alerts',
                                const Color(0xFFF59E0B),
                                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RemindersScreen())),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Featured Doctor & Pharmacy Sections
                          const SectionHeader(title: 'Specialized Care in Yaoundé'),
                          const SizedBox(height: 12),

                          // Doctor Consultation Banner Card
                          PromoImageBanner(
                            imagePath: 'assets/images/doctor_consultation_scene.jpg',
                            tag: 'ONMC Verified',
                            title: 'Book a Consultation with a Specialist',
                            subtitle: 'General medicine, Cardiology, Pediatrics, & more.',
                            ctaText: 'Book Appointment',
                            onCtaPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const BookAppointmentScreen()),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Express Pharmacy Banner Card
                          PromoImageBanner(
                            imagePath: 'assets/images/pharmacy_store_banner.jpg',
                            tag: 'ONPC Approved',
                            title: 'Order Direct from City Pharmacies',
                            subtitle: 'Guaranteed authentic medication with secure batch tracing.',
                            ctaText: 'Browse Catalog',
                            onCtaPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SearchMedicationScreen()),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // AI Health Assistant Interactive Card
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatbotScreen())),
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF0284C7)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF047857).withOpacity(0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 28),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'PharmaLink AI Health Assistant',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Ask about symptoms, drug dosages, or local care',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white.withOpacity(0.85),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                                ],
                              ),
                            ),
                          ),
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
        BottomNavigationBarItem(icon: Icon(Icons.medication_outlined), activeIcon: Icon(Icons.medication_rounded), label: 'Medications'),
        BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today_rounded), label: 'Appointments'),
        BottomNavigationBarItem(icon: Icon(Icons.shopping_bag_outlined), activeIcon: Icon(Icons.shopping_bag_rounded), label: 'Orders'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), activeIcon: Icon(Icons.person_rounded), label: 'Profile'),
      ],
    );
  }

  Widget _actionCard(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
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
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingAppointmentsWidget() {
    final apt = _upcomingAppointments.first as Map<String, dynamic>;
    final doctor = apt['doctor'] as Map<String, dynamic>? ?? {};
    final profile = doctor['doctorProfile'] as Map<String, dynamic>? ?? {};
    final docName = doctor['name'] != null
        ? (doctor['name'].toString().startsWith('Dr.') ? doctor['name'] : 'Dr. ${doctor['name']}')
        : 'Dr. Specialist';
    final specialty = profile['specialty'] ?? 'General Practitioner';
    final hospital = apt['hospital'] ?? profile['hospital'] ?? 'Hôpital Central de Yaoundé';
    final isTelemedicine = apt['type'] == 'telemedicine';

    DateTime? aptDate;
    try {
      aptDate = DateTime.parse(apt['appointmentDate']).toLocal();
    } catch (_) {}

    final formattedDate = aptDate != null
        ? '${aptDate.day}/${aptDate.month}/${aptDate.year} at ${aptDate.hour.toString().padLeft(2, '0')}:${aptDate.minute.toString().padLeft(2, '0')}'
        : 'Upcoming';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF0D6E48)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D6E48).withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.alarm_on_rounded, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'UPCOMING APPOINTMENT',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  apt['status']?.toString().toUpperCase() ?? 'CONFIRMED',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      docName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '$specialty • $hospital',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.85),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  isTelemedicine ? Icons.videocam_rounded : Icons.location_on_rounded,
                  color: const Color(0xFFFDE047),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isTelemedicine ? '📱 Telemedicine Video Consultation' : '🏥 In-Person at $hospital',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  formattedDate,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFDE047),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PatientAppointmentsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.calendar_month_rounded, size: 16),
                  label: const Text('View All Appointments'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(0, 38),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
