import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/logout_button.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});
  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> with WidgetsBindingObserver {
  final _api = ApiService();
  Map? _stats;
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();

    // Refresh immediately on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthService>().refreshUser();
    });

    // Silent background refresh every 60 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) context.read<AuthService>().refreshUser();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AuthService>().refreshUser();
    }
  }

  Future<void> _load() async {
    try {
      final res = await _api.get('/admin/stats');
      setState(() => _stats = res.data['data']);
    } catch (_) {} finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Row(children: const [
            Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text('Admin Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
            HeaderLogoutButton(),
          ]),
        ),
        Expanded(child: Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Overview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4,
                      children: [
                        StatCard(title: 'Total Users', value: '${_stats?['users'] ?? 0}', icon: Icons.people_outlined),
                        StatCard(title: 'Total Orders', value: '${_stats?['orders'] ?? 0}', icon: Icons.shopping_bag_outlined, color: Colors.blue),
                        StatCard(title: 'Deliveries', value: '${_stats?['deliveries'] ?? 0}', icon: Icons.delivery_dining, color: Colors.orange),
                        StatCard(title: 'Revenue', value: 'FCFA ${_stats?['revenue'] ?? 0}', icon: Icons.attach_money, color: Colors.green),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('Quick Actions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    ...[
                      ['Manage Users', Icons.manage_accounts, '/admin/users'],
                      ['Verify Licenses', Icons.verified, '/admin/licenses'],
                      ['ONMC / ONPC Registry', Icons.app_registration, '/admin/registry'],
                      ['View Complaints', Icons.report_outlined, '/admin/complaints'],
                      ['All Transactions', Icons.receipt_long, '/admin/transactions'],
                    ].map((item) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFEEEEEE))),
                        leading: Icon(item[1] as IconData, color: AppColors.primary),
                        title: Text(item[0] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textGrey),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _adminScreen(item[2] as String))),
                      ),
                    )),
                  ]),
                ),
        )),
      ])),
    );
  }

  Widget _adminScreen(String route) {
    switch (route) {
      case '/admin/licenses': return const AdminLicensesScreen();
      case '/admin/registry': return const AdminRegistryScreen();
      case '/admin/complaints': return const AdminComplaintsScreen();
      default: return const AdminUsersScreen();
    }
  }
}

// ─── Admin Users ──────────────────────────────────────────────────────────────
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _api = ApiService();
  List _users = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await _api.get('/admin/users');
      setState(() => _users = res.data['data']['users'] ?? []);
    } catch (_) {} finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Users')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final u = _users[i];
                return ListTile(
                  leading: CircleAvatar(backgroundColor: AppColors.lightGreen,
                    child: Text((u['name'] ?? 'U')[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))),
                  title: Text(u['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text('${u['role']} • ${u['email'] ?? u['phone'] ?? ''}', style: const TextStyle(fontSize: 12)),
                  trailing: Switch(
                    value: u['isActive'] ?? false,
                    onChanged: (val) async {
                      await _api.patch('/admin/users/${u['id']}/${val ? 'activate' : 'deactivate'}');
                      _load();
                    },
                    activeColor: AppColors.primary,
                  ),
                );
              },
            ),
    );
  }
}

// ─── Admin Licenses ───────────────────────────────────────────────────────────
class AdminLicensesScreen extends StatefulWidget {
  const AdminLicensesScreen({super.key});
  @override
  State<AdminLicensesScreen> createState() => _AdminLicensesScreenState();
}

class _AdminLicensesScreenState extends State<AdminLicensesScreen> {
  final _api = ApiService();
  Map? _pending;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _api.get('/admin/licenses/pending');
      setState(() => _pending = res.data['data']);
    } catch (_) {} finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _review(String id, String profileType, String status, {String? reason, bool saveToRegistry = true}) async {
    try {
      await _api.patch('/admin/licenses/$id/review', data: {
        'profileType': profileType,
        'status': status,
        'saveToRegistry': saveToRegistry,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'approved' ? 'Professional verified & approved!' : 'Verification rejected.'),
          backgroundColor: status == 'approved' ? AppColors.primary : Colors.red,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('message')
          ? e.toString()
          : 'Failed to update review status';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.length > 100 ? msg.substring(0, 100) : msg), backgroundColor: Colors.red),
      );
    }
  }

  void _viewDocument(String docUrl) {
    final isPdf = docUrl.toLowerCase().endsWith('.pdf');
    final fullUrl = docUrl.startsWith('http')
        ? docUrl
        : '${AppConstants.baseUrl.replaceAll('/api', '')}$docUrl';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(isPdf ? Icons.picture_as_pdf : Icons.image, color: isPdf ? Colors.red : AppColors.primary),
                      const SizedBox(width: 8),
                      Text(isPdf ? 'PDF License Document' : 'License Photo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              Flexible(
                child: isPdf
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.picture_as_pdf, color: Colors.red, size: 56),
                            const SizedBox(height: 12),
                            Text(docUrl.split('/').last, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
                            const SizedBox(height: 6),
                            const Text('Official verification PDF document', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                              child: const Text('PDF Document Attached', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          fullUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (_, child, progress) => progress == null
                              ? child
                              : const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                          errorBuilder: (_, __, ___) => Container(
                            height: 200,
                            alignment: Alignment.center,
                            child: const Text('Could not load image preview', style: TextStyle(color: AppColors.textGrey)),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showApproveConfirmation(String id, String profileType, String name, String? licenseNumber, bool matchFound) {
    final registryName = profileType == 'doctor' ? 'ONMC (Ordre National des Médecins)' : (profileType == 'pharmacist' ? 'ONPC (Ordre National des Pharmaciens)' : 'Registry');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: const [
          Icon(Icons.verified_user, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Confirm Approval', style: TextStyle(fontSize: 16)),
        ]),
        content: Text(
          matchFound
              ? 'Official $registryName match confirmed for license #$licenseNumber ($name).\n\nApproving will grant full platform access and notify the professional immediately.'
              : 'License #$licenseNumber for $name is not yet in the local registry table.\n\nApproving will grant full platform access AND automatically save this practitioner into the official $registryName registry for future auto-matches.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(ctx);
              _review(id, profileType, 'approved', saveToRegistry: true);
            },
            child: const Text('Approve & Activate'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(String id, String profileType, String name) {
    final reasonController = TextEditingController();
    String selectedPreset = profileType == 'doctor'
        ? 'License number not found in ONMC registry'
        : (profileType == 'pharmacist' ? 'License number not found in ONPC registry' : 'Invalid or expired document');
    
    final presets = profileType == 'doctor'
        ? [
            'License number not found in ONMC registry',
            'Name does not match ONMC registration records',
            'Document image is blurry or illegible',
            'Medical license has expired or is invalid',
            'Other (specify below)',
          ]
        : (profileType == 'pharmacist'
            ? [
                'License number not found in ONPC registry',
                'Pharmacy address or name mismatch with ONPC records',
                'Document image is blurry or illegible',
                'Pharmacy license expired',
                'Other (specify below)',
              ]
            : [
                'Driver license or ID expired',
                'Unclear or illegible document scan',
                'Vehicle documents missing or invalid',
                'Other (specify below)',
              ]);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reject Verification', style: TextStyle(fontSize: 16, color: Colors.red)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Provide a reason for rejecting $name\'s submission. This will be sent directly to them so they can rectify their document.',
                    style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                const SizedBox(height: 12),
                const Text('Select Reason:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                ...presets.map((preset) => RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(preset, style: const TextStyle(fontSize: 12)),
                      value: preset,
                      groupValue: selectedPreset,
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedPreset = val;
                          });
                        }
                      },
                    )),
                if (selectedPreset.startsWith('Other')) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Enter specific rejection details...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(10),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                final finalReason = selectedPreset.startsWith('Other')
                    ? (reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : 'Document could not be verified')
                    : selectedPreset;
                Navigator.pop(ctx);
                _review(id, profileType, 'rejected', reason: finalReason);
              },
              child: const Text('Confirm Rejection'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Licenses')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Info banner for Cameroon registries
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Automatic Cross-Check: Submissions are automatically matched in real time against ONMC and ONPC official records. You can approve or add new entries seamlessly.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF1B5E20), height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...[
                  ['Doctors', 'doctor', _pending?['doctors'], 'ONMC Registry'],
                  ['Pharmacists', 'pharmacist', _pending?['pharmacists'], 'ONPC Registry'],
                  ['Drivers', 'driver', _pending?['drivers'], 'Transport Registry'],
                ].map((section) {
                  final list = section[2] as List? ?? [];
                  if (list.isEmpty) return const SizedBox.shrink();
                  final profileType = section[1] as String;
                  final registryTag = section[3] as String;

                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(
                      children: [
                        Text('${section[0]} (${list.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.lightGreen,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(registryTag, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...list.map((p) {
                      final userName = p['user']?['name'] ?? 'Professional';
                      final userContact = p['user']?['email'] ?? p['user']?['phone'] ?? '';
                      final licenseNo = p['licenseNumber'] ?? 'N/A';
                      final docUrl = p['licenseDocUrl'] ?? p['driverLicenseUrl'] ?? '';
                      final match = p['registryMatch'];
                      final isMatchFound = match != null && match['found'] == true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: isMatchFound ? const Color(0xFF81C784) : const Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(userName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text(userContact, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('PENDING REVIEW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.orange)),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          
                          // ─── Automatic Registry Matching Indicator ────────────────
                          if (profileType == 'doctor' || profileType == 'pharmacist') ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: isMatchFound ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isMatchFound ? Colors.green.withOpacity(0.4) : Colors.orange.withOpacity(0.4)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(isMatchFound ? Icons.verified : Icons.info_outline, color: isMatchFound ? Colors.green : Colors.orange, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isMatchFound ? '✓ Auto-Match Found in Official Registry' : '⚠ Not Yet in Local Registry Table',
                                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: isMatchFound ? Colors.green.shade800 : Colors.orange.shade900),
                                        ),
                                        if (isMatchFound) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            profileType == 'doctor'
                                                ? 'Official: ${match['fullName']} (${match['specialty'] ?? 'Doctor'}, ${match['hospital'] ?? 'Practice'})'
                                                : 'Official: ${match['pharmacyName']} — ${match['titularPharmacist']} (${match['address']})',
                                            style: const TextStyle(fontSize: 11, color: Colors.black87),
                                          ),
                                        ] else ...[
                                          const SizedBox(height: 2),
                                          const Text(
                                            'Legitimate new registration? Approving will auto-add them into the registry.',
                                            style: TextStyle(fontSize: 11, color: Colors.black87),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Details row
                          Row(
                            children: [
                              const Icon(Icons.badge_outlined, size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text('License #: ', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                              Text(licenseNo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          if (p['specialty'] != null) ...[
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.medical_services_outlined, size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text('Specialty: ${p['specialty']}', style: const TextStyle(fontSize: 12)),
                            ]),
                          ],
                          if (p['pharmacyName'] != null) ...[
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.local_pharmacy_outlined, size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text('Pharmacy: ${p['pharmacyName']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ]),
                          ],
                          if (docUrl.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _viewDocument(docUrl),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      docUrl.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf : Icons.image,
                                      size: 16,
                                      color: docUrl.toLowerCase().endsWith('.pdf') ? Colors.red : AppColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'View Document: ${docUrl.split('/').last}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(Icons.open_in_new, size: 14, color: AppColors.primary),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.check_circle_outline, size: 16),
                                  label: const Text('Approve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  onPressed: () => _showApproveConfirmation(p['id'], profileType, userName, licenseNo, isMatchFound),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                                  label: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red)),
                                  onPressed: () => _showRejectDialog(p['id'], profileType, userName),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.red),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ),
                          ]),
                        ]),
                      );
                    }),
                    const SizedBox(height: 16),
                  ]);
                }),
              ]),
            ),
    );
  }
}

// ─── Admin Official Registry Management Screen ────────────────────────────────
class AdminRegistryScreen extends StatefulWidget {
  const AdminRegistryScreen({super.key});
  @override
  State<AdminRegistryScreen> createState() => _AdminRegistryScreenState();
}

class _AdminRegistryScreenState extends State<AdminRegistryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _api = ApiService();
  List _doctors = [];
  List _pharmacies = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final [docRes, pharmRes] = await Future.wait([
        _api.get('/admin/registry/onmc?q=$_searchQuery'),
        _api.get('/admin/registry/onpc?q=$_searchQuery'),
      ]);
      setState(() {
        _doctors = docRes.data['data']['records'] ?? [];
        _pharmacies = pharmRes.data['data']['records'] ?? [];
      });
    } catch (_) {} finally {
      setState(() => _loading = false);
    }
  }

  void _showAddDoctorDialog() {
    final licenseCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final specCtrl = TextEditingController();
    final hospCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add ONMC Doctor Record', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: licenseCtrl, decoration: const InputDecoration(labelText: 'ONMC License # (e.g. ONMC/2024/9912)')),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Doctor Full Name (e.g. Dr. Jean Marc)')),
            TextField(controller: specCtrl, decoration: const InputDecoration(labelText: 'Specialty (e.g. Gynecology)')),
            TextField(controller: hospCtrl, decoration: const InputDecoration(labelText: 'Hospital / Practice (Yaoundé)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              if (licenseCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await _api.post('/admin/registry/onmc', data: {
                'licenseNumber': licenseCtrl.text.trim(),
                'fullName': nameCtrl.text.trim(),
                'specialty': specCtrl.text.trim(),
                'hospital': hospCtrl.text.trim(),
              });
              _load();
            },
            child: const Text('Save Record'),
          ),
        ],
      ),
    );
  }

  void _showAddPharmacyDialog() {
    final licenseCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final titCtrl = TextEditingController();
    final addrCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add ONPC Pharmacy Record', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: licenseCtrl, decoration: const InputDecoration(labelText: 'ONPC License # (e.g. ONPC/PHARM/2024/201)')),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Pharmacy Name (e.g. Pharmacie Omnisport)')),
            TextField(controller: titCtrl, decoration: const InputDecoration(labelText: 'Titular Pharmacist (Dr. Pharm. ...)')),
            TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Physical Address (Yaoundé)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              if (licenseCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await _api.post('/admin/registry/onpc', data: {
                'licenseNumber': licenseCtrl.text.trim(),
                'pharmacyName': nameCtrl.text.trim(),
                'titularPharmacist': titCtrl.text.trim(),
                'address': addrCtrl.text.trim(),
              });
              _load();
            },
            child: const Text('Save Record'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Official Registries'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'ONMC Doctors (${_doctors.length})'),
            Tab(text: 'ONPC Pharmacies (${_pharmacies.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: Text(_tabController.index == 0 ? 'Add Doctor' : 'Add Pharmacy'),
        onPressed: () => _tabController.index == 0 ? _showAddDoctorDialog() : _showAddPharmacyDialog(),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name, license #, or specialty...',
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onChanged: (val) {
                _searchQuery = val.trim();
                _load();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Doctors Tab
                      ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _doctors.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final d = _doctors[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.lightGreen,
                              child: const Icon(Icons.medical_services, color: AppColors.primary, size: 20),
                            ),
                            title: Text(d['fullName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            subtitle: Text('${d['licenseNumber']} • ${d['specialty'] ?? 'General'} • ${d['hospital'] ?? ''}', style: const TextStyle(fontSize: 12)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(4)),
                              child: Text(d['status']?.toUpperCase() ?? 'ACTIVE', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
                            ),
                          );
                        },
                      ),

                      // Pharmacies Tab
                      ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _pharmacies.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final p = _pharmacies[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.lightGreen,
                              child: const Icon(Icons.local_pharmacy, color: AppColors.primary, size: 20),
                            ),
                            title: Text(p['pharmacyName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            subtitle: Text('${p['licenseNumber']} • ${p['titularPharmacist'] ?? ''} • ${p['address'] ?? ''}', style: const TextStyle(fontSize: 12)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(4)),
                              child: Text(p['status']?.toUpperCase() ?? 'ACTIVE', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Admin Complaints ─────────────────────────────────────────────────────────
class AdminComplaintsScreen extends StatefulWidget {
  const AdminComplaintsScreen({super.key});
  @override
  State<AdminComplaintsScreen> createState() => _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends State<AdminComplaintsScreen> {
  final _api = ApiService();
  List _complaints = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await _api.get('/admin/complaints');
      setState(() => _complaints = res.data['data'] ?? []);
    } catch (_) {} finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complaints')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _complaints.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final c = _complaints[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFEEEEEE)), borderRadius: BorderRadius.circular(10)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(c['subject'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: c['status'] == 'resolved' ? AppColors.lightGreen : Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(c['status'] ?? '', style: TextStyle(fontSize: 10, color: c['status'] == 'resolved' ? AppColors.primary : Colors.orange, fontWeight: FontWeight.w600))),
                    ]),
                    const SizedBox(height: 4),
                    Text(c['user']?['name'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                    const SizedBox(height: 6),
                    Text(c['body'] ?? '', style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (c['status'] != 'resolved') ...[
                      const SizedBox(height: 10),
                      SizedBox(height: 34, child: ElevatedButton(
                        onPressed: () async { await _api.patch('/admin/complaints/${c['id']}/respond', data: {'status': 'resolved', 'adminResponse': 'Issue resolved.'}); _load(); },
                        style: ElevatedButton.styleFrom(minimumSize: Size.zero, textStyle: const TextStyle(fontSize: 12)),
                        child: const Text('Mark Resolved'))),
                    ],
                  ]),
                );
              },
            ),
    );
  }
}

