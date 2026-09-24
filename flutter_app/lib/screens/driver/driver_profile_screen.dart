import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';
import 'driver_upload_docs_screen.dart';

class DriverProfileScreen extends StatefulWidget {
  final bool isTab;
  const DriverProfileScreen({super.key, this.isTab = false});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/driver/status');
      if (res.data != null && res.data['data'] != null) {
        setState(() {
          _profile = Map<String, dynamic>.from(res.data['data']);
          _isOnline = _profile?['isOnline'] == true;
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleOnline(bool value) async {
    try {
      await _api.patch('/driver/status', data: {'isOnline': value});
      setState(() => _isOnline = value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? '🟢 You are now Online & eligible for deliveries' : '⚪ You are now Offline'),
          backgroundColor: value ? AppColors.primary : Colors.grey[700],
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    final name = user?['name'] ?? _profile?['user']?['name'] ?? 'Delivery Driver';
    final phone = user?['phone'] ?? _profile?['user']?['phone'] ?? '+237 600 000 000';
    final email = user?['email'] ?? _profile?['user']?['email'] ?? 'driver@pharmalink.cm';
    final vehicle = _profile?['vehicleInfo'] ?? 'Motorbike (Yamaha YBR 125)';
    final approvalStatus = _profile?['approvalStatus'] ?? 'approved';
    final isApproved = approvalStatus == 'approved';

    final body = _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Profile Header Card ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundColor: AppColors.lightGreen,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'D',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: _isOnline ? const Color(0xFF22C55E) : Colors.grey,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textDark),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              phone,
                              style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email,
                              style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isApproved ? const Color(0xFFF0FDF4) : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isApproved ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                                ),
                              ),
                              child: Text(
                                isApproved ? '✓ VERIFIED DRIVER' : '⏳ PENDING REVIEW',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isApproved ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ─── Online / Offline Availability Switch ──────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isOnline ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isOnline ? AppColors.primary : const Color(0xFFE2E8F0),
                      width: _isOnline ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _isOnline ? AppColors.lightGreen : Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isOnline ? Icons.power_settings_new : Icons.power_off,
                          color: _isOnline ? AppColors.primary : Colors.grey[600],
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isOnline ? 'Online • Visible to Dispatch' : 'Offline • Hidden from Queue',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: _isOnline ? AppColors.primary : AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isOnline
                                  ? 'You are active and receiving delivery requests'
                                  : 'Switch online when you are ready to work',
                              style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isOnline,
                        onChanged: _toggleOnline,
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ─── Vehicle & License Details ────────────────────────────────
                const Text('Vehicle Information', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _infoRow(Icons.two_wheeler, 'Vehicle Info', vehicle),
                      const Divider(height: 18),
                      _infoRow(Icons.speed, 'Commission Rate', '10% of total order value'),
                      const Divider(height: 18),
                      _infoRow(Icons.pin_drop_outlined, 'Base Zone', 'Yaoundé & Surrounding Quarters'),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ─── Document Verification Shortcut ───────────────────────────
                const Text('Verification Documents', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DriverUploadDocsScreen()),
                    );
                    _loadProfile();
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.badge_outlined, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Driver License & National ID', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              SizedBox(height: 2),
                              Text('Tap to update or re-upload documents', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ─── Logout Button ────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () => context.read<AuthService>().logout(),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );

    if (widget.isTab) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('Driver Profile')),
      body: body,
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark)),
      ],
    );
  }
}
