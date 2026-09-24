import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'constants.dart';

class SelectedDoc {
  final Uint8List bytes;
  final String name;
  final int size;

  const SelectedDoc({
    required this.bytes,
    required this.name,
    required this.size,
  });

  bool get isPdf => name.toLowerCase().endsWith('.pdf');
  bool get isImage => !isPdf;

  String get sizeString {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class DocPickerHelper {
  static final _imagePicker = ImagePicker();

  /// Pick document (PDF, PNG, JPG, JPEG) using FilePicker
  static Future<SelectedDoc?> pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes != null) {
          return SelectedDoc(
            bytes: bytes,
            name: file.name,
            size: file.size,
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking document with FilePicker: $e');
    }
    return null;
  }

  /// Pick image from gallery
  static Future<SelectedDoc?> pickImageFromGallery() async {
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        return SelectedDoc(
          bytes: bytes,
          name: picked.name.isNotEmpty ? picked.name : 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
          size: bytes.length,
        );
      }
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
    }
    return null;
  }

  /// Take photo using camera
  static Future<SelectedDoc?> pickImageFromCamera() async {
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        return SelectedDoc(
          bytes: bytes,
          name: picked.name.isNotEmpty ? picked.name : 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
          size: bytes.length,
        );
      }
    } catch (e) {
      debugPrint('Error capturing photo from camera: $e');
    }
    return null;
  }

  static Future<SelectedDoc?> showPickerModal(BuildContext context, {String title = 'Upload Verification Document'}) async {
    return showModalBottomSheet<SelectedDoc?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 16),
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 24),
                  ),
                  title: const Text('Select PDF or File', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Upload official PDF certificate or scanned document', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textGrey),
                  onTap: () async {
                    final doc = await pickDocument();
                    if (ctx.mounted) Navigator.pop(ctx, doc);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.photo_library_outlined, color: AppColors.primary, size: 24),
                  ),
                  title: const Text('Choose Photo from Gallery', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('PNG, JPG, JPEG from your device photo library', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textGrey),
                  onTap: () async {
                    final doc = await pickImageFromGallery();
                    if (ctx.mounted) Navigator.pop(ctx, doc);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.teal.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.camera_alt_outlined, color: Colors.teal, size: 24),
                  ),
                  title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Capture license or badge directly with camera', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textGrey),
                  onTap: () async {
                    final doc = await pickImageFromCamera();
                    if (ctx.mounted) Navigator.pop(ctx, doc);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DocUploadPreviewCard extends StatelessWidget {
  final SelectedDoc? selectedDoc;
  final String label;
  final String hint;
  final VoidCallback onTap;

  const DocUploadPreviewCard({
    super.key,
    required this.selectedDoc,
    required this.label,
    this.hint = 'PDF, JPG, PNG • Max 5MB',
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final doc = selectedDoc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: doc != null ? AppColors.lightGreen.withOpacity(0.6) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: doc != null ? AppColors.primary : const Color(0xFFE2E8F0),
            width: doc != null ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: doc != null
            ? Row(
                children: [
                  // Visual preview: PDF badge or Image thumbnail
                  if (doc.isPdf)
                    Container(
                      width: 64,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.picture_as_pdf, color: Colors.red, size: 30),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('PDF', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        doc.bytes,
                        width: 64,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 64,
                          height: 72,
                          color: AppColors.lightGreen,
                          child: const Icon(Icons.image, color: AppColors.primary),
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
                            const Icon(Icons.check_circle, color: AppColors.primary, size: 16),
                            const SizedBox(width: 5),
                            Text(
                              doc.isPdf ? 'PDF Document Ready' : 'Image Ready',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          doc.name,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Size: ${doc.sizeString}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Tap to change', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: AppColors.lightGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap to upload $label',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hint,
                    style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                  ),
                ],
              ),
      ),
    );
  }
}
