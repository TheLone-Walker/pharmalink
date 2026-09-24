import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/location_autocomplete_field.dart';
import '../patient/my_orders_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String? orderId;
  final String orderType;
  final String pharmacyId;
  final List<Map<String, dynamic>> items;
  final double totalFcfa;

  const PaymentScreen({
    super.key,
    this.orderId,
    required this.orderType,
    required this.pharmacyId,
    required this.items,
    required this.totalFcfa,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _api = ApiService();
  String _method = 'momo';
  bool _loading = false;
  final _addressCtrl = TextEditingController(text: 'Quartier Bastos, Yaoundé');

  final _methods = [
    {'id': 'momo', 'label': 'MTN Mobile Money', 'icon': Icons.phone_android},
    {'id': 'orange_money', 'label': 'Orange Money', 'icon': Icons.phone_iphone},
    {'id': 'card', 'label': 'Bank Card', 'icon': Icons.credit_card_outlined},
    {'id': 'cash', 'label': 'Cash on Delivery', 'icon': Icons.money},
  ];

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    setState(() => _loading = true);
    try {
      // Create order first if no orderId
      String orderId = widget.orderId ?? '';
      if (orderId.isEmpty) {
        final orderRes = await _api.post('/orders', data: {
          'pharmacyId': widget.pharmacyId,
          'orderType': widget.orderType,
          'items': widget.items,
          'deliveryAddress': widget.orderType == 'delivery' ? _addressCtrl.text.trim() : null,
        });
        orderId = orderRes.data['data']['id'];
      }

      // Initiate payment
      await _api.post('/payments/initiate', data: {
        'orderId': orderId,
        'method': _method,
        'amountFcfa': widget.totalFcfa,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment successful!'), backgroundColor: AppColors.primary),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
        (route) => route.isFirst,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed. Try again.'), backgroundColor: AppColors.error),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Order Type', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                    Text(widget.orderType == 'delivery' ? '🚴 Delivery' : '🏪 Pick Up',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Total', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                    Text('FCFA ${widget.totalFcfa.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.primary)),
                  ]),
                ]),
              ),
              if (widget.orderType == 'delivery') ...[
                const SizedBox(height: 20),
                const Text('Delivery Dropoff Address', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                LocationAutocompleteField(
                  controller: _addressCtrl,
                  label: 'Delivery Dropoff Address',
                  hint: 'Type quarter or landmark (e.g. Bastos, Warda, Akwa)...',
                ),
              ],
              const SizedBox(height: 24),
              const Text('Payment Method', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ..._methods.map((m) => GestureDetector(
                onTap: () => setState(() => _method = m['id'] as String),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _method == m['id'] ? AppColors.lightGreen : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _method == m['id'] ? AppColors.primary : const Color(0xFFEEEEEE),
                      width: 1.5,
                    ),
                  ),
                  child: Row(children: [
                    Icon(m['icon'] as IconData, color: _method == m['id'] ? AppColors.primary : AppColors.textGrey),
                    const SizedBox(width: 12),
                    Text(m['label'] as String, style: TextStyle(
                      fontWeight: _method == m['id'] ? FontWeight.w600 : FontWeight.normal,
                      color: _method == m['id'] ? AppColors.primary : AppColors.textDark,
                    )),
                    const Spacer(),
                    if (_method == m['id'])
                      const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                  ]),
                ),
              )),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: PharmaButton(
            label: 'Pay FCFA ${widget.totalFcfa.toStringAsFixed(0)}',
            onPressed: _pay,
            isLoading: _loading,
            icon: Icons.lock_outline,
          ),
        ),
      ]),
    );
  }
}
