import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/api_service.dart';
import '../../services/route_directions_service.dart';
import '../../services/socket_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';
import 'digital_receipt_screen.dart';

class DeliveryTrackingScreen extends StatefulWidget {
  final String orderId;
  const DeliveryTrackingScreen({super.key, required this.orderId});
  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen> {
  final _api = ApiService();
  final _socket = SocketService();
  final _directionsService = RouteDirectionsService();
  GoogleMapController? _mapCtrl;
  Map? _delivery;
  bool _loading = true;
  LatLng _driverPos = const LatLng(3.848, 11.502);
  LatLng? _destinationPos;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _fetchingRoute = false;

  @override
  void initState() {
    super.initState();
    _load();
    _socket.joinOrder(widget.orderId);
    _socket.onDriverLocation((data) {
      if (!mounted) return;
      setState(() {
        _driverPos = LatLng(data['lat'], data['lng']);
        _markers.removeWhere((m) => m.markerId.value == 'driver');
        _markers.add(Marker(
          markerId: const MarkerId('driver'),
          position: _driverPos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Courier Driver'),
        ));
      });
      _updateRoadRoute();
      _mapCtrl?.animateCamera(CameraUpdate.newLatLng(_driverPos));
    });

    // Auto-redirect to receipt once courier scans QR and signature is submitted
    _socket.onStatusChange((data) {
      if (data['status'] == 'delivered' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Delivery received and signature validated!'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DigitalReceiptScreen(orderId: widget.orderId)),
        );
      }
    });
  }

  @override
  void dispose() {
    _mapCtrl?.dispose();
    super.dispose();
  }

  Future<void> _switchToPickup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.storefront_rounded, color: Color(0xFF16A34A), size: 24),
            SizedBox(width: 10),
            Expanded(child: Text('Switch to Counter Pickup?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          ],
        ),
        content: const Text(
          'Need your medication immediately without waiting for courier arrival?\n\n'
          'Switching will instantly issue your Pharmacy Counter Pickup Pass & QR Code. You or anyone with your QR pass can immediately collect the medication at the pharmacy counter.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Tracking Delivery'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.qr_code_rounded, size: 16),
            label: const Text('Get Pickup Pass Now', style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _api.patch('/orders/${widget.orderId}/switch-to-pickup');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🏪 Switched to In-Person Pickup! Counter pass activated.'),
              backgroundColor: Color(0xFF16A34A),
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DigitalReceiptScreen(orderId: widget.orderId),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not switch to pickup: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _load() async {
    try {
      final res = await _api.get('/deliveries/${widget.orderId}');
      final d = res.data['data'];
      if (!mounted) return;
      setState(() {
        _delivery = d;
        if (d['currentLat'] != null && d['currentLng'] != null) {
          _driverPos = LatLng(d['currentLat'], d['currentLng']);
        }
        _markers.add(Marker(
          markerId: const MarkerId('driver'),
          position: _driverPos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Driver'),
        ));
        if (d['order']?['deliveryLat'] != null) {
          _destinationPos = LatLng(d['order']['deliveryLat'], d['order']['deliveryLng']);
          _markers.add(Marker(
            markerId: const MarkerId('destination'),
            position: _destinationPos!,
            infoWindow: const InfoWindow(title: 'Delivery Location'),
          ));
        }
      });
      _updateRoadRoute();
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Calculates and renders road path that hugs road curves and turns
  Future<void> _updateRoadRoute() async {
    if (_destinationPos == null || _fetchingRoute) return;
    _fetchingRoute = true;
    try {
      final roadPoints = await _directionsService.getRoadPath(
        origin: _driverPos,
        destination: _destinationPos!,
      );
      if (!mounted) return;
      setState(() {
        _polylines.removeWhere((p) => p.polylineId.value == 'delivery_route');
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('delivery_route'),
            points: roadPoints,
            color: AppColors.primary,
            width: 5,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
      });
    } catch (_) {
    } finally {
      _fetchingRoute = false;
    }
  }

  void _showQrFullscreen(String qrData, String orderShortId, {String? otp}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: AppColors.lightGreen, shape: BoxShape.circle),
                child: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                'Delivery Verification Pass',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              Text(
                'Order #$orderShortId',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textGrey, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF0D6E48),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (otp != null && otp.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_rounded, size: 14, color: Color(0xFFB45309)),
                          const SizedBox(width: 6),
                          Text(
                            'CONFIDENTIAL HANDOVER OTP',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF92400E),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        otp,
                        style: GoogleFonts.spaceMono(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                          color: const Color(0xFF78350F),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Give or recite this code ONLY when the driver hands you your package.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF92400E),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The driver cannot complete delivery without this OTP or QR scan. Keep it private until handover!',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFF166534), height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Close',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppColors.textGrey),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final driver = _delivery?['driver']?['user'];
    final order = _delivery?['order'];
    final orderShortId = (widget.orderId.length >= 8) ? widget.orderId.substring(0, 8).toUpperCase() : widget.orderId.toUpperCase();
    final otp = order?['otp']?.toString() ?? '';
    final qrData = 'PHARMALINK_DELIVERY:${widget.orderId}:${order?['patientId'] ?? ''}:${otp}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Track Live Delivery', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded),
            tooltip: 'View QR Code',
            onPressed: () => _showQrFullscreen(qrData, orderShortId, otp: otp),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(children: [
              Expanded(
                flex: 3,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(target: _driverPos, zoom: 14),
                  markers: _markers,
                  polylines: _polylines,
                  onMapCreated: (c) => _mapCtrl = c,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                ),
              ),
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Status banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.lightGreen,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.delivery_dining, color: AppColors.primary, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Courier is en route to you',
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 13),
                              ),
                              Text(
                                'Order #$orderShortId • Real-time GPS',
                                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textGrey),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                          child: const Text('ETA ~12 min', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
                        ),
                      ]),
                    ),

                    if (driver != null) ...[
                      const SizedBox(height: 14),
                      Row(children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.lightGreen,
                          child: Text((driver['name'] ?? 'D')[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(driver['name'] ?? 'Delivery Courier', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          Text(_delivery?['driver']?['vehicleInfo'] ?? 'Motorbike Delivery', style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                        ])),
                        CircleAvatar(
                          radius: 17, backgroundColor: AppColors.lightGreen,
                          child: const Icon(Icons.phone_outlined, color: AppColors.primary, size: 16),
                        ),
                      ]),
                    ],

                    const SizedBox(height: 16),

                    // ─── PROMINENT DELIVERY CONFIRMATION QR & OTP CARD ───────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withOpacity(0.35), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => _showQrFullscreen(qrData, orderShortId, otp: otp),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: QrImageView(
                                    data: qrData,
                                    version: QrVersions.auto,
                                    size: 84.0,
                                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0D6E48)),
                                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF0F172A)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.qr_code_scanner_rounded, size: 16, color: AppColors.primary),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Patient Delivery Pass',
                                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textDark),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Present this QR code or secret OTP to courier upon package arrival to confirm handover.',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textGrey, height: 1.3),
                                    ),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () => _showQrFullscreen(qrData, orderShortId, otp: otp),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Tap to Enlarge QR',
                                            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.fullscreen_rounded, size: 16, color: AppColors.primary),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (otp.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFDE68A),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.lock_rounded, size: 20, color: Color(0xFF92400E)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'SECRET HANDOVER OTP',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF92400E),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        Text(
                                          otp,
                                          style: GoogleFonts.spaceMono(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 4,
                                            color: const Color(0xFF78350F),
                                          ),
                                        ),
                                        Text(
                                          'Only give this code to the courier after package is handed to you.',
                                          style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF92400E)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ─── EMERGENCY / IN-A-HURRY SWITCH TO COUNTER PICKUP ───────────────
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _switchToPickup,
                        icon: const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF16A34A)),
                        label: const Text(
                          '🏪 In a hurry / No courier? Switch to Instant Counter Pickup Pass',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF86EFAC), width: 1.2),
                          backgroundColor: const Color(0xFFF0FDF4),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
    );
  }
}
