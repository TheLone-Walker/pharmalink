import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

class AdminTransactionsScreen extends StatefulWidget {
  const AdminTransactionsScreen({super.key});
  @override
  State<AdminTransactionsScreen> createState() => _AdminTransactionsScreenState();
}

class _AdminTransactionsScreenState extends State<AdminTransactionsScreen> {
  final _api = ApiService();
  List _transactions = [];
  bool _loading = true;
  double _totalRevenue = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await _api.get('/admin/transactions');
      final list = res.data['data'] as List? ?? [];
      setState(() {
        _transactions = list;
        _totalRevenue = list.fold(0.0, (sum, t) =>
          sum + (t['status'] == 'success' ? (double.tryParse(t['amountFcfa'].toString()) ?? 0) : 0));
      });
    } catch (_) {} finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Transactions')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(children: [
              // Summary banner
              Container(
                padding: const EdgeInsets.all(20),
                color: AppColors.primary,
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Total Revenue', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Text('FCFA ${_totalRevenue.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${_transactions.length}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                    const Text('transactions', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                ]),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _transactions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = _transactions[i];
                    final isSuccess = t['status'] == 'success';
                    final date = DateTime.tryParse(t['createdAt'] ?? '');
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSuccess ? AppColors.lightGreen : Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.receipt_outlined,
                          color: isSuccess ? AppColors.primary : Colors.red, size: 18),
                      ),
                      title: Text('FCFA ${t['amountFcfa']}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t['user']?['name'] ?? '', style: const TextStyle(fontSize: 12)),
                        Text('${t['method']?.toString().replaceAll('_', ' ')} • ${t['type']}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                        if (date != null)
                          Text('${date.day}/${date.month}/${date.year}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                      ]),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSuccess ? AppColors.lightGreen : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(t['status'] ?? '',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                            color: isSuccess ? AppColors.primary : Colors.red)),
                      ),
                    );
                  },
                ),
              ),
            ]),
    );
  }
}
