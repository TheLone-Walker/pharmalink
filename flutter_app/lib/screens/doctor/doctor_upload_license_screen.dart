import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/doc_picker_helper.dart';
import '../../widgets/shared_widgets.dart';

class DoctorUploadLicenseScreen extends StatefulWidget {
  final String? initialLicenseNumber;
  final String? rejectionReason;
  final String? approvalStatus;

  const DoctorUploadLicenseScreen({
    super.key,
    this.initialLicenseNumber,
    this.rejectionReason,
    this.approvalStatus,
  });

  @override
  State<DoctorUploadLicenseScreen> createState() => _DoctorUploadLicenseScreenState();
}

class _DoctorUploadLicenseScreenState extends State<DoctorUploadLicenseScreen> {
  final _api = ApiService();
  final _licenseNumberController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _hospitalController = TextEditingController();
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
    _rejectionReason = widget.rejectionReason;
    if (widget.approvalStatus == 'pending') {
      _uploaded = true;
    }
  }

  @override
  void dispose() {
    _licenseNumberController.dispose();
    _specialtyController.dispose();
    _hospitalController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    final doc = await DocPickerHelper.showPickerModal(
      context,
      title: 'Select ONMC License (PDF or Photo)',
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
          content: Text('Please enter your ONMC License / Registration Number'),
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
        if (_specialtyController.text.trim().isNotEmpty) 'specialty': _specialtyController.text.trim(),
        if (_hospitalController.text.trim().isNotEmpty) 'hospital': _hospitalController.text.trim(),
      });

      await _api.postForm('/doctor/license', formData);
      setState(() {
        _uploaded = true;
        _rejectionReason = null;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ ONMC License submitted successfully! Pending admin cross-check.'),
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
      appBar: AppBar(title: const Text('ONMC License Verification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Rejection Banner if previously rejected
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
                      const Text('Please verify your ONMC number and re-upload a clear, valid license document below.', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
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
                    Text('License Submitted — Pending Review', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14)),
                    SizedBox(height: 2),
                    Text('The admin is cross-checking your credentials against the official ONMC registry. You will be notified immediately once approved.', style: TextStyle(fontSize: 12, color: Color(0xFF1B5E20))),
                  ]),
                ),
              ]),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.verified_user_outlined, color: Colors.orange, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'PharmaLink requires verified medical credentials issued by ONMC (Ordre National des Médecins du Cameroun). Both PDF and image documents are accepted.',
                    style: TextStyle(fontSize: 12, color: Colors.orange, height: 1.3),
                  ),
                ),
              ]),
            ),

          const SizedBox(height: 20),

          // ONMC License Number Input
          const Text('ONMC Registration / License Number *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _licenseNumberController,
            decoration: InputDecoration(
              hintText: 'e.g., ONMC/2023/8492 or ONMC/2024/9021',
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
                  'Entering your ONMC License ID is sufficient for instant registry cross-checking. Document upload below is optional.',
                  style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Specialty Input
          const Text('Medical Specialty (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _specialtyController,
            decoration: InputDecoration(
              hintText: 'e.g., Cardiology, General Medicine, Pediatrics',
              prefixIcon: const Icon(Icons.medical_services_outlined, color: AppColors.primary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),

          // Hospital / Practice Autocomplete Input
          const Text('Hospital / Practice (Yaoundé)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Autocomplete<String>(
            initialValue: TextEditingValue(text: _hospitalController.text),
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return AppConstants.cameroonHospitals.take(5);
              }
              return AppConstants.cameroonHospitals.where((String option) {
                return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
              });
            },
            onSelected: (String selection) {
              _hospitalController.text = selection;
            },
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              controller.addListener(() {
                _hospitalController.text = controller.text;
              });
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: 'e.g. Hôpital Central de Yaoundé (type for suggestions)',
                  prefixIcon: const Icon(Icons.apartment_outlined, color: AppColors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 6.0,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 220, maxWidth: 330),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEEEEEE))),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) {
                        final String option = options.elementAt(index);
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.local_hospital, size: 16, color: AppColors.primary),
                          title: Text(option, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          const Text('Medical License Document (PDF or Photo) — Optional', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          DocUploadPreviewCard(
            selectedDoc: _selectedDoc,
            label: 'License Document (Optional)',
            hint: 'PDF, JPG, PNG • Optional if License Number provided',
            onTap: _pickDocument,
          ),

          const SizedBox(height: 20),

          const Text('Verification Guidelines', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...[
            'License ID must be registered with ONMC (Ordre National des Médecins du Cameroun)',
            'Doctor name and license number will be matched against official ONMC registry',
            'Document upload is optional — only required if your license is not yet in the preloaded registry',
            'Instant approval when your ONMC license ID matches official registry records',
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
            label: _uploaded ? 'Update License Details' : 'Submit for ONMC Verification',
            onPressed: _upload,
            isLoading: _loading,
            icon: Icons.verified_user_outlined,
          ),
        ]),
      ),
    );
  }
}
