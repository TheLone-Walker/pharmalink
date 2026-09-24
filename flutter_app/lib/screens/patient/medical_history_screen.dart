import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

class MedicalHistoryScreen extends StatefulWidget {
  const MedicalHistoryScreen({super.key});
  @override
  State<MedicalHistoryScreen> createState() => _MedicalHistoryScreenState();
}

class _MedicalHistoryScreenState extends State<MedicalHistoryScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _consultations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/prescriptions/medical-history');
      final list = res.data['data'] as List? ?? [];
      setState(() {
        _consultations = list.cast<Map<String, dynamic>>();
      });
    } catch (_) {
      try {
        final fallback = await _api.get('/medical-history');
        final list = fallback.data['data'] as List? ?? [];
        setState(() {
          _consultations = list.cast<Map<String, dynamic>>();
        });
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Consultations & Medical History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _consultations.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _consultations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, i) => _buildConsultationCard(_consultations[i]),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.lightGreen, shape: BoxShape.circle),
            child: const Icon(Icons.history_edu_outlined, size: 50, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text('No Consultation Records Yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Your doctor consultation history, clinical vitals, and diagnosed health records will be listed here after your doctor visits.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGrey, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsultationCard(Map<String, dynamic> c) {
    final date = DateTime.tryParse(c['date'] ?? c['createdAt'] ?? '');
    final data = c['consultationData'] as Map<String, dynamic>? ?? {};
    final doctor = c['doctor'] as Map<String, dynamic>?;
    final doctorName = data['doctorName'] ?? doctor?['name'] ?? 'Doctor Consultation';
    final hospitalName = data['hospitalName'] ?? doctor?['hospital'] ?? 'Medical Center';
    final diagnosis = c['diagnosis'] ?? data['diagnosis'] ?? 'Medical Consultation';
    final symptoms = data['symptoms'] as String? ?? '';
    final vitals = data['vitals'] as Map<String, dynamic>? ?? {};
    final clinicalNotes = data['clinicalNotes'] as String? ?? c['notes'] ?? '';
    final recommendations = data['recommendations'] as String? ?? '';
    final medications = data['prescribedMedications'] as List? ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.lightGreen.withOpacity(0.6),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.primary,
                  radius: 18,
                  child: Icon(Icons.medical_information, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dr. $doctorName', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(hospitalName, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                    ],
                  ),
                ),
                if (date != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Diagnosis Tag
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Diagnosis: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
                    Expanded(
                      child: Text(
                        diagnosis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Symptoms if present
                if (symptoms.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.sick_outlined, size: 15, color: Colors.orange),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Symptoms: $symptoms',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // Vitals Chips
                if (_hasAnyVitals(vitals)) ...[
                  const Text('Clinical Vitals Recorded:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if ((vitals['bloodPressure'] ?? '').isNotEmpty)
                        _vitalBadge('BP', '${vitals['bloodPressure']} mmHg', Icons.favorite_border),
                      if ((vitals['temperature'] ?? '').isNotEmpty)
                        _vitalBadge('Temp', '${vitals['temperature']} °C', Icons.thermostat_outlined),
                      if ((vitals['heartRate'] ?? '').isNotEmpty)
                        _vitalBadge('Pulse', '${vitals['heartRate']} bpm', Icons.timeline),
                      if ((vitals['respiratoryRate'] ?? '').isNotEmpty)
                        _vitalBadge('Resp', '${vitals['respiratoryRate']} cpm', Icons.air),
                      if ((vitals['weight'] ?? '').isNotEmpty)
                        _vitalBadge('Weight', '${vitals['weight']} kg', Icons.scale_outlined),
                      if ((vitals['bloodSugar'] ?? '').isNotEmpty)
                        _vitalBadge('Sugar', '${vitals['bloodSugar']} mg/dL', Icons.water_drop_outlined),
                      if ((vitals['spo2'] ?? '').isNotEmpty)
                        _vitalBadge('SpO2', '${vitals['spo2']}%', Icons.bubble_chart_outlined),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Clinical notes
                if (clinicalNotes.isNotEmpty && !clinicalNotes.startsWith('{')) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Doctor Notes / Findings:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textGrey)),
                        const SizedBox(height: 4),
                        Text(clinicalNotes, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Recommendations
                if (recommendations.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline, size: 15, color: Colors.amber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Advice: $recommendations',
                          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF4B5563)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // Prescribed medications
                if (medications.isNotEmpty) ...[
                  const Divider(height: 16),
                  const Text('Prescribed Medications (Rx):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  const SizedBox(height: 6),
                  ...medications.map((m) {
                    final name = m['name'] ?? m['medicationName'] ?? '';
                    final dosage = m['dosage'] ?? '';
                    final instructions = m['instructions'] ?? '';
                    final days = m['durationDays'] != null ? '${m['durationDays']} days' : '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.medication, size: 14, color: AppColors.accent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '$name ${dosage.isNotEmpty ? '• $dosage' : ''} ${days.isNotEmpty ? '• $days' : ''}${instructions.isNotEmpty ? '\n↳ $instructions' : ''}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF1F2937)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _hasAnyVitals(Map<String, dynamic> vitals) {
    return vitals.values.any((v) => v != null && v.toString().trim().isNotEmpty);
  }

  Widget _vitalBadge(String label, String val, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text('$label: $val', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        ],
      ),
    );
  }
}
