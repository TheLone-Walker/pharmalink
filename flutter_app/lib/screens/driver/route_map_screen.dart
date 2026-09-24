import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';
import 'delivery_photo_screen.dart';

class RouteMapScreen extends StatefulWidget {
  final String deliveryId;
  final String orderId;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;
  final String? customerName;
  final String? pharmacyName;

  const RouteMapScreen({
    super.key,
    required this.deliveryId,
    required this.orderId,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
    this.customerName,
    this.pharmacyName,
  });

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  final _api = ApiService();
  final _socket = SocketService();
  GoogleMapController? _mapCtrl;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _pickedUp = false;
  bool _loading = false;
  String? _otp = '4821';
  LatLng _currentPos = const LatLng(3.848, 11.502);

  @override
  void initState() {
    super.initState();
    _setupMap();
    _loadDeliveryDetails();
    _socket.joinOrder(widget.orderId);
  }

  @override
  void dispose() {
    _mapCtrl?.dispose();
    super.dispose();
  }

  Future<void> _loadDeliveryDetails() async {
    try {
      final res = await _api.get('/driver/deliveries');
      final list = (res.data['data'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
      final match = list.firstWhere((d) => d['id'] == widget.deliveryId || d['orderId'] == widget.orderId, orElse: () => {});
      if (match.isNotEmpty) {
        setState(() {
          _pickedUp = ['picked_up', 'in_transit', 'delivered'].contains(match['status']);
          if (match['order']?['otp'] != null) {
            _otp = match['order']['otp'].toString();
          }
        });
      }
    } catch (_) {}
  }

  void _setupMap() {
    final pickup = widget.pickupLat != null
        ? LatLng(widget.pickupLat!, widget.pickupLng!)
        : const LatLng(3.880, 11.516);
    final dropoff = widget.dropoffLat != null
        ? LatLng(widget.dropoffLat!, widget.dropoffLng!)
        : const LatLng(3.848, 11.502);

    setState(() {
      _markers.addAll([
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: widget.pharmacyName ?? 'Pharmacy', snippet: 'Pickup Point'),
        ),
        Marker(
          markerId: const MarkerId('dropoff'),
          position: dropoff,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: widget.customerName ?? 'Customer', snippet: 'Dropoff Point'),
        ),
      ]);
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: [pickup, _currentPos, dropoff],
          color: AppColors.primary,
          width: 4,
        ),
      );
    });
  }

  Future<void> _confirmPickup() async {
    setState(() => _loading = true);
    try {
      final res = await _api.patch('/driver/deliveries/${widget.deliveryId}/pickup');
      final orderData = res.data['data']?['order'] ?? {};
      if (orderData['otp'] != null) {
        _otp = orderData['otp'].toString();
      }

      setState(() => _pickedUp = true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Pickup confirmed! Head to customer. Verification OTP: $_otp'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to confirm pickup.'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmDelivery() async {
    setState(() => _loading = true);
    try {
      await _api.patch('/driver/deliveries/${widget.deliveryId}/deliver');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Delivery completed and logged!'), backgroundColor: AppColors.primary),
      );
      Navigator.pop(context, true);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to confirm delivery.'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _updateLocation(LatLng pos) {
    _socket.sendLocation(widget.orderId, pos.latitude, pos.longitude);
    _api.put('/driver/location', data: {
      'lat': pos.latitude,
      'lng': pos.longitude,
      'orderId': widget.orderId,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Route Navigation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: 'Take Delivery Photo',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DeliveryPhotoScreen(orderId: widget.orderId, deliveryId: widget.deliveryId),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── 2-Step Progress Indicator ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            color: AppColors.primary,
            child: Row(
              children: [
                _stepItem(1, 'Pickup at Pharmacy', !_pickedUp),
                Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: _pickedUp ? Colors.white : Colors.white30,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                _stepItem(2, 'Deliver to Customer', _pickedUp),
              ],
            ),
          ),

          // ─── Map View ────────────────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _currentPos, zoom: 13.5),
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (c) => _mapCtrl = c,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onCameraMove: (pos) => _updateLocation(pos.target),
            ),
          ),

          // ─── Bottom Status & OTP Panel ───────────────────────────────────────
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Destination Info
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.lightGreen,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _pickedUp ? Icons.person_pin_circle : Icons.local_pharmacy,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _pickedUp ? (widget.customerName ?? 'Customer') : (widget.pharmacyName ?? 'Pharmacy'),
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              Text(
                                _pickedUp ? 'Deliver & verify OTP' : 'Collect medication package',
                                style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: const [
                            Text('ETA', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                            Text('8 min', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 14)),
                            Text('1.8 km', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ─── 4-Digit Customer OTP Box ───────────────────────────────
                  if (_pickedUp && _otp != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.vpn_key, color: Color(0xFFD97706), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '4-DIGIT CUSTOMER VERIFICATION OTP',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                                ),
                                Text(
                                  _otp!,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF78350F),
                                    letterSpacing: 4,
                                  ),
                                ),
                                const Text(
                                  'Show this code to customer upon arrival to verify receipt & sign.',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF92400E)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 18, color: Color(0xFFD97706)),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _otp!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('OTP copied to clipboard'), duration: Duration(seconds: 1)),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // ─── Action Buttons ──────────────────────────────────────────
                  if (!_pickedUp)
                    PharmaButton(
                      label: 'Confirm Pickup at ${widget.pharmacyName ?? 'Pharmacy'}',
                      onPressed: _confirmPickup,
                      isLoading: _loading,
                      icon: Icons.check_circle_outline,
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                              side: const BorderSide(color: Color(0xFF2563EB)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.camera_alt, size: 18),
                            label: const Text('Proof Photo', style: TextStyle(fontWeight: FontWeight.w700)),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DeliveryPhotoScreen(orderId: widget.orderId, deliveryId: widget.deliveryId),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.done_all, size: 18),
                            label: const Text('Confirm Delivery', style: TextStyle(fontWeight: FontWeight.w700)),
                            onPressed: _confirmDelivery,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepItem(int num, String label, bool active) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white24,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$num',
              style: TextStyle(
                color: active ? AppColors.primary : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white70,
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
