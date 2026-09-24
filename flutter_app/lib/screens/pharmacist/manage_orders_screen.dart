import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';
import '../../services/socket_service.dart';
import '../shared/chat_screen.dart';

class ManageOrdersScreen extends StatefulWidget {
  const ManageOrdersScreen({super.key});

  @override
  State<ManageOrdersScreen> createState() => _ManageOrdersScreenState();
}

class _ManageOrdersScreenState extends State<ManageOrdersScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  final _socket = SocketService();
  late TabController _tabController;

  List<Map<String, dynamic>> _allOrders = [];
  bool _loading = true;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  final List<String> _tabs = [
    'All',
    'Pending',
    'Preparing',
    'Out for Delivery',
    'Ready / Pickup',
    'Delivered',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadOrders();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase().trim());
    });
    _socket.onOrderNew(_onSocketOrder);
    _socket.onOrderUpdated(_onSocketOrder);
  }

  void _onSocketOrder(dynamic data) {
    if (mounted) {
      _loadOrders();
    }
  }

  @override
  void dispose() {
    _socket.removeListener('order:new', _onSocketOrder);
    _socket.removeListener('order:updated', _onSocketOrder);
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/pharmacist/orders');
      final list = (res.data['data'] as List? ?? []).cast<Map<String, dynamic>>();
      setState(() => _allOrders = list);
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Filter Orders by Tab & Query ──────────────────────────────────────────
  List<Map<String, dynamic>> get _filteredOrders {
    final currentTab = _tabs[_tabController.index];
    return _allOrders.where((order) {
      final status = (order['status'] ?? 'pending').toString().toLowerCase();
      final orderType = (order['orderType'] ?? 'pickup').toString().toLowerCase();

      // Tab Filtering
      bool matchesTab = true;
      if (currentTab == 'Pending') {
        matchesTab = status == 'pending';
      } else if (currentTab == 'Preparing') {
        matchesTab = status == 'confirmed' || status == 'preparing';
      } else if (currentTab == 'Out for Delivery') {
        matchesTab = status == 'out_for_delivery';
      } else if (currentTab == 'Ready / Pickup') {
        matchesTab = (status == 'preparing' || status == 'confirmed') && orderType == 'pickup';
      } else if (currentTab == 'Delivered') {
        matchesTab = status == 'delivered' || status == 'picked_up';
      }

      if (!matchesTab) return false;

      // Query Filtering
      if (_searchQuery.isNotEmpty) {
        final id = (order['id'] ?? '').toString().toLowerCase();
        final patientName = (order['patient']?['name'] ?? '').toString().toLowerCase();
        final phone = (order['patient']?['phone'] ?? '').toString().toLowerCase();
        return id.contains(_searchQuery) || patientName.contains(_searchQuery) || phone.contains(_searchQuery);
      }

      return true;
    }).toList();
  }

  // ─── Order Actions ─────────────────────────────────────────────────────────

  // 1. Validate & Confirm Order
  Future<void> _confirmOrder(String orderId) async {
    try {
      await _api.patch('/pharmacist/orders/$orderId/confirm');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order verified & confirmed! Preparing medications.'), backgroundColor: AppColors.primary),
      );
      _loadOrders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  // 2. Open Driver Assignment Modal
  void _openAssignDriverModal(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AssignDriverModal(
        order: order,
        onDriverAssigned: () {
          Navigator.pop(ctx);
          _loadOrders();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Delivery driver successfully assigned! En route to pharmacy.'), backgroundColor: AppColors.primary),
          );
        },
      ),
    );
  }

  // 3. Open OTP Verification Modal (for In-Person Pickup or Handover)
  void _openVerifyOtpModal(Map<String, dynamic> order) {
    final otpCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 24),
            SizedBox(width: 8),
            Text('Validate Customer OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter the 4-digit OTP provided by customer ${order['patient']?['name'] ?? ''} to validate handover:', style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
            const SizedBox(height: 16),
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 6, color: AppColors.primary),
              decoration: InputDecoration(
                hintText: '• • • •',
                hintStyle: const TextStyle(color: Colors.grey, letterSpacing: 4),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final code = otpCtrl.text.trim();
              if (code.isEmpty) return;
              try {
                await _api.post('/pharmacist/orders/${order['id']}/verify-otp', data: {'otp': code});
                Navigator.pop(ctx);
                _loadOrders();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('OTP Validated! Order marked as completed.'), backgroundColor: AppColors.primary),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Validation failed: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Verify & Complete'),
          ),
        ],
      ),
    );
  }

  // 4. Mark Pickup Ready
  Future<void> _markReady(String orderId) async {
    try {
      await _api.patch('/pharmacist/orders/$orderId/ready');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medications ready for customer counter pickup!'), backgroundColor: AppColors.primary),
      );
      _loadOrders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOrders;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Pharmacy Order Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: Column(
        children: [
          // Search & Summary Header
          Container(
            padding: const EdgeInsets.all(14),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search order #, patient name, phone number...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => _searchCtrl.clear())
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${filtered.length} of ${_allOrders.length} total orders',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textGrey),
                    ),
                    Text(
                      '🟡 ${_allOrders.where((o) => o['status'] == 'pending').length} Pending Validation',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Orders List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : filtered.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (_, i) => _buildOrderCard(filtered[i]),
                      ),
          ),
        ],
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
            child: const Icon(Icons.receipt_outlined, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          Text(
            'No orders in ${_tabs[_tabController.index]}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text('New customer prescription orders will appear here automatically.', style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
        ],
      ),
    );
  }

  // ─── Comprehensive Order Card ──────────────────────────────────────────────
  Widget _buildOrderCard(Map<String, dynamic> order) {
    final id = order['id'] ?? '';
    final shortId = id.length > 8 ? id.substring(0, 8).toUpperCase() : id;
    final status = (order['status'] ?? 'pending').toString().toLowerCase();
    final orderType = (order['orderType'] ?? 'pickup').toString().toLowerCase();
    final isDelivery = orderType == 'delivery';
    final totalFcfa = order['totalFcfa'] ?? 0;
    final createdAt = DateTime.tryParse(order['createdAt'] ?? '');
    final patient = order['patient'] as Map<String, dynamic>? ?? {};
    final patientName = patient['name'] ?? 'Customer';
    final patientPhone = patient['phone'] ?? '';
    final deliveryAddress = order['deliveryAddress'] ?? 'Yaoundé';
    final items = (order['items'] as List? ?? []).cast<Map<String, dynamic>>();
    final driver = order['driver'] as Map<String, dynamic>?;
    final otp = order['otp'] ?? order['pickupCode'] ?? '';

    // Calculate time formatted
    String timeAgo = 'Just now';
    if (createdAt != null) {
      final diff = DateTime.now().difference(createdAt);
      if (diff.inMinutes < 60) {
        timeAgo = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        timeAgo = '${diff.inHours}h ago';
      } else {
        timeAgo = '${createdAt.day}/${createdAt.month}/${createdAt.year}';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'pending' ? const Color(0xFFFBBF24) : const Color(0xFFE5E7EB),
          width: status == 'pending' ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Order ID, Timestamp & Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: status == 'pending' ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                      child: Text('#$shortId', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    Text('⏱️ $timeAgo', style: const TextStyle(fontSize: 11, color: AppColors.textGrey, fontWeight: FontWeight.w500)),
                  ],
                ),
                _buildStatusBadge(status),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body: Customer Info & Fulfillment Method
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.lightGreen,
                      radius: 20,
                      child: Text(
                        patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(patientName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          if (patientPhone.isNotEmpty)
                            Text(patientPhone, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                        ],
                      ),
                    ),
                    // Quick Chat Button
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 20),
                      tooltip: 'Chat with Customer',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InAppChatScreen(
                              receiverId: patient['id'] ?? '',
                              receiverName: patientName,
                              receiverRole: 'patient',
                              orderId: id,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Fulfillment Mode & Payment Tags
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDelivery ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDelivery ? const Color(0xFFBFDBFE) : const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isDelivery ? Icons.delivery_dining : Icons.storefront, size: 16, color: isDelivery ? Colors.blue[800] : Colors.green[800]),
                          const SizedBox(width: 6),
                          Text(
                            isDelivery ? '🛵 Home Delivery' : '🏪 Counter Pickup',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDelivery ? Colors.blue[900] : Colors.green[900]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Total: $totalFcfa FCFA',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),

                if (isDelivery) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textGrey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text('Dropoff: $deliveryAddress', style: const TextStyle(fontSize: 11, color: AppColors.textGrey), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],

                // Assigned Driver if delivery
                if (isDelivery && driver != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: Row(
                      children: [
                        const Icon(Icons.two_wheeler, color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Assigned Driver: ${driver['user']?['name'] ?? 'Driver'} (${driver['vehicleInfo'] ?? 'Motorbike'})',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                        ),
                        Text(driver['user']?['phone'] ?? '', style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Prescribed / Ordered Items
                const Text('Medication Order Items:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textGrey)),
                const SizedBox(height: 4),
                ...items.map((item) {
                  final med = item['medication'] ?? {};
                  final medName = med['name'] ?? item['name'] ?? 'Medication';
                  final qty = item['quantity'] ?? 1;
                  final price = item['unitPriceFcfa'] ?? med['priceFcfa'] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('• $medName x$qty', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                        Text('$price FCFA', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 12),

                // ─── ACTION BUTTONS ACCORDING TO ORDER STAGE ──────────────────
                if (status == 'pending') ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('Validate & Confirm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          onPressed: () => _confirmOrder(id),
                        ),
                      ),
                    ],
                  ),
                ] else if (status == 'confirmed' || status == 'preparing') ...[
                  Row(
                    children: [
                      if (isDelivery) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.delivery_dining, size: 18),
                            label: const Text('Assign Delivery Driver', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            onPressed: () => _openAssignDriverModal(order),
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal[700],
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.storefront, size: 18),
                            label: const Text('Mark Ready for Pickup', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            onPressed: () => _markReady(id),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          icon: const Icon(Icons.verified_outlined, size: 16, color: AppColors.primary),
                          label: const Text('Verify OTP', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700)),
                          onPressed: () => _openVerifyOtpModal(order),
                        ),
                      ],
                    ],
                  ),
                ] else if (status == 'out_for_delivery') ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.blue),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.verified_outlined, size: 16, color: Colors.blue),
                          label: const Text('Validate Driver/Customer OTP', style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w700)),
                          onPressed: () => _openVerifyOtpModal(order),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFFEF3C7);
    Color text = const Color(0xFFB45309);
    String label = 'Pending Validation';

    if (status == 'confirmed' || status == 'preparing') {
      bg = const Color(0xFFDBEAFE);
      text = const Color(0xFF1E40AF);
      label = 'Preparing Meds';
    } else if (status == 'out_for_delivery') {
      bg = const Color(0xFFEDE9FE);
      text = const Color(0xFF6D28D9);
      label = 'Out for Delivery 🛵';
    } else if (status == 'picked_up' || status == 'delivered') {
      bg = const Color(0xFFDCFCE7);
      text = const Color(0xFF166534);
      label = 'Completed ✅';
    } else if (status == 'cancelled') {
      bg = const Color(0xFFFEE2E2);
      text = const Color(0xFF991B1B);
      label = 'Cancelled ❌';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: text, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}

// ─── ASSIGN DELIVERY DRIVER MODAL ─────────────────────────────────────────────
class _AssignDriverModal extends StatefulWidget {
  final Map<String, dynamic> order;
  final VoidCallback onDriverAssigned;

  const _AssignDriverModal({required this.order, required this.onDriverAssigned});

  @override
  State<_AssignDriverModal> createState() => _AssignDriverModalState();
}

class _AssignDriverModalState extends State<_AssignDriverModal> {
  final _api = ApiService();
  List<Map<String, dynamic>> _drivers = [];
  bool _loading = true;
  String? _selectedDriverId;
  bool _assigning = false;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    try {
      final res = await _api.get('/pharmacist/drivers');
      final list = (res.data['data'] as List? ?? []).cast<Map<String, dynamic>>();
      setState(() => _drivers = list);
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assignDriver() async {
    if (_selectedDriverId == null) return;
    setState(() => _assigning = true);
    try {
      await _api.post('/pharmacist/orders/${widget.order['id']}/assign-driver', data: {
        'driverProfileId': _selectedDriverId,
      });
      widget.onDriverAssigned();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to assign driver: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(margin: const EdgeInsets.only(top: 10, bottom: 4), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)), child: Icon(Icons.two_wheeler, color: Colors.blue[800], size: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Select Available Delivery Driver', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      Text('Order #${widget.order['id'].toString().substring(0, 8).toUpperCase()} • Dropoff: ${widget.order['deliveryAddress'] ?? 'Customer Address'}', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _drivers.isEmpty
                    ? const Center(child: Text('No active drivers found nearby.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _drivers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final d = _drivers[i];
                          final isSelected = _selectedDriverId == d['id'];
                          final isOnline = d['isOnline'] == true;

                          return GestureDetector(
                            onTap: () => setState(() => _selectedDriverId = d['id']),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isSelected ? Colors.blue[700]! : const Color(0xFFE2E8F0), width: isSelected ? 2 : 1),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isOnline ? const Color(0xFFDCFCE7) : Colors.grey[200],
                                    child: Icon(Icons.person, color: isOnline ? const Color(0xFF166534) : Colors.grey),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(d['name'] ?? 'Driver', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(color: isOnline ? const Color(0xFFDCFCE7) : Colors.grey[100], borderRadius: BorderRadius.circular(4)),
                                              child: Text(isOnline ? '🟢 Available' : 'Offline', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isOnline ? const Color(0xFF166534) : Colors.grey)),
                                            ),
                                          ],
                                        ),
                                        Text('🛵 ${d['vehicleInfo']} • 📞 ${d['phone']}', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                                        Text('📍 ${d['distanceKm']} km away • ⭐ ${d['rating'].toStringAsFixed(1)} (${d['totalDeliveries']} deliveries)', style: const TextStyle(fontSize: 10, color: Color(0xFF475569))),
                                      ],
                                    ),
                                  ),
                                  Radio<String>(
                                    value: d['id'],
                                    groupValue: _selectedDriverId,
                                    onChanged: (val) => setState(() => _selectedDriverId = val),
                                    activeColor: Colors.blue[700],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedDriverId != null ? Colors.blue[700] : Colors.grey,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _selectedDriverId != null && !_assigning ? _assignDriver : null,
                child: _assigning
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Dispatch Driver for Delivery', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
