import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/doc_picker_helper.dart';
import '../../widgets/shared_widgets.dart';

class PharmacistUploadLicenseScreen extends StatefulWidget {
  final String? initialLicenseNumber;
  final String? initialPharmacyName;
  final String? rejectionReason;
  final String? approvalStatus;

  const PharmacistUploadLicenseScreen({
    super.key,
    this.initialLicenseNumber,
    this.initialPharmacyName,
    this.rejectionReason,
    this.approvalStatus,
  });

  @override
  State<PharmacistUploadLicenseScreen> createState() => _PharmacistUploadLicenseScreenState();
}

class _PharmacistUploadLicenseScreenState extends State<PharmacistUploadLicenseScreen> {
  final _api = ApiService();
  final _licenseNumberController = TextEditingController();
  final _pharmacyNameController = TextEditingController();
  final _pharmacyAddressController = TextEditingController();
  SelectedDoc? _selectedDoc;
  bool _loading = false;
  bool _uploaded = false;
  String? _rejectionReason;

  @override
  void initState() {
    super.initState();
    if (widget.initialLicenseNumber != null) {
      _licenseNumberController.text = widget.initialLicenseNumber!;
    }
    if (widget.initialPharmacyName != null) {
      _pharmacyNameController.text = widget.initialPharmacyName!;
    }
    _rejectionReason = widget.rejectionReason;
    if (widget.approvalStatus == 'pending') {
      _uploaded = true;
    }
  }

  @override
  void dispose() {
    _licenseNumberController.dispose();
    _pharmacyNameController.dispose();
    _pharmacyAddressController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    final doc = await DocPickerHelper.showPickerModal(
      context,
      title: 'Select ONPC License (PDF or Photo)',
    );
    if (doc != null) {
      setState(() {
        _selectedDoc = doc;
        _uploaded = false;
      });
    }
  }

  Future<void> _upload() async {
    if (_licenseNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your ONPC Registration / License Number'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final formData = FormData.fromMap({
        if (_selectedDoc != null)
          'license': MultipartFile.fromBytes(
            _selectedDoc!.bytes,
            filename: _selectedDoc!.name,
          ),
        'licenseNumber': _licenseNumberController.text.trim(),
        if (_pharmacyNameController.text.trim().isNotEmpty) 'pharmacyName': _pharmacyNameController.text.trim(),
        if (_pharmacyAddressController.text.trim().isNotEmpty) 'pharmacyAddress': _pharmacyAddressController.text.trim(),
      });

      await _api.postForm('/pharmacist/license', formData);
      setState(() {
        _uploaded = true;
        _rejectionReason = null;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ ONPC License submitted successfully! Pending admin cross-check.'),
          backgroundColor: AppColors.primary,
        ),
      );
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
      appBar: AppBar(title: const Text('ONPC License Verification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Rejection banner if previously rejected
          if (_rejectionReason != null && _rejectionReason!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.4)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Verification Rejected by Admin', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('Reason: $_rejectionReason', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                      const SizedBox(height: 6),
                      const Text('Please verify your ONPC registration number and pharmacy details and re-upload your valid document below.', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                    ],
                  ),
                ),
              ]),
            ),

          // Status Banner
          if (_uploaded)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(12)),
              child: const Row(children: [
                Icon(Icons.hourglass_top_outlined, color: AppColors.primary, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('License Submitted — Under Review', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14)),
                    SizedBox(height: 2),
                    Text('The admin is cross-checking your license against the ONPC registry. You will receive a notification once approved.', style: TextStyle(fontSize: 12, color: Color(0xFF1B5E20))),
                  ]),
                ),
              ]),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.local_pharmacy_outlined, color: Colors.orange, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'PharmaLink requires verified credentials issued by ONPC (Ordre National des Pharmaciens du Cameroun) to sell medications. Both PDF and image documents are accepted.',
                    style: TextStyle(fontSize: 12, color: Colors.orange, height: 1.3),
                  ),
                ),
              ]),
            ),

          const SizedBox(height: 20),

          // ONPC License Number Input
          const Text('ONPC Pharmacy License / Registration Number *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _licenseNumberController,
            decoration: InputDecoration(
              hintText: 'e.g., ONPC/PHARM/2022/104 or ONPC/PHARM/2021/045',
              prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.primary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: const [
              Icon(Icons.check_circle_outline, size: 14, color: AppColors.primary),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Entering your ONPC License ID is sufficient for instant registry cross-checking. Document upload below is optional.',
                  style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Pharmacy Name Input
          const Text('Pharmacy Official Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _pharmacyNameController,
            decoration: InputDecoration(
              hintText: 'e.g., Pharmacie du Centre, Pharmacie Bastos',
              prefixIcon: const Icon(Icons.storefront_outlined, color: AppColors.primary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),

          // Pharmacy Address Input
          const Text('Pharmacy Physical Address (Yaoundé)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _pharmacyAddressController,
            decoration: InputDecoration(
              hintText: 'e.g., Rue Joseph Essono Balla, Bastos, Yaoundé',
              prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),

          const Text('Pharmacy License Document (PDF or Photo) — Optional', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          DocUploadPreviewCard(
            selectedDoc: _selectedDoc,
            label: 'Pharmacy License (Optional)',
            hint: 'PDF, JPG, PNG • Optional if License Number provided',
            onTap: _pickDocument,
          ),

          const SizedBox(height: 20),

          const Text('Verification Guidelines', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...[
            'License must be registered with ONPC (Ordre National des Pharmaciens du Cameroun)',
            'Titular pharmacist name and pharmacy authorization will be matched against official ONPC records',
            'Document upload is optional — only required if your license is not yet in the preloaded registry',
            'Instant approval when your ONPC license ID matches official registry records',
          ].map((req) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.check_circle_outline, color: AppColors.accent, size: 15),
                  const SizedBox(width: 8),
                  Expanded(child: Text(req, style: const TextStyle(fontSize: 12, color: AppColors.textGrey))),
                ]),
              )),
          const SizedBox(height: 24),
          PharmaButton(
            label: _uploaded ? 'Update License Details' : 'Submit for ONPC Verification',
            onPressed: _upload,
            isLoading: _loading,
            icon: Icons.verified_user_outlined,
          ),
        ]),
      ),
    );
  }
}
