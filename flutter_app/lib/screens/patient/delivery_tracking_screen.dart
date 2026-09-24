import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';
import 'otp_confirm_screen.dart';

class DeliveryTrackingScreen extends StatefulWidget {
  final String orderId;
  const DeliveryTrackingScreen({super.key, required this.orderId});
  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen> {
  final _api = ApiService();
  final _socket = SocketService();
  GoogleMapController? _mapCtrl;
  Map? _delivery;
  bool _loading = true;
  LatLng _driverPos = const LatLng(3.848, 11.502);
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _load();
    _socket.joinOrder(widget.orderId);
    _socket.onDriverLocation((data) {
      setState(() {
        _driverPos = LatLng(data['lat'], data['lng']);
        _markers.removeWhere((m) => m.markerId.value == 'driver');
        _markers.add(Marker(markerId: const MarkerId('driver'), position: _driverPos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Driver')));
      });
      _mapCtrl?.animateCamera(CameraUpdate.newLatLng(_driverPos));
    });
  }

  @override
  void dispose() { _mapCtrl?.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final res = await _api.get('/deliveries/${widget.orderId}');
      final d = res.data['data'];
      setState(() {
        _delivery = d;
        if (d['currentLat'] != null && d['currentLng'] != null) {
          _driverPos = LatLng(d['currentLat'], d['currentLng']);
        }
        _markers.add(Marker(markerId: const MarkerId('driver'), position: _driverPos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Driver')));
        if (d['order']?['deliveryLat'] != null) {
          _markers.add(Marker(
            markerId: const MarkerId('destination'),
            position: LatLng(d['order']['deliveryLat'], d['order']['deliveryLng']),
            infoWindow: const InfoWindow(title: 'Delivery Location'),
          ));
        }
      });
    } catch (_) {} finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final driver = _delivery?['driver']?['user'];
    return Scaffold(
      appBar: AppBar(title: const Text('Track Delivery')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(children: [
              Expanded(
                flex: 3,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(target: _driverPos, zoom: 14),
                  markers: _markers,
                  onMapCreated: (c) => _mapCtrl = c,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                ),
              ),
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        const Icon(Icons.delivery_dining, color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        const Text('Driver is on the way', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
                        const Spacer(),
                        const Text('ETA: 12 min', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    if (driver != null) ...[
                      const SizedBox(height: 16),
                      const Text('Driver Details', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 10),
                      Row(children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.lightGreen,
                          child: Text((driver['name'] ?? 'D')[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 18)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(driver['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Row(children: [
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const Text(' 4.7 (56 trips)', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                          ]),
                          Text(_delivery?['driver']?['vehicleInfo'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                        ])),
                        Row(children: [
                          CircleAvatar(
                            radius: 18, backgroundColor: AppColors.lightGreen,
                            child: const Icon(Icons.phone_outlined, color: AppColors.primary, size: 18),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 18, backgroundColor: AppColors.lightGreen,
                            child: const Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 18),
                          ),
                        ]),
                      ]),
                    ],
                    const SizedBox(height: 16),
                    PharmaButton(
                      label: 'Enter OTP to Confirm',
                      onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => OtpConfirmScreen(orderId: widget.orderId))),
                      icon: Icons.lock_outline,
                    ),
                  ]),
                ),
              ),
            ]),
    );
  }
}
