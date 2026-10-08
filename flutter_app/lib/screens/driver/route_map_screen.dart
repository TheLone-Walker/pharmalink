import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:signature/signature.dart';
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
  double _orderTotal = 0.0;
  String? _patientId;
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
          if (match['order'] != null) {
            _orderTotal = double.tryParse(match['order']['totalFcfa'].toString()) ?? 0.0;
            _patientId = match['order']['patientId']?.toString();
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
      await _api.patch('/driver/deliveries/${widget.deliveryId}/pickup');
      setState(() => _pickedUp = true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Pickup confirmed! Head to customer with medication package.'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 4),
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

  /// Trigger QR Code Scan & Patient Signature Flow
  void _startQrScanAndSignatureFlow() {
    final codeCtrl = TextEditingController();
    final expectedQrPayload = 'PHARMALINK_DELIVERY:${widget.orderId}';
    final shortOrderId = widget.orderId.length >= 8 ? widget.orderId.substring(0, 8).toUpperCase() : widget.orderId.toUpperCase();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: AppColors.lightGreen, shape: BoxShape.circle),
                    child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan Patient Delivery QR Code',
                          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Order #$shortOrderId • ${widget.customerName ?? "Patient"}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textGrey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Simulated Scanner / Camera Preview Card
              Container(
                height: 170,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_outlined, color: Color(0xFF10B981), size: 32),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Point Camera at Patient QR Code',
                          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Patient shows QR from their tracking screen',
                          style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                    Positioned(
                      bottom: 10,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.check_circle_rounded, size: 16),
                        label: const Text('Simulate Scan & Match QR', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openSignaturePadDialog();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Manual Code Entry Fallback
              PharmaField(
                label: 'Or Enter Patient Verification Code',
                hint: 'e.g. PHARMALINK_DELIVERY:... or #$shortOrderId',
                prefixIcon: Icons.keyboard_alt_outlined,
                controller: codeCtrl,
              ),
              const SizedBox(height: 14),

              PharmaButton(
                label: 'Verify Code & Open Signature',
                icon: Icons.draw_rounded,
                onPressed: () {
                  final input = codeCtrl.text.trim();
                  if (input.isEmpty || input.contains(widget.orderId) || input.contains(shortOrderId) || input.contains('PHARMALINK')) {
                    Navigator.pop(ctx);
                    _openSignaturePadDialog();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid QR code data. Please scan the patient screen.'), backgroundColor: AppColors.error),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Open Digital Signature Pad for Patient to Sign
  void _openSignaturePadDialog() {
    final SignatureController sigController = SignatureController(
      penStrokeWidth: 3.5,
      penColor: const Color(0xFF0F172A),
      exportBackgroundColor: Colors.white,
    );
    bool isSavingSignature = false;
    final commissionFcfa = ((_orderTotal > 0 ? _orderTotal : 5000) * 0.1).round();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: AppColors.lightGreen, shape: BoxShape.circle),
                child: const Icon(Icons.draw_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patient Digital Signature',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    Text(
                      'Please hand device to patient to sign for receipt',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 2),
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Signature(
                    controller: sigController,
                    height: 180,
                    backgroundColor: const Color(0xFFFAFAFA),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sign with finger above',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textGrey, fontStyle: FontStyle.italic),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.refresh, size: 14, color: Color(0xFFEF4444)),
                    label: const Text('Clear', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: () => sigController.clear(),
                  ),
                ],
              ),
              const Divider(height: 16),

              // Summary Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Pharmacy Payment', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                        const Text('Will be VALIDATED', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF10B981))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Your Driver Commission', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                        Text('FCFA $commissionFcfa (10%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: isSavingSignature ? null : () => Navigator.pop(dlgCtx),
                    child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: AppColors.textGrey)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: isSavingSignature
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle, size: 18),
                    label: Text(
                      isSavingSignature ? 'Processing...' : 'Confirm Delivery',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    onPressed: isSavingSignature
                        ? null
                        : () async {
                            if (sigController.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please have the patient sign before confirming delivery.'), backgroundColor: AppColors.error),
                              );
                              return;
                            }

                            setDlgState(() => isSavingSignature = true);
                            try {
                              final Uint8List? pngBytes = await sigController.toPngBytes();
                              String? base64Sig;
                              if (pngBytes != null) {
                                base64Sig = 'data:image/png;base64,${base64Encode(pngBytes)}';
                              }

                              // 1. Submit signature & mark delivery delivered
                              await _api.post('/orders/${widget.orderId}/signature', data: {
                                'signatureBase64': base64Sig,
                              });

                              // 2. Patch delivery status
                              await _api.patch('/driver/deliveries/${widget.deliveryId}/deliver').catchError((_) => null);

                              if (mounted && dlgCtx.mounted) {
                                Navigator.pop(dlgCtx);
                              }

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('🎉 Delivery completed! FCFA $commissionFcfa commission credited to your wallet.'),
                                    backgroundColor: AppColors.primary,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                                Navigator.pop(context, true);
                              }
                            } catch (e) {
                              setDlgState(() => isSavingSignature = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error validating delivery: $e'), backgroundColor: AppColors.error),
                                );
                              }
                            }
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
    final shortOrderId = widget.orderId.length >= 8 ? widget.orderId.substring(0, 8).toUpperCase() : widget.orderId.toUpperCase();
    final commission = ((_orderTotal > 0 ? _orderTotal : 5000) * 0.1).round();

    return Scaffold(
      appBar: AppBar(
        title: Text('Live Delivery Navigation (#$shortOrderId)', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15)),
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                _stepItem(2, 'Scan QR & Patient Sign', _pickedUp),
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

          // ─── Bottom Status & QR Scanner Panel ────────────────────────────────
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
                                _pickedUp ? (widget.customerName ?? 'Customer Dropoff') : (widget.pharmacyName ?? 'Pharmacy Pickup'),
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13.5),
                              ),
                              Text(
                                _pickedUp ? 'Scan patient QR code on arrival to get signature' : 'Collect medication package from pharmacist',
                                style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Commission', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                            Text('FCFA $commission', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ─── Action Buttons ──────────────────────────────────────────
                  if (!_pickedUp)
                    PharmaButton(
                      label: 'Confirm Pickup at ${widget.pharmacyName ?? 'Pharmacy'}',
                      onPressed: _confirmPickup,
                      isLoading: _loading,
                      icon: Icons.check_circle_outline,
                    )
                  else ...[
                    // Scan QR Code & Sign Button
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D6E48), Color(0xFF047857)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _startQrScanAndSignatureFlow,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 22),
                                const SizedBox(width: 10),
                                Text(
                                  'Scan Patient QR & Validate Signature',
                                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                              side: const BorderSide(color: Color(0xFF2563EB)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                            ),
                            icon: const Icon(Icons.camera_alt, size: 16),
                            label: const Text('Proof Photo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
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
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                            ),
                            icon: const Icon(Icons.draw_rounded, size: 16),
                            label: const Text('Direct Signature', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                            onPressed: _openSignaturePadDialog,
                          ),
                        ),
                      ],
                    ),
                  ],
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
          width: 24,
          height: 24,
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
                fontSize: 11,
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
