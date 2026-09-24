import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/logout_button.dart';
import '../shared/notifications_screen.dart';
import '../shared/conversations_screen.dart';
import 'inventory_screen.dart';
import 'manage_orders_screen.dart';
import 'sales_analytics_screen.dart';
import '../../services/socket_service.dart';
import 'pharmacist_upload_license_screen.dart';

class PharmacistHomeScreen extends StatefulWidget {
  const PharmacistHomeScreen({super.key});
  @override
  State<PharmacistHomeScreen> createState() => _PharmacistHomeScreenState();
}

class _PharmacistHomeScreenState extends State<PharmacistHomeScreen> with WidgetsBindingObserver {
  int _navIndex = 0;
  final _api = ApiService();
  final _socket = SocketService();
  List _recentOrders = [];
  Map? _analytics;
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _socket.onOrderNew(_onOrderEvent);
    _socket.onOrderUpdated(_onOrderEvent);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthService>().refreshUser();
    });

    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) context.read<AuthService>().refreshUser();
    });
  }

  void _onOrderEvent(dynamic data) {
    if (mounted) {
      _load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _socket.removeListener('order:new', _onOrderEvent);
    _socket.removeListener('order:updated', _onOrderEvent);
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
      final [ordersRes, analyticsRes] = await Future.wait([
        _api.get('/pharmacist/orders'),
        _api.get('/pharmacist/analytics'),
      ]);
      if (mounted) {
        setState(() {
          _recentOrders = (ordersRes.data['data'] as List? ?? []).take(5).toList();
          _analytics = analyticsRes.data['data'];
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_navIndex == 1) {
      return Scaffold(
        body: const InventoryScreen(),
        bottomNavigationBar: _buildBottomNav(),
      );
    }
    if (_navIndex == 2) {
      return Scaffold(
        body: const ManageOrdersScreen(),
        bottomNavigationBar: _buildBottomNav(),
      );
    }
    if (_navIndex == 3) {
      return Scaffold(
        body: const SalesAnalyticsScreen(),
        bottomNavigationBar: _buildBottomNav(),
      );
    }
    if (_navIndex == 4) {
      return Scaffold(
        body: const ProfileScreen(),
        bottomNavigationBar: _buildBottomNav(),
      );
    }

    final user = context.watch<AuthService>().user;
    final pharmProfile = user?['pharmacistProfile'];
    final pharmacyName = pharmProfile?['pharmacyName'] ?? 'My Pharmacy';
    final approvalStatus = pharmProfile?['approvalStatus'] ?? 'pending';
    final isApproved = approvalStatus == 'approved';
    final isRejected = approvalStatus == 'rejected';
    final licenseNo = pharmProfile?['licenseNumber'] ?? '';
    final rejectionReason = pharmProfile?['rejectionReason'];

    return Scaffold(
      backgroundColor: const Color(0xFF0A583A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A583A), Color(0xFF064E3B), Color(0xFF0F766E)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                      ),
                      child: CircleAvatar(
                        backgroundColor: const Color(0xFF10B981),
                        radius: 20,
                        child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pharmacyName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Officine Pharmacist Portal',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white.withOpacity(0.85)),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isApproved
                                  ? const Color(0xFF10B981).withOpacity(0.3)
                                  : (isRejected ? Colors.redAccent.withOpacity(0.3) : Colors.amberAccent.withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isApproved ? '✓ ONPC VERIFIED' : (isRejected ? '✕ VERIFICATION REJECTED' : '⏳ ONPC PENDING REVIEW'),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConversationsScreen())),
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const HeaderLogoutButton(),
                  ],
                ),
              ),

              // White Content Sheet
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x1F000000),
                        blurRadius: 20,
                        offset: Offset(0, -6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Verification Alert Banner if not approved
                          if (!isApproved)
                            Container(
                              margin: const EdgeInsets.only(bottom: 18),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isRejected ? Colors.red.withOpacity(0.08) : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isRejected ? Colors.red.withOpacity(0.3) : Colors.orange.withOpacity(0.3)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(isRejected ? Icons.error_outline : Icons.hourglass_empty, color: isRejected ? Colors.red : Colors.orange, size: 22),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isRejected ? 'ONPC Pharmacy License Rejected' : 'Pharmacy License Verification In Progress',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: isRejected ? Colors.red : Colors.orange,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isRejected
                                              ? 'Reason: ${rejectionReason ?? 'Document mismatch'}. Tap below to update your license.'
                                              : 'Your pharmacy license #$licenseNo is under review by PharmaLink admin against ONPC records.',
                                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.black87),
                                        ),
                                        const SizedBox(height: 10),
                                        SizedBox(
                                          height: 34,
                                          child: ElevatedButton.icon(
                                            icon: const Icon(Icons.upload_file_rounded, size: 16),
                                            label: Text(
                                              isRejected ? 'Re-upload ONPC License' : 'View / Update License',
                                              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700),
                                            ),
                                            onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => PharmacistUploadLicenseScreen(
                                                  initialLicenseNumber: licenseNo,
                                                  initialPharmacyName: pharmacyName,
                                                  rejectionReason: rejectionReason,
                                                  approvalStatus: approvalStatus,
                                                ),
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isRejected ? Colors.red : AppColors.primary,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Pharmacy Store Showcase Banner
                          PromoImageBanner(
                            imagePath: 'assets/images/pharmacy_store_banner.jpg',
                            tag: 'Pharmacy Operations',
                            title: 'Digital Order Dispensation & Live Inventory',
                            subtitle: 'Fulfill verified e-prescriptions and assign delivery drivers in Yaoundé.',
                            ctaText: 'Manage Orders',
                            onCtaPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ManageOrdersScreen()),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Stats row
                          if (_analytics != null) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: StatCard(
                                    title: 'Total Revenue',
                                    value: '${_analytics!['totalSales']?.toString() ?? '0'} F',
                                    icon: Icons.payments_rounded,
                                    color: const Color(0xFF0D6E48),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: StatCard(
                                    title: 'Completed Orders',
                                    value: '${_analytics!['orderCount'] ?? 0}',
                                    icon: Icons.shopping_bag_rounded,
                                    color: const Color(0xFF0284C7),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],

                          const SectionHeader(title: 'Management Hub'),
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 1.45,
                            children: [
                              _card(
                                Icons.inventory_2_rounded,
                                'Med Inventory',
                                'Stock & Pricing',
                                const Color(0xFF0D6E48),
                                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen())),
                              ),
                              _card(
                                Icons.local_shipping_rounded,
                                'Orders & Drivers',
                                'Fulfill & Dispatch',
                                const Color(0xFF0284C7),
                                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageOrdersScreen())),
                              ),
                              _card(
                                Icons.bar_chart_rounded,
                                'Sales Analytics',
                                'Financial revenue',
                                const Color(0xFF7C3AED),
                                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesAnalyticsScreen())),
                              ),
                              _card(
                                Icons.verified_user_rounded,
                                'ONPC License',
                                isApproved ? 'Verified officine' : 'Update license',
                                const Color(0xFFF59E0B),
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PharmacistUploadLicenseScreen(
                                      initialLicenseNumber: licenseNo,
                                      initialPharmacyName: pharmacyName,
                                      rejectionReason: rejectionReason,
                                      approvalStatus: approvalStatus,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          const SectionHeader(title: 'Recent Incoming Orders'),
                          const SizedBox(height: 12),
                          if (_loading)
                            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.primary)))
                          else if (_recentOrders.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Center(
                                child: Text(
                                  'No incoming orders at the moment',
                                  style: GoogleFonts.plusJakartaSans(color: AppColors.textGrey, fontSize: 13),
                                ),
                              ),
                            )
                          else
                            ..._recentOrders.map((o) => _orderTile(o)),
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
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return PharmaBottomNav(
      currentIndex: _navIndex,
      onTap: (i) => setState(() => _navIndex = i),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), activeIcon: Icon(Icons.inventory_2_rounded), label: 'Inventory'),
        BottomNavigationBarItem(icon: Icon(Icons.shopping_bag_outlined), activeIcon: Icon(Icons.shopping_bag_rounded), label: 'Orders'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart_rounded), label: 'Analytics'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), activeIcon: Icon(Icons.person_rounded), label: 'Profile'),
      ],
    );
  }

  Widget _card(IconData icon, String title, String sub, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.textGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _orderTile(Map o) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFEEEEEE)), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('#${o['id'].toString().substring(0,8).toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text(o['patient']?['name'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
        ])),
        Text('FCFA ${o['totalFcfa']}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(6)),
          child: Text(o['status'] ?? '', style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}
