import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';
import '../shared/payment_screen.dart';
import 'book_appointment_screen.dart';

class PharmacyDetailScreen extends StatefulWidget {
  final String pharmacyId;
  final String medicationId;
  const PharmacyDetailScreen({super.key, required this.pharmacyId, required this.medicationId});
  @override
  State<PharmacyDetailScreen> createState() => _PharmacyDetailScreenState();
}

class _PharmacyDetailScreenState extends State<PharmacyDetailScreen> {
  final _api = ApiService();
  Map? _pharmacy;
  Map? _medication;
  bool _loading = true;
  int _qty = 1;

  List<dynamic> _patientPrescriptions = [];
  String? _selectedPrescriptionId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r1 = await _api.get('/pharmacies/${widget.pharmacyId}');
      final r2 = await _api.get('/medications/${widget.medicationId}');

      setState(() {
        _pharmacy = r1.data['data'];
        _medication = r2.data['data'];
      });

      // prescriptions are optional – ignore any error
      try {
        final r3 = await _api.get('/prescriptions');
        if (r3.data['success'] == true) {
          setState(() {
            _patientPrescriptions = r3.data['data'] as List<dynamic>? ?? [];
          });
        }
      } catch (_) {}
    } catch (_) {} finally {
      setState(() => _loading = false);
    }
  }

  void _showOrderOptions() {
    final requiresRx = _medication?['requiresPrescription'] == true;

    if (requiresRx) {
      if (_patientPrescriptions.isEmpty) {
        _showPrescriptionRequiredDialog();
        return;
      } else {
        _showPrescriptionSelectionSheet('delivery');
        return;
      }
    }

    _showDeliveryMethodSheet(null);
  }

  void _showPrescriptionRequiredDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_rounded, color: Color(0xFFDC2626), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Prescription Required',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_medication?['name'] ?? 'This medication'} is classified as a regulated prescription drug under Cameroon ONPC regulations.',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You do not currently have an active doctor prescription for this drug in your record.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFF1E40AF)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BookAppointmentScreen()),
              );
            },
            icon: const Icon(Icons.medical_services_rounded, size: 16),
            label: const Text('Consult Doctor'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _showPrescriptionSelectionSheet(String orderType) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Select Verified Doctor Prescription',
                  style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Attach an authorized prescription issued by a certified doctor.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textGrey),
            ),
            const SizedBox(height: 16),
            ..._patientPrescriptions.map((p) {
              final doc = p['doctor'] as Map<String, dynamic>? ?? {};
              final docName = doc['name'] != null ? 'Dr. ${doc['name']}' : 'Certified Doctor';
              final dateStr = p['createdAt'] != null ? p['createdAt'].toString().split('T')[0] : 'Recent';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFF0FDF4),
                ),
                child: ListTile(
                  leading: const Icon(Icons.verified_rounded, color: Color(0xFF10B981)),
                  title: Text(
                    'Prescription from $docName',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('Issued: $dateStr • Status: ${p['status'] ?? 'Active'}'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeliveryMethodSheet(p['id'].toString());
                  },
                ),
              );
            }),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Center(child: Text('Cancel', style: TextStyle(color: AppColors.textGrey))),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeliveryMethodSheet(String? prescriptionId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Fulfillment Method',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _orderOption(Icons.delivery_dining, 'Doorstep Courier Delivery', 'Pay online → Express courier delivery', () {
              Navigator.pop(context);
              _placeOrder('delivery', prescriptionId);
            }),
            const SizedBox(height: 12),
            _orderOption(Icons.store_outlined, 'Counter Pickup at Pharmacy', 'Ready in 15 mins with QR pickup code', () {
              Navigator.pop(context);
              _placeOrder('pickup', prescriptionId);
            }),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Center(child: Text('Cancel', style: TextStyle(color: AppColors.textGrey))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderOption(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: AppColors.lightGreen, width: 1.5), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.lightGreen, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.primary, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
          ])),
          const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textGrey),
        ]),
      ),
    );
  }

  Future<void> _placeOrder(String type, [String? prescriptionId]) async {
    if (_medication == null || _pharmacy == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentScreen(
      orderId: null,
      orderType: type,
      pharmacyId: widget.pharmacyId,
      items: [{'medicationId': widget.medicationId, 'quantity': _qty}],
      totalFcfa: (double.tryParse(_medication!['priceFcfa'].toString()) ?? 0) * _qty,
      prescriptionId: prescriptionId,
    )));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    if (_pharmacy == null) return const Scaffold(body: Center(child: Text('Pharmacy not found')));

    final requiresRx = _medication?['requiresPrescription'] == true;

    return Scaffold(
      appBar: AppBar(title: Text(_pharmacy!['pharmacyName'] ?? 'Pharmacy')),
      body: SingleChildScrollView(
        child: Column(children: [
          Container(height: 160, color: AppColors.lightGreen,
            child: Center(child: Icon(Icons.local_pharmacy, size: 60, color: AppColors.primary))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_pharmacy!['pharmacyName'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.star, color: Colors.amber, size: 16),
                const Text(' 4.8 (128 reviews)', style: TextStyle(fontSize: 12)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.location_on_outlined, color: AppColors.textGrey, size: 14),
                Expanded(child: Text(_pharmacy!['pharmacyAddress'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textGrey))),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.access_time_outlined, color: AppColors.accent, size: 14),
                Text(' ${_pharmacy!['openingHours'] ?? 'Open'}', style: const TextStyle(fontSize: 12, color: AppColors.accent)),
              ]),
              const Divider(height: 28),
              if (_medication != null) ...[
                const Text('Medication Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(
                    child: Text(
                      _medication!['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  Text('FCFA ${_medication!['priceFcfa']}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16)),
                ]),
                const SizedBox(height: 8),

                // Prescription vs OTC Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(6)),
                      child: Text('In Stock (${_medication!['stockQuantity']})', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: requiresRx ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: requiresRx ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            requiresRx ? Icons.lock_outline_rounded : Icons.check_circle_outline_rounded,
                            size: 13,
                            color: requiresRx ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            requiresRx ? 'Requires Prescription' : 'OTC / Free Sale',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: requiresRx ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(children: [
                  const Text('Quantity:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.remove_circle_outline, color: AppColors.primary), onPressed: () { if (_qty > 1) setState(() => _qty--); }),
                  Text('$_qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  IconButton(icon: const Icon(Icons.add_circle_outline, color: AppColors.primary), onPressed: () => setState(() => _qty++)),
                ]),
              ],
              const SizedBox(height: 20),
              PharmaButton(
                label: 'Order for Delivery',
                onPressed: _showOrderOptions,
                icon: Icons.delivery_dining,
              ),
              const SizedBox(height: 10),
              PharmaButton(
                label: 'Pay Online & Pick Up',
                onPressed: () {
                  if (requiresRx) {
                    if (_patientPrescriptions.isEmpty) {
                      _showPrescriptionRequiredDialog();
                    } else {
                      _showPrescriptionSelectionSheet('pickup');
                    }
                  } else {
                    _placeOrder('pickup');
                  }
                },
                outlined: true,
                icon: Icons.store_outlined,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

