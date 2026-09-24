import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/doc_picker_helper.dart';
import '../../widgets/shared_widgets.dart';

class DriverUploadDocsScreen extends StatefulWidget {
  const DriverUploadDocsScreen({super.key});
  @override
  State<DriverUploadDocsScreen> createState() => _DriverUploadDocsScreenState();
}

class _DriverUploadDocsScreenState extends State<DriverUploadDocsScreen> {
  final _api = ApiService();
  SelectedDoc? _licenseDoc;
  SelectedDoc? _nationalIdDoc;
  bool _loading = false;

  Future<void> _pickFile(bool isLicense) async {
    final doc = await DocPickerHelper.showPickerModal(
      context,
      title: isLicense ? 'Upload Driver\'s License' : 'Upload National ID Card',
    );
    if (doc != null) {
      setState(() {
        if (isLicense) {
          _licenseDoc = doc;
        } else {
          _nationalIdDoc = doc;
        }
      });
    }
  }

  Future<void> _upload() async {
    if (_licenseDoc == null && _nationalIdDoc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one document to upload'), backgroundColor: AppColors.error),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final formData = FormData();
      if (_licenseDoc != null) {
        formData.files.add(MapEntry(
          'driverLicense',
          MultipartFile.fromBytes(_licenseDoc!.bytes, filename: _licenseDoc!.name),
        ));
      }
      if (_nationalIdDoc != null) {
        formData.files.add(MapEntry(
          'nationalId',
          MultipartFile.fromBytes(_nationalIdDoc!.bytes, filename: _nationalIdDoc!.name),
        ));
      }
      await _api.postForm('/driver/documents', formData);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Documents uploaded! Pending admin review.'), backgroundColor: AppColors.primary),
      );
      Navigator.pop(context);
    } catch (e) {
      String msg = 'Upload failed. Try again.';
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
      appBar: AppBar(title: const Text('Upload Driver Documents')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(12)),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Upload your Driver\'s License and National ID for verification. '
                  'Accepted formats: PDF, JPG, PNG, WEBP (max 5MB). '
                  'Your account will be reviewed within 24 hours.',
                  style: TextStyle(fontSize: 12, color: AppColors.primary),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // Driver's License
          const Text('Driver\'s License *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          DocUploadPreviewCard(
            selectedDoc: _licenseDoc,
            label: 'Driver\'s License (PDF or Photo)',
            hint: 'PDF, JPG, PNG • Max 5MB',
            onTap: () => _pickFile(true),
          ),
          const SizedBox(height: 20),

          // National ID
          const Text('National ID Card (Optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          DocUploadPreviewCard(
            selectedDoc: _nationalIdDoc,
            label: 'National ID Card (PDF or Photo)',
            hint: 'PDF, JPG, PNG • Max 5MB',
            onTap: () => _pickFile(false),
          ),
          const SizedBox(height: 32),
          PharmaButton(label: 'Upload Documents', onPressed: _upload, isLoading: _loading, icon: Icons.upload_file),
        ]),
      ),
    );
  }
}
