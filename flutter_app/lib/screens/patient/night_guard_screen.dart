import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../shared/payment_screen.dart';
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
                    flex: 3,
                    child: ElevatedButton.icon(
                      onPressed: () => _showNightOrderSheet(ph),
                      icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                      label: const Text('Order Emergency Drugs'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 42),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _makeCall(ph['phone'] ?? '+237600000000'),
                    icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF34D399), size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFF334155)),
                      ),
                      padding: const EdgeInsets.all(10),
                    ),
                    tooltip: 'Call Pharmacy',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNightOrderSheet(Map<String, dynamic> ph) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NightOrderModal(pharmacy: ph),
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

class _NightOrderModal extends StatefulWidget {
  final Map<String, dynamic> pharmacy;

  const _NightOrderModal({required this.pharmacy});

  @override
  State<_NightOrderModal> createState() => _NightOrderModalState();
}

class _NightOrderModalState extends State<_NightOrderModal> {
  final _addressCtrl = TextEditingController(text: 'Quartier Bastos, Yaoundé');
  String _orderType = 'delivery';
  List<Map<String, dynamic>> _meds = [];
  String? _selectedMedId;
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    final rawMeds = widget.pharmacy['featuredMeds'] as List? ?? [];
    if (rawMeds.isNotEmpty) {
      _meds = rawMeds.map((m) => Map<String, dynamic>.from(m as Map)).toList();
    } else {
      _meds = [
        {'id': 'med-para-500', 'name': 'Paracetamol 500mg', 'priceFcfa': 1200, 'category': 'Pain Relief', 'requiresPrescription': false, 'stockQuantity': 50},
        {'id': 'med-coartem', 'name': 'Coartem (ACT Antimalarial)', 'priceFcfa': 2200, 'category': 'Antimalarial', 'requiresPrescription': false, 'stockQuantity': 40},
        {'id': 'med-ibu-400', 'name': 'Ibuprofen 400mg', 'priceFcfa': 1400, 'category': 'Pain Relief', 'requiresPrescription': false, 'stockQuantity': 35},
        {'id': 'med-amox-500', 'name': 'Amoxicillin 500mg', 'priceFcfa': 2500, 'category': 'Antibiotics', 'requiresPrescription': true, 'stockQuantity': 30},
      ];
    }
    if (_meds.isNotEmpty) {
      _selectedMedId = _meds.first['id'].toString();
    }
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _currentMed {
    if (_selectedMedId == null) return _meds.isNotEmpty ? _meds.first : null;
    return _meds.firstWhere((m) => m['id'].toString() == _selectedMedId, orElse: () => _meds.first);
  }

  double get _subtotal {
    final med = _currentMed;
    if (med == null) return 0;
    final price = double.tryParse(med['priceFcfa'].toString()) ?? 0;
    return price * _qty;
  }

  double get _deliveryFee => _orderType == 'delivery' ? 1000 : 0;
  double get _total => _subtotal + _deliveryFee;

  void _proceedToCheckout() {
    final med = _currentMed;
    if (med == null) return;

    final pharmacyId = widget.pharmacy['id']?.toString() ?? '';

    Navigator.pop(context);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          orderId: null,
          orderType: _orderType,
          pharmacyId: pharmacyId,
          items: [
            {
              'medicationId': med['id'].toString(),
              'quantity': _qty,
            }
          ],
          totalFcfa: _total,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF475569),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.nightlight_round, color: Color(0xFF34D399), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Night Order — ${widget.pharmacy['pharmacyName'] ?? 'Pharmacy'}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '📍 ${widget.pharmacy['pharmacyAddress'] ?? 'Yaoundé'}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF334155)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1. Select In-Stock Medication',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._meds.map((m) {
                    final isSelected = m['id'].toString() == _selectedMedId;
                    final isRx = m['requiresPrescription'] == true;
                    final price = double.tryParse(m['priceFcfa'].toString()) ?? 0;

                    return InkWell(
                      onTap: () => setState(() => _selectedMedId = m['id'].toString()),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF0F766E).withOpacity(0.25) : const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF14B8A6) : const Color(0xFF334155),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: isSelected ? const Color(0xFF34D399) : const Color(0xFF64748B),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m['name'] ?? '',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        'FCFA ${price.toStringAsFixed(0)}',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: const Color(0xFF34D399),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isRx ? const Color(0xFF7F1D1D) : const Color(0xFF065F46),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isRx ? 'Rx Required' : 'OTC 🟢',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: isRx ? const Color(0xFFFCA5A5) : const Color(0xFF6EE7B7),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quantity / Boxes',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFE2E8F0),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, color: Colors.white, size: 16),
                              onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                            ),
                            Text(
                              '$_qty',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, color: Colors.white, size: 16),
                              onPressed: _qty < 10 ? () => setState(() => _qty++) : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF334155)),
                  const SizedBox(height: 12),
                  Text(
                    '2. Choose Fulfillment Mode',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _orderType = 'delivery'),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _orderType == 'delivery' ? const Color(0xFF0F766E).withOpacity(0.3) : const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _orderType == 'delivery' ? const Color(0xFF14B8A6) : const Color(0xFF334155),
                                width: _orderType == 'delivery' ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.moped_rounded, color: Color(0xFF34D399), size: 24),
                                const SizedBox(height: 6),
                                Text(
                                  'Express Delivery',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '+ FCFA 1,000',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _orderType = 'pickup'),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _orderType == 'pickup' ? const Color(0xFF0F766E).withOpacity(0.3) : const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _orderType == 'pickup' ? const Color(0xFF14B8A6) : const Color(0xFF334155),
                                width: _orderType == 'pickup' ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.storefront_rounded, color: Color(0xFF38BDF8), size: 24),
                                const SizedBox(height: 6),
                                Text(
                                  'Pharmacy Pickup',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Free (15 mins)',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_orderType == 'delivery') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addressCtrl,
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Night Delivery Address / Neighborhood',
                        labelStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 12),
                        prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF34D399), size: 18),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF334155)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Medication Subtotal:', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 13)),
                      Text('FCFA ${_subtotal.toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Night Fulfillment Fee:', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 13)),
                      Text(_deliveryFee > 0 ? 'FCFA ${_deliveryFee.toStringAsFixed(0)}' : 'FREE', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF34D399), fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total to Pay:', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(
                        'FCFA ${_total.toStringAsFixed(0)}',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF34D399),
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(top: BorderSide(color: Color(0xFF334155))),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _proceedToCheckout,
                  icon: const Icon(Icons.payment_rounded, size: 18),
                  label: Text('Proceed to Checkout (FCFA ${_total.toStringAsFixed(0)})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
