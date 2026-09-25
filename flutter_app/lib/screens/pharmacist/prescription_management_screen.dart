import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  List<dynamic> _prescriptions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/prescriptions');
      setState(() => _prescriptions = res.data['data'] ?? []);
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> _filtered(String tabType) {
    if (tabType == 'pending') {
      return _prescriptions.where((p) {
        final vStatus = p['validationStatus'] ?? (p['status'] == 'sent_to_pharmacy' ? 'pending' : '');
        return vStatus == 'pending' || p['status'] == 'sent_to_pharmacy';
      }).toList();
    } else if (tabType == 'approved') {
      return _prescriptions.where((p) {
        final vStatus = p['validationStatus'] ?? '';
        return vStatus == 'approved' || p['status'] == 'approved' || p['status'] == 'fulfilled';
      }).toList();
    } else if (tabType == 'rejected') {
      return _prescriptions.where((p) {
        final vStatus = p['validationStatus'] ?? '';
        return vStatus == 'rejected' || p['status'] == 'cancelled';
      }).toList();
    }
    return _prescriptions;
  }

  Future<void> _validatePrescription(String id, String action, {String? reason}) async {
    try {
      final res = await _api.patch('/prescriptions/$id/validate', data: {
        'action': action,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });

      if (mounted) {
        final isApprove = action == 'approve';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isApprove
                ? '✅ Prescription validated & approved successfully! Patient notified.'
                : '❌ Prescription rejected. Patient has been notified with the reason.'),
            backgroundColor: isApprove ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update prescription status. Please try again.')),
        );
      }
    }
  }

  void _showRejectDialog(String id) {
    final reasonCtrl = TextEditingController(text: 'Prescription document is illegible or missing doctor signature');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Text('Reject Prescription', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please provide a clear reason to explain why this prescription cannot be dispensed:',
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.textGrey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              style: GoogleFonts.plusJakartaSans(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. Expired date, missing ONMC license stamp, dosage unclear...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _validatePrescription(id, 'reject', reason: reasonCtrl.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );
  }

  void _viewDocumentModal(String? url, String docName) {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No physical prescription file attached.')),
      );
      return;
    }

    final fullUrl = url.startsWith('http') ? url : '${AppConstants.baseUrl.replaceAll('/api', '')}$url';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Prescription Document', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    fullUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.picture_as_pdf_rounded, size: 48, color: Color(0xFFEF4444)),
                          const SizedBox(height: 8),
                          Text('Document file attached:\n$url', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _fulfill(String id) async {
    try {
      await _api.patch('/prescriptions/$id/fulfill');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prescription marked as fulfilled & ready!'), backgroundColor: AppColors.primary),
      );
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Prescription Validation & Orders', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        elevation: 0,
        backgroundColor: AppColors.primary,
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: '⏳ Needs Validation'),
            Tab(text: '✅ Approved'),
            Tab(text: '❌ Rejected'),
            Tab(text: '📁 All'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tab,
              children: ['pending', 'approved', 'rejected', 'all'].map((tabType) {
                final list = _filtered(tabType);
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_outlined, size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No prescriptions in this section.', style: GoogleFonts.plusJakartaSans(color: AppColors.textGrey, fontSize: 13)),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _prescriptionCard(list[i] as Map<String, dynamic>),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _prescriptionCard(Map<String, dynamic> p) {
    final date = DateTime.tryParse(p['createdAt'] ?? '');
    final vStatus = p['validationStatus'] ?? (p['status'] == 'sent_to_pharmacy' ? 'pending' : p['status']);
    final isPending = vStatus == 'pending' || p['status'] == 'sent_to_pharmacy';
    final isApproved = vStatus == 'approved' || p['status'] == 'approved' || p['status'] == 'fulfilled';
    final isRejected = vStatus == 'rejected' || p['status'] == 'cancelled';
    final docUrl = p['documentUrl'] as String?;
    final docName = p['doctorName'] ?? (p['doctor']?['name'] != null ? 'Dr. ${p['doctor']['name']}' : 'Physician');

    Color badgeColor = Colors.orange;
    Color badgeBg = Colors.orange.withOpacity(0.1);
    String badgeText = 'PENDING VALIDATION';

    if (isApproved) {
      badgeColor = const Color(0xFF10B981);
      badgeBg = const Color(0xFFD1FAE5);
      badgeText = p['status'] == 'fulfilled' ? 'FULFILLED' : 'VALIDATED & APPROVED';
    } else if (isRejected) {
      badgeColor = const Color(0xFFEF4444);
      badgeBg = const Color(0xFFFEE2E2);
      badgeText = 'REJECTED';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending ? const Color(0xFFFBBF24) : (isApproved ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0)),
          width: isPending ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          p['patient']?['name'] ?? 'Patient',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Prescribing Doctor: $docName',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textGrey, fontWeight: FontWeight.w500),
                    ),
                    if (p['hospital'] != null)
                      Text(
                        'Facility: ${p['hospital']}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFF64748B)),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  badgeText,
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: badgeColor, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Attached Document Preview Badge
          if (docUrl != null && docUrl.isNotEmpty) ...[
            InkWell(
              onTap: () => _viewDocumentModal(docUrl, docName),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attachment_rounded, size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Patient Attached Prescription Document (Tap to Inspect)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF1E40AF),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(Icons.remove_red_eye_outlined, size: 16, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Medications List
          Text('Prescribed Items & Regimen:', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
          const SizedBox(height: 6),
          ...(p['items'] as List? ?? []).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.medication_rounded, color: AppColors.primary, size: 15),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['medicationName'] ?? '', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13)),
                          Text(
                            '${item['dosage'] ?? '1 dose'} • ${item['instructions'] ?? 'Per Rx'} • ${item['durationDays'] ?? 7} days',
                            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textGrey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),

          if (p['rejectionReason'] != null && p['rejectionReason'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
              child: Text(
                'Rejection Reason: ${p['rejectionReason']}',
                style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFF991B1B), fontWeight: FontWeight.w600),
              ),
            ),
          ],

          if (date != null) ...[
            const SizedBox(height: 10),
            Text(
              'Received: ${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF94A3B8)),
            ),
          ],

          // Action Buttons
          if (isPending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(p['id']),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Reject Rx'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      minimumSize: const Size(0, 42),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _validatePrescription(p['id'], 'approve'),
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: const Text('Validate & Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      minimumSize: const Size(0, 42),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (isApproved && p['status'] != 'fulfilled') ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _fulfill(p['id']),
              icon: const Icon(Icons.task_alt_rounded, size: 16),
              label: const Text('Mark Order as Fulfilled & Ready'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

