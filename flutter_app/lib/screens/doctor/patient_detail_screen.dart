import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';
import '../shared/chat_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  final String patientId;
  const PatientDetailScreen({super.key, required this.patientId});
  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tab;
  Map? _patient;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final res = await _api.get('/doctor/patients/${widget.patientId}');
      setState(() => _patient = res.data['data']);
    } catch (_) {} finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    if (_patient == null) return const Scaffold(body: Center(child: Text('Patient not found')));

    final profile = _patient!['patientProfile'];
    final prescriptions = _patient!['patientPrescriptions'] as List? ?? [];
    final history = _patient!['medicalHistories'] as List? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_patient!['name'] ?? 'Patient'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InAppChatScreen(
              receiverId: _patient!['id'],
              receiverName: _patient!['name'] ?? 'Patient',
              receiverRole: 'patient',
            ))),
          ),
          IconButton(
            icon: const Icon(Icons.note_add_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
              WritePrescriptionScreen(patientId: _patient!['id'], patientName: _patient!['name']))),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [Tab(text: 'Overview'), Tab(text: 'Prescriptions'), Tab(text: 'History')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // Overview
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(
                  radius: 30, backgroundColor: AppColors.lightGreen,
                  child: Text((_patient!['name'] ?? 'P')[0],
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_patient!['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  Text(_patient!['email'] ?? _patient!['phone'] ?? '',
                    style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                ])),
              ]),
              const SizedBox(height: 20),
              const Text('Patient Information', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _infoRow(Icons.bloodtype_outlined, 'Blood Type', profile?['bloodType'] ?? 'Unknown'),
              _infoRow(Icons.warning_amber_outlined, 'Allergies', profile?['allergies'] ?? 'None known'),
              _infoRow(Icons.location_on_outlined, 'Address', profile?['address'] ?? 'Not provided'),
            ]),
          ),

          // Prescriptions
          prescriptions.isEmpty
              ? _emptyState('No prescriptions issued', Icons.description_outlined)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: prescriptions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final p = prescriptions[i];
                    final date = DateTime.tryParse(p['createdAt'] ?? '');
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFEEEEEE)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(date != null ? '${date.day}/${date.month}/${date.year}' : '',
                            style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(6)),
                            child: Text(p['status'] ?? '',
                              style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        ...(p['items'] as List? ?? []).map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(children: [
                            const Icon(Icons.medication_outlined, color: AppColors.accent, size: 14),
                            const SizedBox(width: 6),
                            Expanded(child: Text('${item['medicationName']} • ${item['dosage'] ?? ''}',
                              style: const TextStyle(fontSize: 13))),
                          ]),
                        )),
                      ]),
                    );
                  },
                ),

          // Medical History
          history.isEmpty
              ? _emptyState('No medical history', Icons.history)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final h = history[i];
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFFEEEEEE)),
                      ),
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.lightGreen,
                        child: Icon(Icons.medical_services_outlined, color: AppColors.primary, size: 18),
                      ),
                      title: Text(h['diagnosis'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(h['notes'] ?? '', style: const TextStyle(fontSize: 12)),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: AppColors.accent, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ])),
      ]),
    );
  }

  Widget _emptyState(String msg, IconData icon) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 60, color: Colors.grey[300]),
      const SizedBox(height: 12),
      Text(msg, style: const TextStyle(color: AppColors.textGrey)),
    ]));
  }
}
