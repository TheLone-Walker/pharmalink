import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:signature/signature.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';
import 'route_map_screen.dart';
import 'delivery_photo_screen.dart';

class DeliveryListScreen extends StatefulWidget {
  final bool isTab;
  const DeliveryListScreen({super.key, this.isTab = false});

  @override
  State<DeliveryListScreen> createState() => _DeliveryListScreenState();
}

class _DeliveryListScreenState extends State<DeliveryListScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  final _socket = SocketService();
  late TabController _tab;
  List<Map<String, dynamic>> _deliveries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _loadDeliveries();
    _socket.onDeliveryNew(_onSocketDelivery);
    _socket.onOrderUpdated(_onSocketDelivery);
  }

  void _onSocketDelivery(dynamic data) {
    if (mounted) {
      _loadDeliveries();
    }
  }

  @override
  void dispose() {
    _socket.removeListener('delivery:new', _onSocketDelivery);
    _socket.removeListener('order:updated', _onSocketDelivery);
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadDeliveries() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/driver/deliveries');
      final list = (res.data['data'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
      setState(() => _deliveries = list);
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _filter(String type) {
    if (type == 'pending') {
      return _deliveries.where((d) => d['status'] == 'assigned').toList();
    }
    if (type == 'ongoing') {
      return _deliveries.where((d) => ['picked_up', 'in_transit'].contains(d['status'])).toList();
    }
    return _deliveries.where((d) => d['status'] == 'delivered').toList();
  }

  Future<void> _confirmPickup(Map<String, dynamic> delivery) async {
    try {
      await _api.patch('/driver/deliveries/${delivery['id']}/pickup');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Pickup confirmed! Head to delivery address and ask customer for their secret OTP on arrival.'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 4),
        ),
      );
      _loadDeliveries();
      _tab.animateTo(1); // Switch to Ongoing tab
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to confirm pickup. Please try again.'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _confirmDelivery(Map<String, dynamic> delivery) async {
    final patientName = delivery['order']?['patient']?['name'] ?? 'Recipient';
    final orderId = delivery['orderId']?.toString() ?? '';
    final shortOrderId = (orderId.length >= 8) ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase();
    int selectedTab = 0; // 0 = 4-Digit OTP, 1 = Scan QR Pass
    final otpCtrl = TextEditingController();
    final qrCtrl = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 480),
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
                        decoration: const BoxDecoration(color: AppColors.lightGreen, shape: BoxShape.circle),
                        child: const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Step 1: Patient Verification',
                              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'Order #$shortOrderId • $patientName',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textGrey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: isVerifying ? null : () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  Text(
                    'Choose ONE verification method from the patient:',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => selectedTab = 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selectedTab == 0 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: selectedTab == 0
                                    ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.pin_rounded, size: 16, color: selectedTab == 0 ? AppColors.primary : AppColors.textGrey),
                                  const SizedBox(width: 6),
                                  Text(
                                    '1. Enter OTP Code',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: selectedTab == 0 ? FontWeight.w800 : FontWeight.w600,
                                      color: selectedTab == 0 ? AppColors.primary : AppColors.textGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => selectedTab = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selectedTab == 1 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: selectedTab == 1
                                    ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.qr_code_scanner_rounded, size: 16, color: selectedTab == 1 ? AppColors.primary : AppColors.textGrey),
                                  const SizedBox(width: 6),
                                  Text(
                                    '2. Scan QR Code',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: selectedTab == 1 ? FontWeight.w800 : FontWeight.w600,
                                      color: selectedTab == 1 ? AppColors.primary : AppColors.textGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (selectedTab == 0) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline_rounded, color: Color(0xFFB45309), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ask the patient for their secret 4-digit handover code shown in their PharmaLink app.',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFF78350F), height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    PharmaField(
                      label: 'Patient 4-Digit Secret OTP',
                      hint: 'e.g. 4821',
                      prefixIcon: Icons.lock_clock_rounded,
                      keyboardType: TextInputType.number,
                      controller: otpCtrl,
                    ),
                  ] else ...[
                    Container(
                      height: 130,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), shape: BoxShape.circle),
                              child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF10B981), size: 28),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Point Camera at Patient QR Code',
                              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Patient shows QR from their tracking screen',
                              style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 10.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    PharmaField(
                      label: 'Or Paste Patient QR Pass Data',
                      hint: 'e.g. PHARMALINK_DELIVERY:...:4821',
                      prefixIcon: Icons.qr_code_rounded,
                      keyboardType: TextInputType.text,
                      controller: qrCtrl,
                    ),
                  ],
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: isVerifying
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: Text(
                        isVerifying ? 'Verifying Code...' : 'Verify & Open Patient Signature Pad',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      onPressed: isVerifying
                          ? null
                          : () async {
                              final inputCode = selectedTab == 0 ? otpCtrl.text.trim() : qrCtrl.text.trim();
                              if (inputCode.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(selectedTab == 0
                                        ? 'Please enter the 4-digit OTP provided by the patient.'
                                        : 'Please scan or paste the patient\'s QR code pass.'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                                return;
                              }

                              setModalState(() => isVerifying = true);
                              try {
                                final res = await _api.post('/driver/deliveries/${delivery['id']}/verify-code', data: {
                                  'code': inputCode,
                                });

                                final verifiedOtp = res.data['data']?['otp']?.toString() ?? inputCode;

                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('✓ Code verified! Opening patient digital signature pad...'),
                                      backgroundColor: AppColors.primary,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  _openDeliverySignatureDialog(delivery, verifiedOtp: verifiedOtp);
                                }
                              } catch (e) {
                                setModalState(() => isVerifying = false);
                                String err = 'Invalid OTP or QR code! Code does not match patient\'s secret pass. Please ask patient to check their PharmaLink app.';
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(err), backgroundColor: AppColors.error),
                                  );
                                }
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Step 2: Digital Signature Dialog for Patient
  void _openDeliverySignatureDialog(Map<String, dynamic> delivery, {required String verifiedOtp}) {
    final patientName = delivery['order']?['patient']?['name'] ?? 'Recipient';
    final orderId = delivery['orderId']?.toString() ?? '';
    final shortOrderId = (orderId.length >= 8) ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase();
    final sigController = SignatureController(
      penStrokeWidth: 3.5,
      penColor: const Color(0xFF0F172A),
      exportBackgroundColor: Colors.white,
    );
    bool submitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 480),
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
                        decoration: const BoxDecoration(color: AppColors.lightGreen, shape: BoxShape.circle),
                        child: const Icon(Icons.draw_rounded, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Step 2: Recipient Signature',
                              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'Order #$shortOrderId • $patientName',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textGrey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: submitting ? null : () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '✓ Handover Pass Verified! Hand device to patient to sign. Signing unlocks the pharmacy payment and issues digital receipt.',
                            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFF166534), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'Patient Digital Signature Pad *',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary, width: 2),
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Signature(
                        controller: sigController,
                        height: 180,
                        backgroundColor: const Color(0xFFFAFAFA),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Patient signs with finger on screen',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textGrey, fontStyle: FontStyle.italic),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        icon: const Icon(Icons.refresh, size: 14, color: Color(0xFFEF4444)),
                        label: const Text('Clear', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w700)),
                        onPressed: () => sigController.clear(),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: submitting ? null : () => Navigator.pop(ctx),
                          child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: AppColors.textGrey)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: submitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_circle, size: 18),
                          label: Text(
                            submitting ? 'Processing Handover...' : 'Sign & Unlock Delivery',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          onPressed: submitting
                              ? null
                              : () async {
                                  if (sigController.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please have the patient sign before confirming delivery.'), backgroundColor: AppColors.error),
                                    );
                                    return;
                                  }

                                  setDlgState(() => submitting = true);
                                  try {
                                    final Uint8List? pngBytes = await sigController.toPngBytes();
                                    String? base64Sig;
                                    if (pngBytes != null) {
                                      base64Sig = 'data:image/png;base64,${base64Encode(pngBytes)}';
                                    }

                                    // 1. Submit signature & unlock payment on backend
                                    if (orderId.isNotEmpty) {
                                      await _api.post('/orders/$orderId/signature', data: {
                                        'signatureBase64': base64Sig,
                                      }).catchError((_) => null);
                                    }

                                    // 2. Mark delivery delivered with verified OTP
                                    await _api.patch('/driver/deliveries/${delivery['id']}/deliver', data: {'otp': verifiedOtp});

                                    if (ctx.mounted) Navigator.pop(ctx);
                                    _loadDeliveries();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('🎉 Delivery signed & completed! Escrow payment unlocked to pharmacy and commission credited to wallet.'),
                                          backgroundColor: AppColors.primary,
                                          duration: Duration(seconds: 4),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setDlgState(() => submitting = false);
                                    String err = 'Could not finalize delivery: $e';
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(err), backgroundColor: Colors.red),
                                      );
                                    }
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingList = _filter('pending');
    final ongoingList = _filter('ongoing');
    final completedList = _filter('completed');

    final content = _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : TabBarView(
            controller: _tab,
            children: [
              _buildDeliveryTab(pendingList, 'pending'),
              _buildDeliveryTab(ongoingList, 'ongoing'),
              _buildDeliveryTab(completedList, 'completed'),
            ],
          );

    if (widget.isTab) {
      return Column(
        children: [
          Container(
            color: AppColors.primary,
            child: TabBar(
              controller: _tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              tabs: [
                Tab(text: 'Pending (${pendingList.length})'),
                Tab(text: 'Ongoing (${ongoingList.length})'),
                Tab(text: 'Completed (${completedList.length})'),
              ],
            ),
          ),
          Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Deliveries'),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(text: 'Pending (${pendingList.length})'),
            Tab(text: 'Ongoing (${ongoingList.length})'),
            Tab(text: 'Completed (${completedList.length})'),
          ],
        ),
      ),
      body: content,
    );
  }

  Widget _buildDeliveryTab(List<Map<String, dynamic>> list, String type) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                type == 'pending'
                    ? Icons.inbox_outlined
                    : type == 'ongoing'
                        ? Icons.delivery_dining_outlined
                        : Icons.check_circle_outline,
                size: 60,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 14),
              Text(
                'No $type deliveries',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textDark),
              ),
              const SizedBox(height: 6),
              Text(
                type == 'pending'
                    ? 'New delivery assignments will appear here.'
                    : type == 'ongoing'
                        ? 'Confirmed pickups on route to customer will appear here.'
                        : 'Your delivered orders and earnings history will appear here.',
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDeliveries,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (ctx, idx) => _deliveryCard(list[idx], type),
      ),
    );
  }

  Widget _deliveryCard(Map<String, dynamic> d, String type) {
    final order = d['order'] ?? {};
    final orderId = (order['id'] ?? d['orderId'] ?? '').toString();
    final shortId = orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase();
    final pharmacy = order['pharmacy'] ?? {};
    final pharmacyName = pharmacy['pharmacyName'] ?? 'Pharmacy Partner';
    final pharmacyAddress = pharmacy['pharmacyAddress'] ?? 'Yaoundé Central';
    final patient = order['patient'] ?? {};
    final patientName = patient['name'] ?? 'Customer';
    final patientPhone = patient['phone'] ?? '+237 600 000 000';
    final dropoffAddress = order['deliveryAddress'] ?? 'Customer Dropoff Address';
    final totalFcfa = double.tryParse(order['totalFcfa']?.toString() ?? '0') ?? 0.0;
    final driverCut = (totalFcfa * 0.1).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Order ID + Driver Payout
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.lightGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Order #$shortId',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textDark),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Text(
                  '+FCFA $driverCut payout',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF15803D)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Route: Pharmacy -> Customer
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.storefront, size: 18, color: AppColors.primary),
                  Container(width: 2, height: 26, color: Colors.grey[300]),
                  const Icon(Icons.location_on, size: 18, color: Colors.red),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pickup: $pharmacyName',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    Text(
                      pharmacyAddress,
                      style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Dropoff: $patientName ($patientPhone)',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    Text(
                      dropoffAddress,
                      style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ─── Doorstep Security Prompt for Ongoing Deliveries ─────────────────
          if (type == 'ongoing') ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF93C5FD)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security_rounded, color: Color(0xFF1D4ED8), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DOORSTEP HANDOVER VERIFICATION',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1E40AF)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Upon arrival, ask $patientName for their secret 4-digit OTP shown in their PharmaLink app to complete delivery.',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF1E3A8A)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // ─── Contextual Action Buttons ─────────────────────────────────────────
          if (type == 'pending') ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.map_outlined, size: 16),
                    label: const Text('Route Map', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RouteMapScreen(
                          deliveryId: d['id'],
                          orderId: orderId,
                          pharmacyName: pharmacyName,
                          customerName: patientName,
                          pickupLat: pharmacy['lat'],
                          pickupLng: pharmacy['lng'],
                          dropoffLat: order['deliveryLat'],
                          dropoffLng: order['deliveryLng'],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Confirm Pickup', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: () => _confirmPickup(d),
                  ),
                ),
              ],
            ),
          ] else if (type == 'ongoing') ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.navigation_outlined, size: 16),
                    label: const Text('Navigate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RouteMapScreen(
                          deliveryId: d['id'],
                          orderId: orderId,
                          pharmacyName: pharmacyName,
                          customerName: patientName,
                          pickupLat: pharmacy['lat'],
                          pickupLng: pharmacy['lng'],
                          dropoffLat: order['deliveryLat'],
                          dropoffLng: order['deliveryLng'],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.camera_alt_outlined, size: 16),
                    label: const Text('Photo Proof', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DeliveryPhotoScreen(orderId: orderId, deliveryId: d['id'])),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.check_circle, color: AppColors.primary, size: 28),
                  tooltip: 'Confirm Delivery',
                  onPressed: () => _confirmDelivery(d),
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.verified, color: AppColors.primary, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Delivered & Digitally Signed',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ],
                ),
                Text(
                  'Order Total: FCFA ${totalFcfa.round()}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textGrey, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
