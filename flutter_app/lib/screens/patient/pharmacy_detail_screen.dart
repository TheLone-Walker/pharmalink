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
  String? _selectedPrescriptionId;
  String? _attachedPrescriptionName;

  List<dynamic> _patientPrescriptions = [];

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

      try {
        final r3 = await _api.get('/prescriptions');
        if (r3.data['success'] == true) {
          setState(() {
            _patientPrescriptions = r3.data['data'] as List<dynamic>? ?? [];
          });
        }
      } catch (_) {}
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _prescriptionMatchesMedication(Map<String, dynamic> prescription, String medName) {
    final medLower = medName.toLowerCase().trim();
    final baseName = medLower.split(' ')[0]; // e.g. "amoxicillin", "artemether"
    
    final items = (prescription['items'] as List? ?? []);
    final notes = (prescription['notes']?.toString() ?? '').toLowerCase();

    for (final item in items) {
      final itemName = (item['medicationName']?.toString() ?? '').toLowerCase();
      if (itemName.contains(medLower) || medLower.contains(itemName) || (baseName.length >= 4 && itemName.contains(baseName))) {
        return true;
      }
    }
    if (notes.contains(medLower) || (baseName.length >= 4 && notes.contains(baseName))) {
      return true;
    }
    return false;
  }

  bool _isRxRequired() {
    if (_medication == null) return false;
    return _medication!['requiresPrescription'] == true ||
        _medication!['requires_prescription'] == true ||
        _medication!['requiresPrescription'] == 1 ||
        _medication!['rx'] == true ||
        (_medication!['category']?.toString().toLowerCase().contains('prescription') ?? false);
  }

  void _showOrderOptions() {
    final requiresRx = _isRxRequired();

    if (requiresRx && _selectedPrescriptionId == null) {
      _showPrescriptionSelectionSheet('delivery');
      return;
    }

    _showDeliveryMethodSheet(_selectedPrescriptionId);
  }



  void _showPrescriptionSelectionSheet(String orderType) {
    final medName = _medication?['name'] ?? 'Medication';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Color(0xFFFEE2E2), shape: BoxShape.circle),
                      child: const Icon(Icons.shield_rounded, color: Color(0xFFDC2626), size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Doctor Digital Prescription Required',
                            style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Regulated drug: $medName',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textGrey, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(height: 20),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Only official digital prescriptions issued by certified doctors are accepted. The prescription must explicitly prescribe "$medName".',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFF92400E), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Select Your Doctor\'s Digital Prescription:',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
                const SizedBox(height: 10),

                if (_patientPrescriptions.isEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.receipt_long_outlined, color: AppColors.textGrey, size: 40),
                        const SizedBox(height: 10),
                        Text(
                          'No Doctor Digital Prescriptions Found',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You do not have any active doctor prescriptions on file. Please consult a certified ONMC doctor online to receive a digital prescription for $medName.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textGrey),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.medical_services_rounded, size: 16),
                          label: const Text('Consult ONMC Doctor Online', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const BookAppointmentScreen()));
                          },
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  ..._patientPrescriptions.map((p) {
                    final mapP = Map<String, dynamic>.from(p as Map);
                    final doc = mapP['doctor'] as Map<String, dynamic>? ?? {};
                    final docName = doc['name'] != null ? 'Dr. ${doc['name']}' : 'Certified Doctor';
                    final dateStr = mapP['createdAt'] != null ? mapP['createdAt'].toString().split('T')[0] : 'Recent';
                    final isMatch = _prescriptionMatchesMedication(mapP, medName);
                    final rxItems = (mapP['items'] as List? ?? []).map((i) => i['medicationName']?.toString() ?? '').join(', ');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isMatch ? const Color(0xFF10B981) : const Color(0xFFFCA5A5),
                          width: isMatch ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        color: isMatch ? const Color(0xFFF0FDF4) : const Color(0xFFFFF1F2),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        leading: Icon(
                          isMatch ? Icons.verified_rounded : Icons.cancel_outlined,
                          color: isMatch ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                          size: 26,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Rx from $docName',
                                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isMatch ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isMatch ? '✓ Verified: Prescribed for $medName' : '🚫 Mismatch: Unrelated Rx',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: isMatch ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text('Prescribed Items: ${rxItems.isNotEmpty ? rxItems : "None"} • Date: $dateStr',
                                style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                          ],
                        ),
                        trailing: isMatch
                            ? const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF10B981))
                            : const Icon(Icons.block, size: 16, color: Color(0xFFDC2626)),
                        onTap: () {
                          if (!isMatch) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('🚫 Prescription Rejected: This prescription from $docName does not contain "$medName". You cannot use an unrelated prescription to purchase this drug.'),
                                backgroundColor: const Color(0xFFDC2626),
                                duration: const Duration(seconds: 4),
                              ),
                            );
                            return;
                          }

                          setState(() {
                            _selectedPrescriptionId = mapP['id'].toString();
                            _attachedPrescriptionName = 'Digital Rx from $docName';
                          });
                          Navigator.pop(ctx);
                          _showDeliveryMethodSheet(_selectedPrescriptionId);
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.medical_services_outlined, size: 16),
                      label: const Text('Consult an ONMC Doctor to get a new prescription'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const BookAppointmentScreen()));
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeliveryMethodSheet(String? prescriptionId) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: AppColors.lightGreen, shape: BoxShape.circle),
                      child: const Icon(Icons.local_shipping_outlined, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Select Fulfillment Method',
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(height: 20),
                _orderOption(Icons.delivery_dining, 'Doorstep Courier Delivery', 'Pay online → Express courier delivery with Live QR confirmation', () {
                  Navigator.pop(ctx);
                  _placeOrder('delivery', prescriptionId);
                }),
                const SizedBox(height: 12),
                _orderOption(Icons.store_outlined, 'Counter Pickup at Pharmacy', 'Ready in 15 mins with QR pickup code', () {
                  Navigator.pop(ctx);
                  _placeOrder('pickup', prescriptionId);
                }),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
                  ),
                ),
              ],
            ),
          ),
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
          Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: AppColors.lightGreen, shape: BoxShape.circle),
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
      items: [{
        'medicationId': widget.medicationId,
        'quantity': _qty,
        'medicationName': _medication!['name'],
        'requiresPrescription': _isRxRequired(),
      }],
      totalFcfa: (double.tryParse(_medication!['priceFcfa'].toString()) ?? 0) * _qty,
      prescriptionId: prescriptionId ?? _selectedPrescriptionId,
    )));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    if (_pharmacy == null) return const Scaffold(body: Center(child: Text('Pharmacy not found')));

    final requiresRx = _isRxRequired();

    return Scaffold(
      appBar: AppBar(title: Text(_pharmacy!['pharmacyName'] ?? 'Pharmacy')),
      body: SingleChildScrollView(
        child: Column(children: [
          Container(height: 160, color: AppColors.lightGreen,
            child: const Center(child: Icon(Icons.local_pharmacy, size: 60, color: AppColors.primary))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_pharmacy!['pharmacyName'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Row(children: const [
                Icon(Icons.star, color: Colors.amber, size: 16),
                Text(' 4.8 (128 reviews)', style: TextStyle(fontSize: 12)),
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

                // Inline Doctor Prescription Upload & Verification Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _selectedPrescriptionId != null
                        ? const Color(0xFFF0FDF4)
                        : (requiresRx ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _selectedPrescriptionId != null
                          ? const Color(0xFF86EFAC)
                          : (requiresRx ? const Color(0xFFFCD34D) : const Color(0xFFE2E8F0)),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _selectedPrescriptionId != null
                                  ? const Color(0xFFDCFCE7)
                                  : (requiresRx ? const Color(0xFFFEF3C7) : const Color(0xFFE2E8F0)),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _selectedPrescriptionId != null
                                  ? Icons.verified_rounded
                                  : (requiresRx ? Icons.file_present_rounded : Icons.medical_information_outlined),
                              color: _selectedPrescriptionId != null
                                  ? const Color(0xFF16A34A)
                                  : (requiresRx ? const Color(0xFFD97706) : AppColors.primary),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedPrescriptionId != null
                                      ? 'Doctor Digital Rx Verified & Attached'
                                      : (requiresRx ? 'Digital Doctor Prescription Required' : 'Doctor Digital Rx (Optional)'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedPrescriptionId != null
                                        ? const Color(0xFF166534)
                                        : (requiresRx ? const Color(0xFF92400E) : AppColors.textDark),
                                  ),
                                ),
                                Text(
                                  _selectedPrescriptionId != null
                                      ? (_attachedPrescriptionName ?? 'Rx verified and attached to order')
                                      : (requiresRx
                                          ? 'Select an official digital prescription issued by your doctor for this medication.'
                                          : 'You can attach an official doctor prescription for your medical records.'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    color: _selectedPrescriptionId != null
                                        ? const Color(0xFF15803D)
                                        : (requiresRx ? const Color(0xFFB45309) : AppColors.textGrey),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_selectedPrescriptionId != null)
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                              tooltip: 'Remove Prescription',
                              onPressed: () {
                                setState(() {
                                  _selectedPrescriptionId = null;
                                  _attachedPrescriptionName = null;
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _selectedPrescriptionId != null ? const Color(0xFF0F172A) : AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.receipt_long_rounded, size: 18, color: Colors.white),
                              label: Text(
                                _selectedPrescriptionId != null ? 'Change Digital Rx' : 'Select Doctor Digital Rx',
                                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                              onPressed: () => _showPrescriptionSelectionSheet('delivery'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.medical_services_outlined, size: 16),
                            label: Text(
                              'Consult Doctor',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const BookAppointmentScreen()));
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
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
                  if (requiresRx && _selectedPrescriptionId == null) {
                    _showPrescriptionSelectionSheet('pickup');
                  } else {
                    _placeOrder('pickup', _selectedPrescriptionId);
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
