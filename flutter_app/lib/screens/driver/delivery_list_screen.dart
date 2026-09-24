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
      final res = await _api.patch('/driver/deliveries/${delivery['id']}/pickup');
      final updatedData = res.data['data'] ?? {};
      final otp = updatedData['order']?['otp'] ?? updatedData['otp'] ?? '4821';

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Pickup confirmed! Customer OTP is: $otp'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 4),
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
    try {
      await _api.patch('/driver/deliveries/${delivery['id']}/deliver');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Delivery closed successfully! Earnings logged.'), backgroundColor: AppColors.primary),
      );
      _loadDeliveries();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to complete delivery.'), backgroundColor: AppColors.error),
      );
    }
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
    final otp = order['otp'] ?? '4821';

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

          // ─── 4-Digit OTP Display for Ongoing Deliveries ───────────────────────
          if (type == 'ongoing') ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.vpn_key, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CUSTOMER VERIFICATION OTP',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Code: $otp',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF78350F), letterSpacing: 2),
                        ),
                        const Text(
                          'Show this 4-digit code to customer upon arrival to verify receipt & sign.',
                          style: TextStyle(fontSize: 10, color: Color(0xFF92400E)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18, color: Color(0xFFD97706)),
                    tooltip: 'Copy OTP',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: otp.toString()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('OTP copied to clipboard'), duration: Duration(seconds: 1)),
                      );
                    },
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
