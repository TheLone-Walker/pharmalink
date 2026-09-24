import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';
import '../shared/payment_screen.dart';

class PharmacyDetailScreen extends StatefulWidget {
  final String pharmacyId;
  final String medicationId;
  const PharmacyDetailScreen({super.key, required this.pharmacyId, required this.medicationId});
  @override
  State<PharmacyDetailScreen> createState() => _PharmacyDetailScreenState();
}

class _PharmacyDetailScreenState extends State<PharmacyDetailScreen> {
  final _api = ApiService();
  Map? _pharmacy;
  Map? _medication;
  bool _loading = true;
  int _qty = 1;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r1 = await _api.get('/pharmacies/${widget.pharmacyId}');
      final r2 = await _api.get('/medications/${widget.medicationId}');
      setState(() { _pharmacy = r1.data['data']; _medication = r2.data['data']; });
    } catch (_) {} finally { setState(() => _loading = false); }
  }

  void _showOrderOptions() {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Select Order Option', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          _orderOption(Icons.delivery_dining, 'Delivery', 'Pay online → Pharmacy prepares → Driver tracks', () { Navigator.pop(context); _placeOrder('delivery'); }),
          const SizedBox(height: 12),
          _orderOption(Icons.store_outlined, 'Pick Up at Pharmacy', 'Pay online → Go to pharmacy → Show code', () { Navigator.pop(context); _placeOrder('pickup'); }),
          const SizedBox(height: 8),
          TextButton(onPressed: () => Navigator.pop(context), child: const Center(child: Text('Cancel', style: TextStyle(color: AppColors.textGrey)))),
        ]),
      ),
    );
  }

  Widget _orderOption(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: AppColors.lightGreen, width: 1.5), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.lightGreen, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.primary, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
          ])),
          const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textGrey),
        ]),
      ),
    );
  }

  Future<void> _placeOrder(String type) async {
    if (_medication == null || _pharmacy == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentScreen(
      orderId: null,
      orderType: type,
      pharmacyId: widget.pharmacyId,
      items: [{'medicationId': widget.medicationId, 'quantity': _qty}],
      totalFcfa: (double.tryParse(_medication!['priceFcfa'].toString()) ?? 0) * _qty,
    )));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    if (_pharmacy == null) return const Scaffold(body: Center(child: Text('Pharmacy not found')));

    return Scaffold(
      appBar: AppBar(title: Text(_pharmacy!['pharmacyName'] ?? 'Pharmacy')),
      body: SingleChildScrollView(
        child: Column(children: [
          Container(height: 160, color: AppColors.lightGreen,
            child: Center(child: Icon(Icons.local_pharmacy, size: 60, color: AppColors.primary))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_pharmacy!['pharmacyName'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.star, color: Colors.amber, size: 16),
                const Text(' 4.8 (128 reviews)', style: TextStyle(fontSize: 12)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.location_on_outlined, color: AppColors.textGrey, size: 14),
                Expanded(child: Text(_pharmacy!['pharmacyAddress'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textGrey))),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.access_time_outlined, color: AppColors.accent, size: 14),
                Text(' ${_pharmacy!['openingHours'] ?? 'Open'}', style: const TextStyle(fontSize: 12, color: AppColors.accent)),
              ]),
              const Divider(height: 28),
              if (_medication != null) ...[
                const Text('Medication Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(_medication!['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('FCFA ${_medication!['priceFcfa']}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16)),
                ]),
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(6)),
                  child: Text('In Stock (${_medication!['stockQuantity']})', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600))),
                const SizedBox(height: 12),
                Row(children: [
                  const Text('Quantity:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.remove_circle_outline, color: AppColors.primary), onPressed: () { if (_qty > 1) setState(() => _qty--); }),
                  Text('$_qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  IconButton(icon: const Icon(Icons.add_circle_outline, color: AppColors.primary), onPressed: () => setState(() => _qty++)),
                ]),
              ],
              const SizedBox(height: 20),
              PharmaButton(label: 'Order for Delivery', onPressed: _showOrderOptions, icon: Icons.delivery_dining),
              const SizedBox(height: 10),
              PharmaButton(label: 'Pay Online & Pick Up', onPressed: () => _placeOrder('pickup'), outlined: true, icon: Icons.store_outlined),
            ]),
          ),
        ]),
      ),
    );
  }
}
