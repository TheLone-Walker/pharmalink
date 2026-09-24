import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';

class PrescriptionManagementScreen extends StatefulWidget {
  const PrescriptionManagementScreen({super.key});
  @override
  State<PrescriptionManagementScreen> createState() => _PrescriptionManagementScreenState();
}

class _PrescriptionManagementScreenState extends State<PrescriptionManagementScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tab;
  List _prescriptions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final res = await _api.get('/prescriptions');
      setState(() => _prescriptions = res.data['data'] ?? []);
    } catch (_) {} finally { setState(() => _loading = false); }
  }

  List _filtered(String status) =>
      _prescriptions.where((p) => p['status'] == status).toList();

  Future<void> _fulfill(String id) async {
    try {
      await _api.patch('/prescriptions/$id/fulfill');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prescription marked as fulfilled'), backgroundColor: AppColors.primary));
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prescriptions'),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [Tab(text: 'Pending'), Tab(text: 'Fulfilled'), Tab(text: 'All')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tab,
              children: ['sent_to_pharmacy', 'fulfilled', ''].map((status) {
                final list = status.isEmpty ? _prescriptions : _filtered(status);
                if (list.isEmpty) {
                  return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.description_outlined, size: 60, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    const Text('No prescriptions', style: TextStyle(color: AppColors.textGrey)),
                  ]));
                }
                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _prescriptionCard(list[i]),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _prescriptionCard(Map p) {
    final date = DateTime.tryParse(p['createdAt'] ?? '');
    final isFulfilled = p['status'] == 'fulfilled';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isFulfilled ? AppColors.lightGreen : const Color(0xFFEEEEEE), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p['patient']?['name'] ?? 'Patient',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text('Dr. ${p['doctor']?['name'] ?? ''}',
              style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isFulfilled ? AppColors.lightGreen : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(p['status']?.toString().replaceAll('_', ' ').toUpperCase() ?? '',
                style: TextStyle(fontSize: 9, color: isFulfilled ? AppColors.primary : Colors.orange, fontWeight: FontWeight.w700)),
            ),
            if (date != null) ...[
              const SizedBox(height: 2),
              Text('${date.day}/${date.month}/${date.year}',
                style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
            ],
          ]),
        ]),
        const Divider(height: 16),
        ...(p['items'] as List? ?? []).map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            const Icon(Icons.medication_outlined, color: AppColors.accent, size: 15),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['medicationName'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              Text('${item['dosage'] ?? ''} • ${item['instructions'] ?? ''} • ${item['durationDays'] ?? ''} days',
                style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
            ])),
          ]),
        )),
        if (p['notes'] != null && p['notes'].isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Note: ${p['notes']}',
            style: const TextStyle(fontSize: 12, color: AppColors.textGrey, fontStyle: FontStyle.italic)),
        ],
        if (!isFulfilled) ...[
          const SizedBox(height: 12),
          PharmaButton(
            label: 'Mark as Fulfilled',
            onPressed: () => _fulfill(p['id']),
            icon: Icons.check_circle_outline,
          ),
        ],
      ]),
    );
  }
}
