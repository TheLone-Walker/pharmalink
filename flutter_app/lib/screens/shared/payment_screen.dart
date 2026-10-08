import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/location_autocomplete_field.dart';
import '../patient/my_orders_screen.dart';
import '../patient/digital_receipt_screen.dart';
import '../patient/delivery_tracking_screen.dart';
import '../patient/book_appointment_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String? orderId;
  final String orderType;
  final String pharmacyId;
  final List<Map<String, dynamic>> items;
  final double totalFcfa;
  final String? prescriptionId;

  const PaymentScreen({
    super.key,
    this.orderId,
    required this.orderType,
    required this.pharmacyId,
    required this.items,
    required this.totalFcfa,
    this.prescriptionId,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _api = ApiService();
  String _method = 'momo';
  bool _loading = false;
  String? _currentPrescriptionId;
  String? _attachedPrescriptionName;
  List<dynamic> _patientPrescriptions = [];
  final _addressCtrl = TextEditingController(text: 'Quartier Bastos, Yaoundé');
  final _phoneCtrl = TextEditingController();

  final _methods = [
    {'id': 'momo', 'label': 'MTN Mobile Money (*126#)', 'icon': Icons.phone_android, 'sub': 'Cameroon MTN MoMo'},
    {'id': 'orange_money', 'label': 'Orange Money (#150#)', 'icon': Icons.phone_iphone, 'sub': 'Cameroon Orange Money'},
    {'id': 'card', 'label': 'Bank Card (Visa / Mastercard)', 'icon': Icons.credit_card_outlined, 'sub': 'Online Card Payment'},
    {'id': 'cash', 'label': 'Cash on Delivery / Pickup', 'icon': Icons.money, 'sub': 'Pay upon arrival'},
  ];

  @override
  void initState() {
    super.initState();
    _currentPrescriptionId = widget.prescriptionId;
    if (_currentPrescriptionId != null) {
      _attachedPrescriptionName = 'Digital Prescription #${_currentPrescriptionId!.length > 8 ? _currentPrescriptionId!.substring(0, 8) : _currentPrescriptionId} Attached';
    }
    final auth = context.read<AuthService>();
    if (auth.user?['phone'] != null) {
      _phoneCtrl.text = auth.user!['phone'].toString();
    }
    _loadPrescriptions();
  }

  Future<void> _loadPrescriptions() async {
    try {
      final res = await _api.get('/prescriptions');
      if (res.data['success'] == true) {
        setState(() {
          _patientPrescriptions = res.data['data'] as List<dynamic>? ?? [];
        });
      }
    } catch (_) {}
  }

  bool _prescriptionMatchesMedication(Map<String, dynamic> prescription, String medName) {
    final medLower = medName.toLowerCase().trim();
    if (medLower.isEmpty) return true;
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

  bool _checkPrescriptionMatchesOrder(Map<String, dynamic> prescription) {
    // If order has medication names, cross-check them
    final medNames = widget.items.map((it) => (it['medicationName'] ?? it['name'] ?? '').toString()).where((n) => n.isNotEmpty).toList();
    if (medNames.isEmpty) return true;

    return medNames.any((name) => _prescriptionMatchesMedication(prescription, name));
  }

  void _showOnlinePrescriptionPicker() {
    final medNames = widget.items.map((it) => (it['medicationName'] ?? it['name'] ?? '').toString()).where((n) => n.isNotEmpty).toList();
    final primaryMed = medNames.isNotEmpty ? medNames.join(', ') : 'Ordered Medications';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: 540,
            maxHeight: MediaQuery.of(ctx).size.height * 0.88,
          ),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          padding: const EdgeInsets.all(18),
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
                            'Doctor Digital Prescription',
                            style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Order Item: $primaryMed',
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
                          'Only official digital prescriptions issued by certified doctors are accepted. The prescription must explicitly prescribe "$primaryMed".',
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
                          'You do not have any active doctor prescriptions on file. Please consult a certified ONMC doctor online to receive a digital prescription for $primaryMed.',
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
                    final rawDocName = doc['name']?.toString() ?? 'Certified Doctor';
                    final docName = rawDocName.startsWith('Dr.') ? rawDocName : 'Dr. $rawDocName';
                    final dateStr = mapP['createdAt'] != null ? mapP['createdAt'].toString().split('T')[0] : 'Recent';
                    final isMatch = _checkPrescriptionMatchesOrder(mapP);
                    final rxItems = (mapP['items'] as List? ?? []).map((i) => i['medicationName']?.toString() ?? '').join(', ');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isMatch ? const Color(0xFF10B981) : const Color(0xFFFCA5A5),
                          width: isMatch ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        color: isMatch ? const Color(0xFFF0FDF4) : const Color(0xFFFFF1F2),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          if (!isMatch) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('🚫 Prescription Rejected: This prescription from $docName does not contain "$primaryMed". You cannot use an unrelated prescription to purchase this drug.'),
                                backgroundColor: const Color(0xFFDC2626),
                                duration: const Duration(seconds: 4),
                              ),
                            );
                            return;
                          }

                          setState(() {
                            _currentPrescriptionId = mapP['id'].toString();
                            _attachedPrescriptionName = 'Digital Rx from $docName ($dateStr)';
                          });
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ Attached Doctor Digital Rx from $docName!'),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isMatch ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isMatch ? Icons.verified_rounded : Icons.cancel_outlined,
                                  color: isMatch ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Rx from $docName',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                      decoration: BoxDecoration(
                                        color: isMatch ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isMatch ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                            size: 13,
                                            color: isMatch ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              isMatch ? 'Prescribed for $primaryMed' : 'Mismatch: Unrelated Rx',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: isMatch ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Prescribed Items: ${rxItems.isNotEmpty ? rxItems : "None"} • Date: $dateStr',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textGrey),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Icon(
                                  isMatch ? Icons.arrow_forward_ios_rounded : Icons.block,
                                  size: 14,
                                  color: isMatch ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final isFree = widget.totalFcfa <= 0;
    if (!isFree && (_method == 'momo' || _method == 'orange_money') && _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Mobile Money phone number'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      // 1. Create order first if no orderId
      String orderId = widget.orderId ?? '';
      if (orderId.isEmpty) {
        final orderRes = await _api.post('/orders', data: {
          'pharmacyId': widget.pharmacyId,
          'orderType': widget.orderType,
          'items': widget.items,
          'deliveryAddress': widget.orderType == 'delivery' ? _addressCtrl.text.trim() : null,
          'prescriptionId': _currentPrescriptionId ?? widget.prescriptionId,
          'paymentMethod': isFree ? 'free' : _method,
        });
        orderId = orderRes.data['data']['id'];
      }

      // 2. Initiate payment with DigiPay / Mobile Money or Free confirm
      final payRes = await _api.post('/payments/initiate', data: {
        'orderId': orderId,
        'method': isFree ? 'free' : _method,
        'amountFcfa': widget.totalFcfa,
        'phoneNumber': _phoneCtrl.text.trim(),
        'description': isFree ? 'Free Medication Order #$orderId' : 'PharmaLink Order #$orderId',
      });

      if (!mounted) return;

      final successMsg = payRes.data['message'] ?? (isFree ? '🎁 Free delivery order confirmed!' : 'Payment processed successfully!');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMsg), backgroundColor: AppColors.primary),
      );

      // 3. Routing based on orderType:
      // - Delivery: Auto-dispatch nearest online driver & route to MyOrdersScreen for live tracking
      // - Pickup: Route directly to DigitalReceiptScreen with pickup code to present at counter
      if (widget.orderType == 'delivery') {
        _api.post('/orders/$orderId/auto-assign').catchError((_) {});
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const MyOrdersScreen(),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DigitalReceiptScreen(orderId: orderId),
          ),
        );
      }
    } catch (e) {
      String msg = 'Payment failed. Please try again.';
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data['message'] != null) {
          msg = data['message'].toString();
        }
      } else {
        final s = e.toString().replaceAll('Exception:', '').trim();
        if (s.isNotEmpty) msg = s;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout & Payment')),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Order summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
                ),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Order Type', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                    Text(widget.orderType == 'delivery' ? '🚴 Express Delivery' : '🏪 Pharmacy Pick Up',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  ]),
                  const Divider(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(widget.totalFcfa <= 0 ? 'Cost (Donor Subsidized)' : 'Total to Pay', style: const TextStyle(color: AppColors.textGrey, fontSize: 14)),
                    Text(widget.totalFcfa <= 0 ? 'FREE (0 FCFA)' : 'FCFA ${widget.totalFcfa.toStringAsFixed(0)}',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: widget.totalFcfa <= 0 ? const Color(0xFF10B981) : AppColors.primary)),
                  ]),
                ]),
              ),

              if (widget.totalFcfa <= 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Free / Subsidized Medication Program',
                              style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF065F46), fontSize: 13),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'No payment gateway charge required. A Live Delivery QR Code will be generated for delivery confirmation.',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF047857)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (widget.orderType == 'delivery') ...[
                const SizedBox(height: 20),
                const Text('Delivery Dropoff Address', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                LocationAutocompleteField(
                  controller: _addressCtrl,
                  label: 'Delivery Dropoff Address',
                  hint: 'Type quarter or landmark (e.g. Bastos, Warda, Akwa)...',
                ),
              ],

              const SizedBox(height: 20),
              // Doctor Prescription Attachment & Verification Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _currentPrescriptionId != null ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _currentPrescriptionId != null ? const Color(0xFF86EFAC) : const Color(0xFFFCD34D),
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
                            color: _currentPrescriptionId != null ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _currentPrescriptionId != null ? Icons.verified_rounded : Icons.file_present_rounded,
                            color: _currentPrescriptionId != null ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentPrescriptionId != null ? 'Doctor Digital Prescription Verified' : 'Doctor Digital Prescription Required',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: _currentPrescriptionId != null ? const Color(0xFF166534) : const Color(0xFF92400E),
                                ),
                              ),
                              Text(
                                _currentPrescriptionId != null
                                    ? (_attachedPrescriptionName ?? 'Official doctor digital Rx attached & validated.')
                                    : 'Only verified digital prescriptions issued by certified doctors are accepted for regulated medications.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  color: _currentPrescriptionId != null ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_currentPrescriptionId != null)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                            tooltip: 'Remove Prescription',
                            onPressed: () {
                              setState(() {
                                _currentPrescriptionId = null;
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
                              backgroundColor: _currentPrescriptionId != null ? const Color(0xFF0F172A) : AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFF34D399)),
                            label: Text(
                              _currentPrescriptionId != null ? 'Change Digital Rx' : 'Select Doctor Digital Rx',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            onPressed: _showOnlinePrescriptionPicker,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.medical_services_rounded, size: 15),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const BookAppointmentScreen()));
                          },
                          label: Text(
                            'Consult Doctor',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (widget.totalFcfa > 0) ...[
                const SizedBox(height: 24),
                const Text('Select Payment Method', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),

                ..._methods.map((m) {
                  final isSelected = _method == m['id'];
                  return GestureDetector(
                    onTap: () => setState(() => _method = m['id'] as String),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.lightMint : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected ? AppColors.subtleShadow : [],
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary.withOpacity(0.1) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(m['icon'] as IconData, color: isSelected ? AppColors.primary : AppColors.textGrey),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m['label'] as String,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? AppColors.textDark : AppColors.textSubtle,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                m['sub'] as String,
                                style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
                        else
                          const Icon(Icons.radio_button_unchecked, color: AppColors.textMuted, size: 22),
                      ]),
                    ),
                  );
                }),

                if (_method == 'momo' || _method == 'orange_money') ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _method == 'momo' ? 'MTN MoMo Number (+237)' : 'Orange Money Number (+237)',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: 'e.g. 670000000',
                            prefixIcon: const Icon(Icons.phone_iphone_rounded, color: AppColors.primary),
                            filled: true,
                            fillColor: AppColors.fieldBg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: PharmaButton(
            label: widget.totalFcfa <= 0
                ? (widget.orderType == 'delivery' ? '🎁 Confirm Free Delivery & Get QR Code' : '🎁 Confirm Free Order (0 FCFA)')
                : 'Confirm & Pay FCFA ${widget.totalFcfa.toStringAsFixed(0)}',
            onPressed: _pay,
            isLoading: _loading,
            icon: widget.totalFcfa <= 0 ? Icons.qr_code_2_rounded : Icons.lock_outline,
          ),
        ),
      ]),
    );
  }
}
