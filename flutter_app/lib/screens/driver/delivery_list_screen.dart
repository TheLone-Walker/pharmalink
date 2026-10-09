import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final otpCtrl = TextEditingController();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text('Doorstep OTP Verification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recipient: $patientName',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ask the customer for their secret 4-digit verification OTP shown in their PharmaLink app to complete handover:',
                style: TextStyle(fontSize: 12, color: AppColors.textGrey, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                autofocus: true,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 6, color: AppColors.primary),
                decoration: InputDecoration(
                  hintText: '• • • •',
                  counterText: '',
                  hintStyle: const TextStyle(color: Colors.black26, letterSpacing: 4),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: submitting
                  ? null
                  : () async {
                      final code = otpCtrl.text.trim();
                      if (code.isEmpty) return;
                      setDlgState(() => submitting = true);
                      try {
                        await _api.patch('/driver/deliveries/${delivery['id']}/deliver', data: {'otp': code});
                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadDeliveries();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🎉 Delivery verified & completed! Commission credited to your wallet.'),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        }
                      } catch (e) {
                        setDlgState(() => submitting = false);
                        String err = 'Invalid OTP code. Please ask customer to check their PharmaLink app.';
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(err), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Verify & Complete', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
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
