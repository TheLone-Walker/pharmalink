import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import 'book_appointment_screen.dart';

class NightGuardScreen extends StatefulWidget {
  const NightGuardScreen({super.key});

  @override
  State<NightGuardScreen> createState() => _NightGuardScreenState();
}

class _NightGuardScreenState extends State<NightGuardScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tab;
  bool _loading = true;
  List<dynamic> _guardPharmacies = [];
  List<dynamic> _emergencyDoctors = [];
  List<dynamic> _hotlines = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/medications/night-guard');
      if (res.data['success'] == true) {
        final data = res.data['data'] as Map<String, dynamic>;
        setState(() {
          _guardPharmacies = data['guardPharmacies'] ?? [];
          _emergencyDoctors = data['emergencyDoctors'] ?? [];
          _hotlines = data['emergencyHotlines'] ?? [];
        });
      }
    } catch (_) {} finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _makeCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    } catch (_) {}

    // Fallback: Copy to clipboard if dialing cannot be launched (e.g. web browser)
    await Clipboard.setData(ClipboardData(text: cleanPhone));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Phone number copied to clipboard: $cleanPhone'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2541),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.nightlight_round, color: Color(0xFFFBBF24), size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Night Guard & Urgences 24/7',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Pharmacies & Doctors on Night Duty',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF94A3B8),
          indicatorColor: const Color(0xFF10B981),
          indicatorWeight: 3,
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: '🌙 Pharmacies de Garde', icon: Icon(Icons.local_pharmacy_rounded, size: 18)),
            Tab(text: '👨‍⚕️ Emergency Doctors', icon: Icon(Icons.medical_services_rounded, size: 18)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : Column(
              children: [
                // Top Emergency Hotline Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: const Color(0xFF991B1B),
                  child: Row(
                    children: [
                      const Icon(Icons.emergency_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'SAMU Urgence Médicale Cameroun: 119 ou 15 (Appel Gratuit)',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => _makeCall('119'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'CALL',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF991B1B),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _buildPharmaciesTab(),
                      _buildDoctorsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPharmaciesTab() {
    if (_guardPharmacies.isEmpty) {
      return Center(
        child: Text(
          'No night guard pharmacies found.',
          style: GoogleFonts.plusJakartaSans(color: Colors.white70),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _guardPharmacies.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final ph = _guardPharmacies[i] as Map<String, dynamic>;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2541),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(Icons.local_pharmacy_rounded, color: Color(0xFF34D399), size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ph['pharmacyName'] ?? 'Pharmacie',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          ph['pharmacyAddress'] ?? 'Yaoundé',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF065F46),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'GARDE 24/7',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF6EE7B7),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: Color(0xFF94A3B8), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${ph['distanceKm'] ?? 1.2} km away',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFCBD5E1),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, color: Color(0xFF94A3B8), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        ph['pharmacistName'] ?? 'Pharmacien',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFCBD5E1),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _makeCall(ph['phone'] ?? '+237600000000'),
                      icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                      label: Text('Call Pharmacy (${ph['phone'] ?? 'Dial'})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 42),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDoctorsTab() {
    if (_emergencyDoctors.isEmpty) {
      return Center(
        child: Text(
          'No emergency doctors currently on-call.',
          style: GoogleFonts.plusJakartaSans(color: Colors.white70),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _emergencyDoctors.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final doc = _emergencyDoctors[i] as Map<String, dynamic>;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2541),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF3B82F6),
                    child: Text(
                      (doc['name'] ?? 'D')[0].toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
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
                              doc['name'] ?? 'Doctor',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF38BDF8)),
                          ],
                        ),
                        Text(
                          doc['specialty'] ?? 'General Medicine',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF38BDF8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          doc['hospital'] ?? 'Hôpital Central',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF94A3B8),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ON CALL',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF93C5FD),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _makeCall(doc['phone'] ?? '+237600000000'),
                      icon: const Icon(Icons.phone_rounded, size: 16),
                      label: const Text('Call Direct'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF475569)),
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BookAppointmentScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.videocam_rounded, size: 16),
                      label: const Text('Consult Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
