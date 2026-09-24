import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';

// ─── Inventory Screen ─────────────────────────────────────────────────────────
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _api = ApiService();
  List _meds = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await _api.get('/pharmacist/inventory');
      setState(() => _meds = res.data['data'] ?? []);
    } catch (_) {} finally { setState(() => _loading = false); }
  }

  void _showAddDialog([Map? med]) {
    final nameCtrl = TextEditingController(text: med?['name'] ?? '');
    final priceCtrl = TextEditingController(text: med?['priceFcfa']?.toString() ?? '');
    final stockCtrl = TextEditingController(text: med?['stockQuantity']?.toString() ?? '');
    final catCtrl = TextEditingController(text: med?['category'] ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(med == null ? 'Add Medication to Inventory' : 'Edit Medication Stock', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Medication Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 6),
              Autocomplete<String>(
                initialValue: TextEditingValue(text: nameCtrl.text),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.trim().isEmpty) {
                    return AppConstants.cameroonMedications.take(6);
                  }
                  final q = textEditingValue.text.toLowerCase().trim();
                  return AppConstants.cameroonMedications.where((m) => m.toLowerCase().contains(q));
                },
                onSelected: (String sel) {
                  nameCtrl.text = sel;
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  if (nameCtrl.text.isNotEmpty && controller.text != nameCtrl.text) {
                    controller.text = nameCtrl.text;
                  }
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: (v) => nameCtrl.text = v,
                    decoration: InputDecoration(
                      hintText: 'e.g. Artemether, Paracetamol, Coartem',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              const Text('Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 6),
              Autocomplete<String>(
                initialValue: TextEditingValue(text: catCtrl.text),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.trim().isEmpty) {
                    return AppConstants.cameroonMedicationCategories.take(6);
                  }
                  final q = textEditingValue.text.toLowerCase().trim();
                  return AppConstants.cameroonMedicationCategories.where((c) => c.toLowerCase().contains(q));
                },
                onSelected: (String sel) {
                  catCtrl.text = sel;
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  if (catCtrl.text.isNotEmpty && controller.text != catCtrl.text) {
                    controller.text = catCtrl.text;
                  }
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: (v) => catCtrl.text = v,
                    decoration: InputDecoration(
                      hintText: 'e.g. Antimalarials, Pain Relief, Antibiotics',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: 'Price (FCFA)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stockCtrl,
                decoration: const InputDecoration(labelText: 'Stock Quantity', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final data = {
                'name': nameCtrl.text.trim(),
                'priceFcfa': priceCtrl.text.trim(),
                'stockQuantity': stockCtrl.text.trim(),
                'category': catCtrl.text.trim(),
              };
              if (med == null) await _api.post('/pharmacist/inventory', data: data);
              else await _api.put('/pharmacist/inventory/${med['id']}', data: data);
              Navigator.pop(context);
              _load();
            },
            child: const Text('Save Medication'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showAddDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _meds.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final m = _meds[i];
                final isLow = (m['stockQuantity'] ?? 0) < 10;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isLow ? Colors.orange.withOpacity(0.4) : const Color(0xFFEEEEEE))),
                  child: Row(children: [
                    Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.medication, color: AppColors.primary, size: 24)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text('FCFA ${m['priceFcfa']}', style: const TextStyle(color: AppColors.primary, fontSize: 13)),
                      Row(children: [
                        Icon(isLow ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                          color: isLow ? Colors.orange : AppColors.accent, size: 14),
                        Text(' Stock: ${m['stockQuantity']}', style: TextStyle(fontSize: 12, color: isLow ? Colors.orange : AppColors.textGrey)),
                      ]),
                    ])),
                    PopupMenuButton(itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                    ], onSelected: (v) async {
                      if (v == 'edit') _showAddDialog(m);
                      else { await _api.delete('/pharmacist/inventory/${m['id']}'); _load(); }
                    }),
                  ]),
                );
              },
            ),
    );
  }
}

