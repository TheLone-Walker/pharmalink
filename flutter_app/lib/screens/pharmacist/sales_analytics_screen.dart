import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

class SalesAnalyticsScreen extends StatefulWidget {
  const SalesAnalyticsScreen({super.key});

  @override
  State<SalesAnalyticsScreen> createState() => _SalesAnalyticsScreenState();
}

class _SalesAnalyticsScreenState extends State<SalesAnalyticsScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String _selectedRange = 'month'; // 'today', 'week', 'month', 'all'

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/pharmacist/analytics', params: {'range': _selectedRange});
      setState(() => _data = res.data['data']);
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Pharmacy Sales & Reports'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAnalytics),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Period Selector Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _rangeChip('today', '📅 Today'),
                        const SizedBox(width: 8),
                        _rangeChip('week', '🗓️ This Week'),
                        const SizedBox(width: 8),
                        _rangeChip('month', '📊 This Month'),
                        const SizedBox(width: 8),
                        _rangeChip('all', '📈 All Time'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // KPI Matrix Cards
                  _buildKPIGrid(),
                  const SizedBox(height: 18),

                  // Delivery vs Pickup Ratio
                  _buildFulfillmentBreakdown(),
                  const SizedBox(height: 18),

                  // Payment Methods Breakdown
                  _buildPaymentBreakdown(),
                  const SizedBox(height: 20),

                  // Top Selling Medications
                  _buildTopProducts(),
                  const SizedBox(height: 20),

                  // Recent Orders Stream
                  _buildRecentOrders(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _rangeChip(String rangeKey, String label) {
    final isSelected = _selectedRange == rangeKey;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? Colors.white : const Color(0xFF334155))),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      side: BorderSide(color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0)),
      onSelected: (_) {
        setState(() => _selectedRange = rangeKey);
        _loadAnalytics();
      },
    );
  }

  Widget _buildKPIGrid() {
    final totalSales = _data?['totalSales'] ?? 0;
    final orderCount = _data?['orderCount'] ?? 0;
    final avgOrderValue = _data?['avgOrderValue'] ?? 0;
    final totalPlaced = _data?['totalOrdersPlaced'] ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        _kpiCard('Total Revenue', '$totalSales FCFA', Icons.account_balance_wallet_outlined, const Color(0xFF0D9488), const Color(0xFFCCFBF1)),
        _kpiCard('Completed Orders', '$orderCount Orders', Icons.check_circle_outline, const Color(0xFF2563EB), const Color(0xFFDBEAFE)),
        _kpiCard('Avg. Order Value', '$avgOrderValue FCFA', Icons.analytics_outlined, const Color(0xFFD97706), const Color(0xFFFEF3C7)),
        _kpiCard('Total Inquiries', '$totalPlaced Placed', Icons.receipt_long_outlined, const Color(0xFF7C3AED), const Color(0xFFEDE9FE)),
      ],
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: bg, shape: BoxShape.circle), child: Icon(icon, color: color, size: 16)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildFulfillmentBreakdown() {
    final pickup = _data?['pickupCount'] ?? 0;
    final delivery = _data?['deliveryCount'] ?? 0;
    final total = pickup + delivery;
    final pickupPct = total > 0 ? (pickup / total) * 100 : 50.0;
    final deliveryPct = total > 0 ? (delivery / total) * 100 : 50.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Fulfillment Distribution', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                Expanded(flex: pickupPct.round().clamp(1, 100), child: Container(height: 12, color: const Color(0xFF10B981))),
                Expanded(flex: deliveryPct.round().clamp(1, 100), child: Container(height: 12, color: const Color(0xFF3B82F6))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('🏪 Counter Pickup: $pickup (${pickupPct.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
              Row(children: [
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('🛵 Home Delivery: $delivery (${deliveryPct.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBreakdown() {
    final pm = _data?['paymentMethods'] as Map<String, dynamic>? ?? {};
    final momo = pm['momo'] ?? 0;
    final orange = pm['orange_money'] ?? 0;
    final card = pm['card'] ?? 0;
    final cash = pm['cash'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Revenue by Payment Channel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark)),
          const SizedBox(height: 12),
          _paymentRow('💛 MTN Mobile Money', '$momo FCFA', const Color(0xFFFBBF24)),
          const Divider(height: 14),
          _paymentRow('🧡 Orange Money', '$orange FCFA', const Color(0xFFFB923C)),
          const Divider(height: 14),
          _paymentRow('💳 Credit / Debit Card', '$card FCFA', const Color(0xFF60A5FA)),
          const Divider(height: 14),
          _paymentRow('💵 Cash on Handover', '$cash FCFA', const Color(0xFF34D399)),
        ],
      ),
    );
  }

  Widget _paymentRow(String name, String amount, Color tagColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: tagColor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
          ],
        ),
        Text(amount, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
      ],
    );
  }

  Widget _buildTopProducts() {
    final topList = (_data?['topProducts'] as List? ?? []).cast<Map<String, dynamic>>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🔥 Top-Selling Medications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark)),
          const SizedBox(height: 12),
          if (topList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No medication sales recorded in this period.', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
            )
          else
            ...topList.asMap().entries.map((entry) {
              final idx = entry.key;
              final p = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(color: idx < 3 ? AppColors.primary : Colors.grey[400], shape: BoxShape.circle),
                      child: Center(child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          Text(p['category'] ?? 'Medication', style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${p['unitsSold']} units', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primary)),
                        Text('${p['revenueFcfa']} FCFA', style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRecentOrders() {
    final recent = (_data?['recentOrders'] as List? ?? []).cast<Map<String, dynamic>>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Order Transactions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark)),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            const Text('No recent orders.', style: TextStyle(fontSize: 12, color: AppColors.textGrey))
          else
            ...recent.map((o) {
              final id = o['id']?.toString().substring(0, 8).toUpperCase() ?? '';
              final patient = o['patient']?['name'] ?? 'Customer';
              final total = o['totalFcfa'] ?? 0;
              final status = o['status'] ?? 'pending';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('#$id • $patient', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        Text('Status: ${status.toString().toUpperCase()}', style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                      ],
                    ),
                    Text('$total FCFA', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primary)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
