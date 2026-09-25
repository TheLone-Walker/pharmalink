import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/location_autocomplete_field.dart';
import '../patient/my_orders_screen.dart';

import '../patient/digital_receipt_screen.dart';

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
    final auth = context.read<AuthService>();
    if (auth.user?['phone'] != null) {
      _phoneCtrl.text = auth.user!['phone'].toString();
    }
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if ((_method == 'momo' || _method == 'orange_money') && _phoneCtrl.text.trim().isEmpty) {
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
          'prescriptionId': widget.prescriptionId,
          'paymentMethod': _method,
        });
        orderId = orderRes.data['data']['id'];
      }

      // 2. Initiate payment with DigiPay / Mobile Money
      final payRes = await _api.post('/payments/initiate', data: {
        'orderId': orderId,
        'method': _method,
        'amountFcfa': widget.totalFcfa,
        'phoneNumber': _phoneCtrl.text.trim(),
        'description': 'PharmaLink Order #$orderId',
      });

      if (!mounted) return;

      final successMsg = payRes.data['message'] ?? 'Payment processed successfully!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMsg), backgroundColor: AppColors.primary),
      );

      // Navigate directly to Official Digital Receipt Screen!
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DigitalReceiptScreen(orderId: orderId),
        ),
      );
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
                    Text(widget.orderType == 'delivery' ? '🚴 Delivery' : '🏪 Pharmacy Pick Up',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  ]),
                  const Divider(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Total to Pay', style: TextStyle(color: AppColors.textGrey, fontSize: 14)),
                    Text('FCFA ${widget.totalFcfa.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.primary)),
                  ]),
                ]),
              ),

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
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: PharmaButton(
            label: 'Confirm & Pay FCFA ${widget.totalFcfa.toStringAsFixed(0)}',
            onPressed: _pay,
            isLoading: _loading,
            icon: Icons.lock_outline,
          ),
        ),
      ]),
    );
  }
}
