import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';

class EarningsScreen extends StatefulWidget {
  final bool isTab;
  const EarningsScreen({super.key, this.isTab = false});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _earningsData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/driver/earnings');
      if (res.data != null && res.data['data'] != null) {
        setState(() {
          _earningsData = Map<String, dynamic>.from(res.data['data']);
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : RefreshIndicator(
            onRefresh: _loadEarnings,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Hero Earnings Card ──────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF065F46), Color(0xFF059669), AppColors.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL DRIVER EARNINGS',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.percent, size: 12, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    '10% Commission',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'FCFA ${(_earningsData?['totalEarnings'] ?? 0).toString()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white24, height: 1),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _statItem(
                              icon: Icons.check_circle_outline,
                              label: 'Total Trips',
                              value: '${_earningsData?['tripCount'] ?? 0}',
                            ),
                            Container(width: 1, height: 28, color: Colors.white24),
                            _statItem(
                              icon: Icons.today_outlined,
                              label: 'Today Earnings',
                              value: 'FCFA ${_earningsData?['todayEarnings'] ?? 0}',
                            ),
                            Container(width: 1, height: 28, color: Colors.white24),
                            _statItem(
                              icon: Icons.electric_bolt,
                              label: 'Status',
                              value: 'Active',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ─── Commission Explanation Banner ────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'You earn an automatic 10% cash commission on every successfully delivered and digitally signed order.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── Trips / Payouts List ─────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Trip Payout History',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
                      ),
                      Text(
                        '${(_earningsData?['deliveries'] as List? ?? []).length} Deliveries',
                        style: const TextStyle(fontSize: 12, color: AppColors.textGrey, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if ((_earningsData?['deliveries'] as List? ?? []).isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(Icons.account_balance_wallet_outlined, size: 54, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            const Text(
                              'No completed deliveries yet',
                              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textGrey),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Complete your first delivery to start earning!',
                              style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...(_earningsData!['deliveries'] as List).map((d) {
                      final order = d['order'] ?? {};
                      final totalFcfa = double.tryParse(order['totalFcfa']?.toString() ?? '0') ?? 0.0;
                      final driverCut = (totalFcfa * 0.1).round();
                      final orderId = (order['id'] ?? d['orderId'] ?? '').toString();
                      final shortId = orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase();
                      final pharmacyName = order['pharmacy']?['pharmacyName'] ?? 'Pharmacy Partner';
                      final dropoff = order['deliveryAddress'] ?? 'Customer Dropoff';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.lightGreen,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.delivery_dining, color: AppColors.primary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Order #$shortId',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0FDF4),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFBBF7D0)),
                                        ),
                                        child: const Text(
                                          'DELIVERED',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF16A34A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    pharmacyName,
                                    style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Dropoff: $dropoff',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '+FCFA $driverCut',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'of FCFA ${totalFcfa.round()}',
                                  style: const TextStyle(fontSize: 10, color: AppColors.textGrey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
          );

    if (widget.isTab) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('My Earnings')),
      body: body,
    );
  }

  Widget _statItem({required IconData icon, required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: Colors.white70),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
