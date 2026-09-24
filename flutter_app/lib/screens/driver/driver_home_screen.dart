import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/logout_button.dart';
import 'delivery_list_screen.dart';
import 'earnings_screen.dart';
import 'driver_profile_screen.dart';
import 'driver_upload_docs_screen.dart';
import 'route_map_screen.dart';
import '../shared/notifications_screen.dart';
import '../../services/socket_service.dart';
import '../shared/conversations_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});
  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> with WidgetsBindingObserver {
  int _navIndex = 0;
  final _api = ApiService();
  final _socket = SocketService();
  bool _isOnline = false;
  List<Map<String, dynamic>> _deliveries = [];
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDashboard();
    _socket.onDeliveryNew(_onSocketDelivery);
    _socket.onOrderUpdated(_onSocketDelivery);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthService>().refreshUser();
    });

    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) context.read<AuthService>().refreshUser();
    });
  }

  void _onSocketDelivery(dynamic data) {
    if (mounted) {
      _loadDashboard();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _socket.removeListener('delivery:new', _onSocketDelivery);
    _socket.removeListener('order:updated', _onSocketDelivery);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AuthService>().refreshUser();
    }
  }

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);
    try {
      final [statusRes, deliveriesRes] = await Future.wait([
        _api.get('/driver/status'),
        _api.get('/driver/deliveries'),
      ]);

      if (statusRes.data != null && statusRes.data['data'] != null) {
        _isOnline = statusRes.data['data']['isOnline'] == true;
      }

      final list = (deliveriesRes.data['data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      setState(() {
        _deliveries = list;
      });
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
          content: Text(
            value
                ? '🟢 You are now Online and visible in the dispatch queue!'
                : '⚪ You are now Offline and hidden from the dispatch queue.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: value ? AppColors.primary : const Color(0xFF334155),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {}
  }

  int get _completedCount => _deliveries.where((d) => d['status'] == 'delivered').length;
  int get _pendingCount => _deliveries.where((d) => ['assigned', 'picked_up', 'in_transit'].contains(d['status'])).length;
  Map<String, dynamic>? get _activeDelivery {
    final active = _deliveries.where((d) => ['picked_up', 'in_transit', 'assigned'].contains(d['status'])).toList();
    return active.isNotEmpty ? active.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    final name = user?['name']?.toString().split(' ').first ?? 'Driver';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Top Gradient Driver Bar ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x200D6E48),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(50),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withAlpha(80), width: 1.5),
                    ),
                    child: const Center(
                      child: Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Express Courier • $name',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _isOnline ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isOnline ? 'Online • Ready for Dispatch' : 'Offline • Tap switch to activate',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _isOnline ? const Color(0xFFD1FAE5) : const Color(0xFFCBD5E1),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ConversationsScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withAlpha(60)),
                      ),
                      child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withAlpha(60)),
                      ),
                      child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const HeaderLogoutButton(),
                ],
              ),
            ),

            // ─── Main View Content based on Tab ───────────────────────────────
            Expanded(
              child: _buildCurrentTab(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: PharmaBottomNav(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard_rounded),
            label: 'Hub',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.two_wheeler_outlined),
            activeIcon: Icon(Icons.two_wheeler_rounded),
            label: 'Deliveries',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Earnings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_navIndex) {
      case 1:
        return const DeliveryListScreen(isTab: true);
      case 2:
        return const EarningsScreen(isTab: true);
      case 3:
        return const DriverProfileScreen(isTab: true);
      case 0:
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final active = _activeDelivery;

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Express Courier Promo Banner ──────────────────────────────
            PromoImageBanner(
              imageAssetPath: 'assets/images/express_delivery_driver.jpg',
              title: 'PharmaLink Express Courier',
              subtitle: 'Rapid temperature-controlled medical delivery across Yaoundé & Douala',
              badge: 'Fast Dispatch',
              buttonLabel: _isOnline ? 'Active Dispatch' : 'Go Online',
              onButtonPressed: () => _toggleOnline(!_isOnline),
            ),
            const SizedBox(height: 20),

            // ─── Online / Offline Interactive Status Card ───────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isOnline ? const Color(0xFFF0FDF4) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _isOnline ? AppColors.primary : const Color(0xFFE2E8F0),
                  width: _isOnline ? 2 : 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 12,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _isOnline ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _isOnline ? Icons.radar_rounded : Icons.power_settings_new_rounded,
                      color: _isOnline ? AppColors.primary : const Color(0xFF64748B),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isOnline ? 'Online • Ready for Dispatch' : 'Offline • Queue Paused',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: _isOnline ? AppColors.primary : AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _isOnline
                              ? 'Your GPS location is live. New pharmacy delivery requests will appear instantly.'
                              : 'Toggle on switch to begin receiving urgent medical pickup requests.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textGrey,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Transform.scale(
                    scale: 0.95,
                    child: Switch(
                      value: _isOnline,
                      onChanged: _toggleOnline,
                      activeColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // ─── Session Metrics ──────────────────────────────────────────
            const SectionHeader(title: 'Courier Performance', subtitle: 'Today\'s activity & fulfillment stats'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Fulfilled',
                    value: '$_completedCount',
                    icon: Icons.check_circle_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'Active Trips',
                    value: '$_pendingCount',
                    icon: Icons.two_wheeler_rounded,
                    color: const Color(0xFFD97706),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // ─── Active Delivery Card (If Any) ────────────────────────────
            if (active != null) ...[
              const SectionHeader(
                title: 'Active Delivery in Progress 🚴',
                subtitle: 'Urgent order in route to patient',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.primary.withAlpha(120), width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x120D6E48),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD1FAE5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.inventory_2_rounded, size: 16, color: AppColors.primary),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Order #${(active['order']?['id'] ?? active['orderId'] ?? '').toString().substring(0, 8).toUpperCase()}',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            (active['status'] ?? 'ONGOING').toString().replaceAll('_', ' ').toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 22, color: Color(0xFFF1F5F9)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.storefront_rounded, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pharmacy: ${active['order']?['pharmacy']?['pharmacyName'] ?? 'Pharmacy Partner'}',
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_rounded, size: 18, color: Color(0xFFEF4444)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Dropoff: ${active['order']?['deliveryAddress'] ?? 'Customer Address'}',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textGrey),
                          ),
                        ),
                      ],
                    ),
                    if (active['order']?['otp'] != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_clock_rounded, size: 16, color: Color(0xFFD97706)),
                            const SizedBox(width: 8),
                            Text(
                              'Recipient Verification OTP: ${active['order']['otp']}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF78350F),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    PharmaButton(
                      label: 'Launch Live Navigation Map',
                      icon: Icons.navigation_rounded,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RouteMapScreen(
                            deliveryId: active['id'],
                            orderId: active['order']?['id'] ?? active['orderId'],
                            pharmacyName: active['order']?['pharmacy']?['pharmacyName'],
                            customerName: active['order']?['patient']?['name'],
                            pickupLat: active['order']?['pharmacy']?['lat'],
                            pickupLng: active['order']?['pharmacy']?['lng'],
                            dropoffLat: active['order']?['deliveryLat'],
                            dropoffLng: active['order']?['deliveryLng'],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
            ],

            // ─── Quick Shortcuts ──────────────────────────────────────────
            const SectionHeader(title: 'Courier Tools', subtitle: 'Fast shortcuts for delivery management'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _quickActionCard(
                    icon: Icons.moped_rounded,
                    title: 'All Deliveries',
                    sub: '$_pendingCount assigned',
                    onTap: () => setState(() => _navIndex = 1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _quickActionCard(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'My Earnings',
                    sub: '10% delivery fee',
                    onTap: () => setState(() => _navIndex = 2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _quickActionCard(
              icon: Icons.verified_user_rounded,
              title: 'Upload Driver Credentials',
              sub: 'Driver License & National ID for Cameroon transport verification',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DriverUploadDocsScreen()),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String title,
    required String sub,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.textGrey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

