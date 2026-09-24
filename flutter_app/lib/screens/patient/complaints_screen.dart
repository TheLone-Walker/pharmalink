import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});
  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  final _api = ApiService();
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  List _complaints = [];
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _subjectCtrl.dispose(); _bodyCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final res = await _api.get('/complaints');
      setState(() => _complaints = res.data['data'] ?? []);
    } catch (_) {} finally { setState(() => _loading = false); }
  }

  Future<void> _submit() async {
    if (_subjectCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields'), backgroundColor: AppColors.error));
      return;
    }
    setState(() => _submitting = true);
    try {
      await _api.post('/complaints', data: {
        'subject': _subjectCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
      });
      _subjectCtrl.clear();
      _bodyCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint submitted!'), backgroundColor: AppColors.primary));
      _load();
    } catch (_) {} finally { setState(() => _submitting = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Complaint')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Form
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lightGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('New Complaint', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primary)),
              const SizedBox(height: 14),
              PharmaField(
                label: 'Subject',
                hint: 'e.g. Delivery issue',
                prefixIcon: Icons.subject,
                controller: _subjectCtrl,
              ),
              const SizedBox(height: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF555555))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _bodyCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Describe your issue in detail...',
                    hintStyle: TextStyle(color: Colors.black26, fontSize: 13),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              PharmaButton(label: 'Submit Complaint', onPressed: _submit, isLoading: _submitting, icon: Icons.send),
            ]),
          ),
          const SizedBox(height: 24),
          const Text('My Complaints', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: AppColors.primary))
          else if (_complaints.isEmpty)
            Center(child: Column(children: [
              Icon(Icons.report_outlined, size: 50, color: Colors.grey[300]),
              const SizedBox(height: 8),
              const Text('No complaints submitted', style: TextStyle(color: AppColors.textGrey)),
            ]))
          else
            ..._complaints.map((c) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Text(c['subject'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c['status'] == 'resolved' ? AppColors.lightGreen : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(c['status'] ?? '',
                      style: TextStyle(fontSize: 10, color: c['status'] == 'resolved' ? AppColors.primary : Colors.orange, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(c['body'] ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textGrey), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (c['adminResponse'] != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(8)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text(c['adminResponse'], style: const TextStyle(fontSize: 12, color: AppColors.primary))),
                    ]),
                  ),
                ],
              ]),
            )),
        ]),
      ),
    );
  }
}
