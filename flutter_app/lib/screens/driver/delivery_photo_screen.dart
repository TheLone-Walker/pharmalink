import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';

class DeliveryPhotoScreen extends StatefulWidget {
  final String orderId;
  final String? deliveryId;

  const DeliveryPhotoScreen({
    super.key,
    required this.orderId,
    this.deliveryId,
  });

  @override
  State<DeliveryPhotoScreen> createState() => _DeliveryPhotoScreenState();
}

class _DeliveryPhotoScreenState extends State<DeliveryPhotoScreen> {
  final _api = ApiService();
  final _picker = ImagePicker();
  Uint8List? _photoBytes;
  String _fileName = 'proof.jpg';
  bool _loading = false;

  Future<void> _takePhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _photoBytes = bytes;
        _fileName = picked.name.isNotEmpty ? picked.name : 'proof_${widget.orderId}.jpg';
      });
    }
  }

  Future<void> _fromGallery() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _photoBytes = bytes;
        _fileName = picked.name.isNotEmpty ? picked.name : 'proof_${widget.orderId}.jpg';
      });
    }
  }

  Future<void> _submit() async {
    if (_photoBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please take or select a proof photo first'), backgroundColor: AppColors.error),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final formData = FormData.fromMap({
        'photo': MultipartFile.fromBytes(_photoBytes!, filename: _fileName),
      });

      if (widget.deliveryId != null && widget.deliveryId!.isNotEmpty) {
        await _api.postForm('/driver/deliveries/${widget.deliveryId}/photo', formData);
      } else {
        await _api.postForm('/orders/${widget.orderId}/signature', formData);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Proof photo uploaded successfully!'), backgroundColor: AppColors.primary),
      );
      Navigator.pop(context, true);
    } catch (e) {
      String msg = 'Upload failed. Please try again.';
      if (e is DioException && e.response?.data != null && e.response?.data['message'] != null) {
        msg = e.response!.data['message'].toString();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Proof of Delivery Photo')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(12)),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Take a clear photo showing the delivered medication package and location. This photo is securely archived on the server as delivery evidence.',
                      style: TextStyle(fontSize: 12, color: AppColors.primary, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Photo Preview Area
            Expanded(
              child: _photoBytes != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(_photoBytes!, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: GestureDetector(
                            onTap: () => setState(() => _photoBytes = null),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    )
                  : GestureDetector(
                      onTap: _takePhoto,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(color: AppColors.lightGreen, shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt, color: AppColors.primary, size: 40),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Tap to Open Camera',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textDark),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Capture package handover at customer door',
                              style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            if (_photoBytes == null)
              PharmaButton(
                label: 'Choose from Gallery',
                onPressed: _fromGallery,
                outlined: true,
                icon: Icons.photo_library_outlined,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: PharmaButton(
                      label: 'Retake Photo',
                      onPressed: _takePhoto,
                      outlined: true,
                      icon: Icons.camera_alt,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PharmaButton(
                      label: 'Submit Proof',
                      onPressed: _submit,
                      isLoading: _loading,
                      icon: Icons.check,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
