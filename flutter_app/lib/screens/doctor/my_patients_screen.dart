import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import 'write_prescription_screen.dart';

// ─── My Patients ──────────────────────────────────────────────────────────────
class MyPatientsScreen extends StatefulWidget {
  const MyPatientsScreen({super.key});
  @override
  State<MyPatientsScreen> createState() => _MyPatientsScreenState();
}

class _MyPatientsScreenState extends State<MyPatientsScreen> {
  final _api = ApiService();
  List _patients = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await _api.get('/doctor/patients');
      setState(() => _patients = res.data['data'] ?? []);
    } catch (_) {} finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Patients')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _patients.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final p = _patients[i];
                return ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFEEEEEE))),
                  leading: CircleAvatar(backgroundColor: AppColors.lightGreen,
                    child: Text((p['name'] ?? 'P')[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))),
                  title: Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(p['email'] ?? p['phone'] ?? '', style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textGrey),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WritePrescriptionScreen(patientId: p['id'], patientName: p['name']))),
                );
              },
            ),
    );
  }
}

