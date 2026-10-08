import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../utils/constants.dart';
import 'delivery_tracking_screen.dart';
import 'digital_receipt_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});
  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  final _socket = SocketService();
  late TabController _tab;
  List _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
    _socket.onOrderUpdated(_onSocketOrder);
    _socket.onOrderNew(_onSocketOrder);
    _socket.onOrderStatus(_onSocketOrder);
  }

  void _onSocketOrder(dynamic data) {
    if (mounted) {
      _load();
    }
  }

  @override
  void dispose() {
    _socket.removeListener('order:updated', _onSocketOrder);
    _socket.removeListener('order:new', _onSocketOrder);
    _socket.removeListener('order:status_change', _onSocketOrder);
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/orders');
      setState(() => _orders = res.data['data'] ?? []);
    } catch (_) {} finally { setState(() => _loading = false); }
  }

  Future<void> _switchToPickup(Map order) async {
    final orderId = order['id'].toString();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.storefront_rounded, color: Color(0xFF16A34A), size: 24),
            SizedBox(width: 10),
            Expanded(child: Text('Switch to Counter Pickup?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          ],
        ),
        content: const Text(
          'Need your medication immediately without waiting for a courier?\n\n'
          'Switching will instantly issue your Pharmacy Counter Pickup Pass & QR Code. You or anyone with your QR code can collect your medication at the pharmacy counter right away.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Delivery'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.qr_code_rounded, size: 16),
            label: const Text('Get Pickup Pass Now', style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _api.patch('/orders/$orderId/switch-to-pickup');
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🏪 Switched to In-Person Pickup! Counter pass activated.'),
              backgroundColor: Color(0xFF16A34A),
            ),
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DigitalReceiptScreen(orderId: orderId),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not switch to pickup: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  List _filtered(String status) {
    if (status == 'active') return _orders.where((o) => ['pending','confirmed','preparing','out_for_delivery'].contains(o['status'])).toList();
    if (status == 'delivered') return _orders.where((o) => ['delivered','picked_up'].contains(o['status'])).toList();
    return _orders.where((o) => o['status'] == 'cancelled').toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [Tab(text: 'Active'), Tab(text: 'Completed'), Tab(text: 'Cancelled')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tab,
              children: ['active', 'delivered', 'cancelled'].map((status) {
                final list = _filtered(status);
                if (list.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.inbox_outlined, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('No $status orders', style: const TextStyle(color: AppColors.textGrey)),
                ]));
                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _orderTile(list[i]),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _orderTile(Map order) {
    final status = (order['status'] ?? 'pending').toString();
    final isDelivery = order['orderType'] == 'delivery';
    final isCompleted = status == 'delivered' || status == 'picked_up';
    final pickupCode = order['pickupCode'] ?? order['otp'];

    final statusColor = {
      'pending': Colors.orange,
      'confirmed': Colors.blue,
      'preparing': Colors.purple,
      'out_for_delivery': AppColors.accent,
      'delivered': AppColors.primary,
      'picked_up': AppColors.primary,
      'cancelled': Colors.red,
    }[status] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
          width: isCompleted ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#${order['id'].toString().substring(0, 8).toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(fontSize: 10.5, color: statusColor, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            order['pharmacy']?['pharmacyName'] ?? 'Pharmacy',
            style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FCFA ${order['totalFcfa']}',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 15),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDelivery ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isDelivery ? '🚴 Doorstep Delivery' : '🏪 Pharmacy Counter Pickup',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDelivery ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),

          // For Counter Pickup orders: Show pickup code badge immediately
          if (!isDelivery && pickupCode != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_rounded, color: Color(0xFF16A34A), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pickup Pass: $pickupCode',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ),
                  const Text(
                    'Ready at Counter',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Action Buttons:
          // 1. If Pickup Order: Always allow instant receipt view to present at counter
          // 2. If Delivery Order:
          //    - If Delivered: View Completed Delivery Receipt
          //    - If in Progress: Track Live Delivery & Show QR code (Receipt issued upon delivery)
          if (!isDelivery) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DigitalReceiptScreen(orderId: order['id'].toString()),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long_rounded, size: 16),
                label: const Text(
                  '🏪 View Counter Pickup Receipt & Code',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ] else if (isCompleted) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DigitalReceiptScreen(orderId: order['id'].toString()),
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: const Text(
                  '📄 View Official Delivery Receipt',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ] else ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DeliveryTrackingScreen(orderId: order['id']),
                          ),
                        ),
                        icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                        label: const Text(
                          '🚴 Track Live Delivery & Show QR',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
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
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _switchToPickup(order),
                    icon: const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF16A34A)),
                    label: const Text(
                      '🏪 Emergency / In a hurry? Get Counter Pickup Pass',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF86EFAC), width: 1.2),
                      backgroundColor: const Color(0xFFF0FDF4),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: const [
                    Icon(Icons.info_outline_rounded, size: 13, color: AppColors.textGrey),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Delivery receipt unlocks upon doorstep delivery. Or switch to Counter Pass for immediate in-person pickup.',
                        style: TextStyle(fontSize: 10, color: AppColors.textGrey),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
