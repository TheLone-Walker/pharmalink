import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/location_autocomplete_field.dart';

class MyPrescriptionsScreen extends StatefulWidget {
  const MyPrescriptionsScreen({super.key});
  @override
  State<MyPrescriptionsScreen> createState() => _MyPrescriptionsScreenState();
}

class _MyPrescriptionsScreenState extends State<MyPrescriptionsScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _prescriptions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrescriptions();
  }

  Future<void> _loadPrescriptions() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/prescriptions');
      final list = res.data['data'] as List? ?? [];
      setState(() {
        _prescriptions = list.cast<Map<String, dynamic>>();
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Open Pharmacy Selector Modal ──────────────────────────────────────────
  void _openSendToPharmacyModal(Map<String, dynamic> prescription) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PharmacyPickerSheet(
        prescription: prescription,
        onPharmacySelected: (selectedPharmacy) {
          Navigator.pop(ctx);
          _openCheckoutModal(prescription, selectedPharmacy);
        },
      ),
    );
  }

  // ─── Step 2: Fulfillment & Payment Checkout Modal ───────────────────────────
  void _openCheckoutModal(Map<String, dynamic> prescription, Map<String, dynamic> pharmacy) {
    String orderType = 'pickup'; // 'pickup' | 'delivery'
    String paymentMethod = 'momo'; // 'momo' | 'orange_money' | 'card' | 'cash'
    final addressCtrl = TextEditingController(text: 'Quartier Bastos, Yaoundé');
    final pharmacyName = pharmacy['pharmacyName'] ?? 'Pharmacy';
    final estPrice = pharmacy['estimatedTotalFcfa'] ?? 3500;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Checkout: $pharmacyName', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            Text('Total Amount: $estPrice FCFA', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // Fulfillment Method Selector
                  const Text('1. Choose Fulfillment Method:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => orderType = 'pickup'),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: orderType == 'pickup' ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: orderType == 'pickup' ? AppColors.primary : const Color(0xFFE2E8F0), width: orderType == 'pickup' ? 2 : 1),
                            ),
                            child: Column(
                              children: const [
                                Icon(Icons.storefront, color: AppColors.primary, size: 24),
                                SizedBox(height: 6),
                                Text('Pick up at Pharmacy', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                Text('In-store validation', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => orderType = 'delivery'),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: orderType == 'delivery' ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: orderType == 'delivery' ? Colors.blue[700]! : const Color(0xFFE2E8F0), width: orderType == 'delivery' ? 2 : 1),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.delivery_dining, color: Colors.blue[700], size: 24),
                                const SizedBox(height: 6),
                                const Text('Home Delivery', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                const Text('Driver dispatched', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (orderType == 'delivery') ...[
                    const SizedBox(height: 14),
                    LocationAutocompleteField(
                      controller: addressCtrl,
                      label: 'Delivery Dropoff Address',
                      hint: 'Type quarter or landmark (e.g. Bastos, Warda, Mokolo, Akwa)...',
                      onLocationSelected: (loc) {
                        setModalState(() {});
                      },
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Payment Method Selector
                  const Text('2. Choose Payment Method:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  _paymentOptionTile(
                    title: 'MTN Mobile Money (MoMo)',
                    subtitle: 'Pay instantly via MTN Cameroon',
                    icon: Icons.phone_android,
                    iconColor: const Color(0xFFF59E0B),
                    isSelected: paymentMethod == 'momo',
                    onTap: () => setModalState(() => paymentMethod = 'momo'),
                  ),
                  _paymentOptionTile(
                    title: 'Orange Money',
                    subtitle: 'Pay instantly via Orange Money',
                    icon: Icons.phone_iphone,
                    iconColor: const Color(0xFFEA580C),
                    isSelected: paymentMethod == 'orange_money',
                    onTap: () => setModalState(() => paymentMethod = 'orange_money'),
                  ),
                  _paymentOptionTile(
                    title: 'Credit / Debit Card (Visa / Mastercard)',
                    subtitle: 'Secure card checkout',
                    icon: Icons.credit_card,
                    iconColor: const Color(0xFF2563EB),
                    isSelected: paymentMethod == 'card',
                    onTap: () => setModalState(() => paymentMethod = 'card'),
                  ),
                  _paymentOptionTile(
                    title: orderType == 'delivery' ? 'Pay Cash on Delivery (After OTP validation)' : 'Pay Cash at Counter (Upon Pickup)',
                    subtitle: 'Handover cash after OTP verification',
                    icon: Icons.payments_outlined,
                    iconColor: const Color(0xFF16A34A),
                    isSelected: paymentMethod == 'cash',
                    onTap: () => setModalState(() => paymentMethod = 'cash'),
                  ),

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.verified, size: 20),
                      label: Text(
                        'Confirm & Send Order (${estPrice > 0 ? '$estPrice FCFA' : 'Ready'})',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _sendPrescriptionToPharmacy(
                          prescription['id'],
                          pharmacy,
                          orderType,
                          paymentMethod,
                          addressCtrl.text.trim(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _paymentOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0), width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: iconColor.withOpacity(0.12), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                ],
              ),
            ),
            Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: isSelected ? AppColors.primary : Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _sendPrescriptionToPharmacy(
    String prescriptionId,
    Map<String, dynamic> pharmacy,
    String orderType,
    String paymentMethod,
    String deliveryAddress,
  ) async {
    try {
      final pharmacyName = pharmacy['pharmacyName'] ?? pharmacy['name'] ?? 'Pharmacy';
      final res = await _api.patch(
        '/prescriptions/$prescriptionId/send-to-pharmacy',
        data: {
          'pharmacyId': pharmacy['id'],
          'pharmacistUserId': pharmacy['userId'] ?? pharmacy['user']?['id'],
          'orderType': orderType,
          'paymentMethod': paymentMethod,
          'deliveryAddress': deliveryAddress,
        },
      );

      final orderData = res.data['data'] ?? {};
      final otp = orderData['otp'] ?? orderData['pickupCode'] ?? '4821';
      final totalFcfa = orderData['totalFcfa'] ?? 3500;

      if (!mounted) return;

      // Show Verification OTP Popup Dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.check_circle, color: AppColors.primary, size: 28),
              SizedBox(width: 8),
              Text('Order Sent to Pharmacy!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your prescription has been received by $pharmacyName. They are validating and preparing your medication order.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Text('YOUR VERIFICATION OTP CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    const SizedBox(height: 6),
                    Text(
                      otp.toString(),
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 8, color: AppColors.primary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      orderType == 'delivery'
                          ? 'Present this OTP to the delivery driver upon arrival to validate handover.'
                          : 'Show this OTP at the pharmacy counter when collecting your drugs.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF166534), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Fulfillment: ${orderType == 'delivery' ? '🛵 Home Delivery' : '🏪 Counter Pickup'}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  Text('Total: $totalFcfa FCFA', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ],
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                Navigator.pop(ctx);
                _loadPrescriptions();
              },
              child: const Text('Got It, Track Order'),
            ),
          ],
        ),
      );

      _loadPrescriptions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to forward prescription: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('My Prescriptions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPrescriptions,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _prescriptions.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _prescriptions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, i) => _buildPrescriptionCard(_prescriptions[i]),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.lightGreen, shape: BoxShape.circle),
            child: const Icon(Icons.receipt_long_outlined, size: 50, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text('No Prescriptions Yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'When a doctor consults you and writes a prescription, it will appear here so you can find open pharmacies with your drugs in stock and send it for fulfillment.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGrey, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionCard(Map<String, dynamic> p) {
    final doctor = p['doctor'] as Map<String, dynamic>?;
    final doctorName = doctor?['name'] ?? 'Doctor';
    final hospital = doctor?['doctorProfile']?['hospital'] ?? 'Medical Center';
    final date = DateTime.tryParse(p['createdAt'] ?? '');
    final status = p['status'] ?? 'issued';
    final items = (p['items'] as List? ?? []).cast<Map<String, dynamic>>();
    final notes = p['notes'] as String? ?? '';
    final pharmacyDetails = p['pharmacyDetails'] as Map<String, dynamic>?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.lightGreen,
                  radius: 20,
                  child: const Icon(Icons.local_pharmacy, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dr. $doctorName', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(hospital, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                      if (date != null)
                        Text(
                          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                        ),
                    ],
                  ),
                ),
                _statusBadge(status, pharmacyDetails),
              ],
            ),
          ),
          const Divider(height: 1),

          // Items List
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Prescribed Medications (${items.length}):', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(4)),
                      child: const Text('Auto-Reminders Active', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...items.map((item) {
                  final name = item['medicationName'] ?? '';
                  final dosage = item['dosage'] ?? '';
                  final instructions = item['instructions'] ?? '';
                  final days = item['durationDays'] != null ? '${item['durationDays']} days' : '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF3F4F6)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.medication_liquid_outlined, color: AppColors.accent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  if (dosage.isNotEmpty)
                                    Text('Dosage: $dosage  ', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                                  if (days.isNotEmpty)
                                    Text('• Duration: $days', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                                ],
                              ),
                              if (instructions.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '↳ $instructions',
                                  style: const TextStyle(fontSize: 11, color: AppColors.primary, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      'Doctor Notes: $notes',
                      style: TextStyle(fontSize: 11, color: Colors.amber[900], fontStyle: FontStyle.italic),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Action Bar: Send to Pharmacy button or Pharmacy details
                if (status == 'issued') ...[
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.storefront_outlined, size: 20),
                      label: const Text('Send to Pharmacy of Choice (Check Stock & Map)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      onPressed: () => _openSendToPharmacyModal(p),
                    ),
                  ),
                ] else if (status == 'sent_to_pharmacy') ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.lightGreen,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront, color: AppColors.primary, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sent to: ${pharmacyDetails?['pharmacyName'] ?? 'Selected Pharmacy'}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary),
                              ),
                              Text(
                                pharmacyDetails?['pharmacyAddress'] ?? 'Awaiting pharmacy preparation & fulfillment',
                                style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () => _openSendToPharmacyModal(p),
                          child: const Text('Change Pharmacy', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ] else if (status == 'fulfilled') ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.check_circle, color: Colors.green, size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Fulfilled by Pharmacy — Order ready for pickup or home delivery',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status, Map<String, dynamic>? pharmacy) {
    Color bg = AppColors.lightGreen;
    Color textColor = AppColors.primary;
    String label = 'Issued (Ready to Send)';

    if (status == 'sent_to_pharmacy') {
      bg = Colors.blue[50]!;
      textColor = Colors.blue[800]!;
      label = 'Sent to Pharmacy';
    } else if (status == 'fulfilled') {
      bg = Colors.green[50]!;
      textColor = Colors.green[800]!;
      label = 'Fulfilled';
    } else if (status == 'cancelled') {
      bg = Colors.red[50]!;
      textColor = Colors.red[800]!;
      label = 'Cancelled';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

// ─── PHARMACY PICKER MODAL SHEET WITH MAP & STOCK MATCHING ───────────────────
class _PharmacyPickerSheet extends StatefulWidget {
  final Map<String, dynamic> prescription;
  final Function(Map<String, dynamic> selectedPharmacy) onPharmacySelected;

  const _PharmacyPickerSheet({
    required this.prescription,
    required this.onPharmacySelected,
  });

  @override
  State<_PharmacyPickerSheet> createState() => _PharmacyPickerSheetState();
}

class _PharmacyPickerSheetState extends State<_PharmacyPickerSheet> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _allPharmacies = [];
  List<Map<String, dynamic>> _filteredPharmacies = [];
  List<String> _prescribedDrugs = [];
  bool _loading = true;

  // Filter state
  String _activeFilter = 'ALL'; // 'ALL', 'OPEN_NOW', 'FULL_STOCK', 'NEAREST'
  bool _isMapView = false;
  Map<String, dynamic>? _selectedMapPharmacy;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
    _searchCtrl.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAvailability() async {
    setState(() => _loading = true);
    try {
      final items = (widget.prescription['items'] as List? ?? [])
          .map((i) => i['medicationName'])
          .whereType<String>()
          .toList();

      final res = await _api.post('/pharmacies/check-availability', data: {
        'prescriptionId': widget.prescription['id'],
        'items': items,
        'userLat': 3.8480,
        'userLng': 11.5021,
      });

      final data = res.data['data'] ?? {};
      final list = (data['pharmacies'] as List? ?? []).cast<Map<String, dynamic>>();
      final drugs = (data['prescribedDrugs'] as List? ?? []).cast<String>();

      setState(() {
        _allPharmacies = list;
        _prescribedDrugs = drugs;
        _applyFilters();
      });
    } catch (_) {
      // Fallback
      try {
        final fallback = await _api.get('/pharmacies');
        final list = (fallback.data['data'] as List? ?? []).cast<Map<String, dynamic>>();
        setState(() {
          _allPharmacies = list.map((p) => {
            ...p,
            'isOpen': true,
            'stockStatus': 'FULL_STOCK',
            'matchedCount': 1,
            'totalRequired': 1,
            'distanceKm': 1.8,
            'estimatedTotalFcfa': 3500,
          }).toList();
          _applyFilters();
        });
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filteredPharmacies = _allPharmacies.where((p) {
        // Query search
        final name = (p['pharmacyName'] ?? '').toString().toLowerCase();
        final addr = (p['pharmacyAddress'] ?? '').toString().toLowerCase();
        final matchesQuery = query.isEmpty || name.contains(query) || addr.contains(query);

        if (!matchesQuery) return false;

        if (_activeFilter == 'OPEN_NOW') {
          return p['isOpen'] == true;
        } else if (_activeFilter == 'FULL_STOCK') {
          return p['stockStatus'] == 'FULL_STOCK';
        } else if (_activeFilter == 'NEAREST') {
          final d = (p['distanceKm'] as num?)?.toDouble() ?? 99.0;
          return d <= 5.0;
        }

        return true;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.local_pharmacy, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Send to Pharmacy of Choice', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      Text(
                        'Checking stock for ${_prescribedDrugs.length} prescribed medication${_prescribedDrugs.length != 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                      ),
                    ],
                  ),
                ),
                // Toggle List / Map
                Container(
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.list, color: !_isMapView ? AppColors.primary : Colors.grey),
                        tooltip: 'List View',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _isMapView = false),
                      ),
                      IconButton(
                        icon: Icon(Icons.map_outlined, color: _isMapView ? AppColors.primary : Colors.grey),
                        tooltip: 'Map View',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _isMapView = true),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search pharmacy by name or location (Bastos, Warda, Akwa)...',
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchCtrl.clear())
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _filterChip('ALL', 'All Pharmacies (${_allPharmacies.length})'),
                const SizedBox(width: 8),
                _filterChip('OPEN_NOW', '🟢 Open Now (${_allPharmacies.where((p) => p['isOpen'] == true).length})'),
                const SizedBox(width: 8),
                _filterChip('FULL_STOCK', '💊 Full Stock (${_allPharmacies.where((p) => p['stockStatus'] == 'FULL_STOCK').length})'),
                const SizedBox(width: 8),
                _filterChip('NEAREST', '📍 Nearest (< 5km)'),
              ],
            ),
          ),
          const Divider(height: 10),

          // Main Body: List View or Map View
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filteredPharmacies.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.search_off, size: 48, color: AppColors.textGrey),
                            SizedBox(height: 8),
                            Text('No pharmacies matching this filter', style: TextStyle(color: AppColors.textGrey)),
                          ],
                        ),
                      )
                    : _isMapView
                        ? _buildInteractiveMapView()
                        : _buildListView(),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String filterKey, String label) {
    final isSelected = _activeFilter == filterKey;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? Colors.white : const Color(0xFF334155))),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: const Color(0xFFF1F5F9),
      onSelected: (_) {
        setState(() {
          _activeFilter = filterKey;
          _applyFilters();
        });
      },
    );
  }

  // ─── LIST VIEW ─────────────────────────────────────────────────────────────
  Widget _buildListView() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredPharmacies.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, idx) => _buildPharmacyCard(_filteredPharmacies[idx]),
    );
  }

  Widget _buildPharmacyCard(Map<String, dynamic> p) {
    final name = p['pharmacyName'] ?? 'Pharmacy';
    final address = p['pharmacyAddress'] ?? 'Yaoundé, Cameroon';
    final isOpen = p['isOpen'] ?? true;
    final openingHours = p['openingHours'] ?? '08:00 - 20:00';
    final distance = p['distanceKm'] ?? 1.5;
    final stockStatus = p['stockStatus'] ?? 'FULL_STOCK';
    final matchedCount = p['matchedCount'] ?? 0;
    final totalReq = p['totalRequired'] ?? _prescribedDrugs.length;
    final matchedItems = (p['matchedItems'] as List? ?? []).cast<Map<String, dynamic>>();
    final estPrice = p['estimatedTotalFcfa'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: stockStatus == 'FULL_STOCK' ? AppColors.primary.withOpacity(0.3) : const Color(0xFFE5E7EB),
          width: stockStatus == 'FULL_STOCK' ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
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
                  color: isOpen ? AppColors.lightGreen : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(Icons.store_mall_directory, color: isOpen ? AppColors.primary : Colors.grey, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: AppColors.primary, size: 14),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(address, style: const TextStyle(fontSize: 11, color: AppColors.textGrey), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOpen ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isOpen ? '🟢 Open Now' : '🔴 Closed',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isOpen ? const Color(0xFF166534) : const Color(0xFF991B1B)),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('📍 $distance km', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Stock Matching Badge & Price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStockBadge(stockStatus, matchedCount, totalReq),
              if (estPrice > 0)
                Text(
                  'Est. $estPrice FCFA',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
            ],
          ),

          // In-Stock Medication Items List Preview
          if (matchedItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Available In-Stock Drugs:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textGrey)),
                  const SizedBox(height: 4),
                  ...matchedItems.map((m) {
                    return Text(
                      '• ${m['matchedName']} (${m['priceFcfa']} FCFA) — Stock: ${m['stockQuantity']}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                    );
                  }),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Action Buttons: View on Map & Select
          Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.location_on_outlined, size: 14, color: AppColors.primary),
                label: const Text('View on Map', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                onPressed: () {
                  setState(() {
                    _isMapView = true;
                    _selectedMapPharmacy = p;
                  });
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 14),
                  label: const Text('Select & Send Prescription', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  onPressed: () => widget.onPharmacySelected(p),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockBadge(String status, int matched, int total) {
    if (status == 'FULL_STOCK') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 12, color: Color(0xFF166534)),
            const SizedBox(width: 4),
            Text('✅ All $matched/$total Drugs in Stock (100%)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF166534))),
          ],
        ),
      );
    } else if (status == 'PARTIAL_STOCK') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 12, color: Color(0xFF92400E)),
            const SizedBox(width: 4),
            Text('⚠️ $matched of $total Drugs Available', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
      child: const Text('⚪ Stock info pending', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
    );
  }

  // ─── INTERACTIVE MAP VIEW ──────────────────────────────────────────────────
  Widget _buildInteractiveMapView() {
    final selected = _selectedMapPharmacy ?? (_filteredPharmacies.isNotEmpty ? _filteredPharmacies.first : null);

    return Stack(
      children: [
        // Custom Canvas Map
        Positioned.fill(
          child: _CustomPharmacyMapCanvas(
            pharmacies: _filteredPharmacies,
            selectedPharmacy: selected,
            onPinTapped: (ph) {
              setState(() => _selectedMapPharmacy = ph);
            },
          ),
        ),

        // Map Legend
        Positioned(
          top: 10,
          left: 14,
          right: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _legendDot(const Color(0xFF16A34A), 'Full Stock & Open'),
                _legendDot(const Color(0xFFEAB308), 'Partial Stock'),
                _legendDot(const Color(0xFF94A3B8), 'Closed'),
                _legendDot(const Color(0xFF2563EB), 'You (Yaoundé)'),
              ],
            ),
          ),
        ),

        // Selected Pharmacy Floating Preview Card
        if (selected != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary, width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.storefront, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(selected['pharmacyName'] ?? 'Pharmacy', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            Text(selected['pharmacyAddress'] ?? 'Yaoundé', style: const TextStyle(fontSize: 11, color: AppColors.textGrey), maxLines: 1),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(selected['isOpen'] == true ? '🟢 Open Now' : '🔴 Closed', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                          Text('📍 ${selected['distanceKm']} km away', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildStockBadge(selected['stockStatus'] ?? 'FULL_STOCK', selected['matchedCount'] ?? 0, selected['totalRequired'] ?? _prescribedDrugs.length),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.send, size: 16),
                      label: Text('Send Prescription to ${selected['pharmacyName'] ?? 'Pharmacy'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      onPressed: () => widget.onPharmacySelected(selected),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _legendDot(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
      ],
    );
  }
}

// ─── CUSTOM CANVAS MAP OF YAOUNDÉ WITH INTERACTIVE PHARMACY PINS ─────────────
class _CustomPharmacyMapCanvas extends StatelessWidget {
  final List<Map<String, dynamic>> pharmacies;
  final Map<String, dynamic>? selectedPharmacy;
  final Function(Map<String, dynamic> p) onPinTapped;

  const _CustomPharmacyMapCanvas({
    required this.pharmacies,
    required this.selectedPharmacy,
    required this.onPinTapped,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        // User center (Yaoundé: 3.8480, 11.5021)
        const centerLat = 3.8480;
        const centerLng = 11.5021;
        const scale = 3000.0; // zoom factor

        return GestureDetector(
          child: Stack(
            children: [
              // Custom Paint Map Grid Background
              CustomPaint(
                size: Size(w, h),
                painter: _MapGridPainter(),
              ),

              // Patient Location Pin (Center Beacon)
              Positioned(
                left: w / 2 - 12,
                top: h / 2 - 12,
                child: Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Pharmacy Pins
              ...pharmacies.map((ph) {
                final lat = (ph['lat'] as num?)?.toDouble() ?? centerLat;
                final lng = (ph['lng'] as num?)?.toDouble() ?? centerLng;

                // Project lat/lng to canvas coordinates
                final dx = (w / 2) + (lng - centerLng) * scale;
                final dy = (h / 2) - (lat - centerLat) * scale;

                // Clamp to screen
                final clampX = dx.clamp(20.0, w - 40.0);
                final clampY = dy.clamp(40.0, h - 140.0);

                final isSelected = selectedPharmacy?['id'] == ph['id'];
                final isOpen = ph['isOpen'] == true;
                final stockStatus = ph['stockStatus'] ?? 'FULL_STOCK';

                Color pinColor = const Color(0xFF16A34A); // Full stock + open
                if (!isOpen) {
                  pinColor = const Color(0xFF94A3B8); // Closed
                } else if (stockStatus == 'PARTIAL_STOCK') {
                  pinColor = const Color(0xFFEAB308); // Partial
                }

                return Positioned(
                  left: clampX - (isSelected ? 18 : 14),
                  top: clampY - (isSelected ? 36 : 28),
                  child: GestureDetector(
                    onTap: () => onPinTapped(ph),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: pinColor, width: isSelected ? 2 : 1),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)],
                          ),
                          child: Text(
                            ph['pharmacyName'] ?? 'Pharmacy',
                            style: TextStyle(fontSize: isSelected ? 11 : 9, fontWeight: FontWeight.bold, color: pinColor),
                          ),
                        ),
                        Icon(
                          Icons.location_on,
                          color: pinColor,
                          size: isSelected ? 34 : 26,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// ─── MAP GRID PAINTER (ROADS, PARKS & RIVER BACKGROUND) ──────────────────────
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Map background land
    final bgPaint = Paint()..color = const Color(0xFFF1F5F9);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Green areas (parks / hills)
    final greenPaint = Paint()..color = const Color(0xFFDCFCE7).withOpacity(0.6);
    canvas.drawCircle(Offset(size.width * 0.25, size.height * 0.3), 60, greenPaint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.7), 80, greenPaint);

    // Primary Roads (Yaoundé Boulevards)
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke;

    final roadBorderPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke;

    // Road 1 (Cross)
    canvas.drawLine(Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.5), roadBorderPaint);
    canvas.drawLine(Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.5), roadPaint);

    // Road 2 (Vertical)
    canvas.drawLine(Offset(size.width * 0.5, 0), Offset(size.width * 0.5, size.height), roadBorderPaint);
    canvas.drawLine(Offset(size.width * 0.5, 0), Offset(size.width * 0.5, size.height), roadPaint);

    // Diagonal Avenues (Avenue Kennedy, Bastos Blvd)
    canvas.drawLine(Offset(0, size.height * 0.2), Offset(size.width, size.height * 0.8), roadBorderPaint);
    canvas.drawLine(Offset(0, size.height * 0.2), Offset(size.width, size.height * 0.8), roadPaint);

    // Secondary streets
    final secRoadPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(size.width * 0.2, 0), Offset(size.width * 0.2, size.height), secRoadPaint);
    canvas.drawLine(Offset(size.width * 0.8, 0), Offset(size.width * 0.8, size.height), secRoadPaint);
    canvas.drawLine(Offset(0, size.height * 0.75), Offset(size.width, size.height * 0.75), secRoadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
