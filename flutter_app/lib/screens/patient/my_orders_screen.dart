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
    final statusColor = {
      'pending': Colors.orange, 'confirmed': Colors.blue,
      'preparing': Colors.purple, 'out_for_delivery': AppColors.accent,
      'delivered': AppColors.primary, 'picked_up': AppColors.primary,
      'cancelled': Colors.red,
    }[order['status']] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('#${order['id'].toString().substring(0, 8).toUpperCase()}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(order['status'].toString().replaceAll('_', ' ').toUpperCase(),
              style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(order['pharmacy']?['pharmacyName'] ?? 'Pharmacy',
          style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('FCFA ${order['totalFcfa']}',
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          Text(order['orderType'] == 'delivery' ? '🚴 Delivery' : '🏪 Pick Up',
            style: const TextStyle(fontSize: 12)),
        ]),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DigitalReceiptScreen(orderId: order['id'].toString()),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long_rounded, size: 15),
                label: const Text('View Receipt', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  minimumSize: const Size(0, 36),
                ),
              ),
            ),
            if (order['status'] == 'out_for_delivery') ...[
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => DeliveryTrackingScreen(orderId: order['id']))),
                  icon: const Icon(Icons.map_outlined, size: 15),
                  label: const Text('Track', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    minimumSize: const Size(0, 36),
                  ),
                ),
              ),
            ],
          ],
        ),
      ]),
    );
  }
}
