import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});
  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final _api = ApiService();
  List _transactions = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await _api.get('/transactions/mine');
      setState(() => _transactions = res.data['data'] ?? []);
    } catch (_) {} finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _transactions.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.receipt_long, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  const Text('No transactions yet', style: TextStyle(color: AppColors.textGrey)),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _transactions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = _transactions[i];
                    final isSuccess = t['status'] == 'success';
                    final date = DateTime.tryParse(t['createdAt'] ?? '');
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSuccess ? AppColors.lightGreen : Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _methodIcon(t['method']),
                          color: isSuccess ? AppColors.primary : Colors.red,
                          size: 20,
                        ),
                      ),
                      title: Text('FCFA ${t['amountFcfa']}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${t['method']?.toString().replaceAll('_', ' ').toUpperCase()} • ${t['type']}',
                          style: const TextStyle(fontSize: 11)),
                        if (date != null) Text('${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2,'0')}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                      ]),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSuccess ? AppColors.lightGreen : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(t['status'] ?? '',
                          style: TextStyle(fontSize: 10, color: isSuccess ? AppColors.primary : Colors.red, fontWeight: FontWeight.w600)),
                      ),
                    );
                  },
                ),
    );
  }

  IconData _methodIcon(String? method) {
    switch (method) {
      case 'momo': return Icons.phone_android;
      case 'orange_money': return Icons.phone_iphone;
      case 'card': return Icons.credit_card_outlined;
      default: return Icons.money;
    }
  }
}
