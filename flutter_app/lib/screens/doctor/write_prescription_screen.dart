import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';

class WritePrescriptionScreen extends StatefulWidget {
  final String? patientId;
  final String? patientName;
  final String? appointmentId;

  const WritePrescriptionScreen({
    super.key,
    this.patientId,
    this.patientName,
    this.appointmentId,
  });

  @override
  State<WritePrescriptionScreen> createState() => _WritePrescriptionScreenState();
}

class _WritePrescriptionScreenState extends State<WritePrescriptionScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabController;

  // Selected Patient State
  String? _selectedPatientId;
  String? _selectedPatientName;
  Map<String, dynamic>? _selectedPatientData;
  List<Map<String, dynamic>> _patientsList = [];
  bool _loadingPatients = false;

  // Consultation Controllers
  final _symptomsCtrl = TextEditingController();
  final _bpCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  final _pulseCtrl = TextEditingController();
  final _respRateCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _sugarCtrl = TextEditingController();
  final _spo2Ctrl = TextEditingController();
  final _clinicalNotesCtrl = TextEditingController();
  final _diagnosisCtrl = TextEditingController();
  final _recommendationsCtrl = TextEditingController();

  // Prescription Items
  final List<Map<String, TextEditingController>> _medicationItems = [];
  final _pharmacyNotesCtrl = TextEditingController();

  // Lab Analysis Request State
  final Set<String> _selectedLabTests = {};
  final _customLabTestCtrl = TextEditingController();
  final _labInstructionsCtrl = TextEditingController();
  String _labUrgency = 'routine';
  bool _isSubmittingLab = false;

  final List<String> _commonLabTests = [
    'Malaria RDT / Thick Drop (Goutte Épaisse)',
    'Full Blood Count (NFS / CBC)',
    'Widal & Felix Serology (Typhoid)',
    'Fasting Blood Sugar (Glycemia)',
    'Urinalysis (ECBU / Dipstick)',
    'Stool Examination (KOP / Coprologie)',
    'Creatinine & Urea (Renal Profile)',
    'Liver Function (ALT / AST / Bilirubin)',
    'Lipid Profile (Cholesterol / Triglycerides)',
    'C-Reactive Protein (CRP)',
    'Chest X-Ray (Radiographie Thorax)',
    'Abdominal Ultrasound (Échographie)',
  ];

  bool _isSaving = false;

  // Quick Chips
  final List<String> _quickSymptoms = [
    'Fever',
    'Severe Headache',
    'Dry Cough',
    'Productive Cough',
    'Abdominal Pain',
    'Fatigue',
    'Vomiting',
    'Body Aches',
    'Chest Pain',
    'Sore Throat',
    'Dizziness',
  ];

  final List<String> _quickDiagnoses = [
    'Uncomplicated Malaria',
    'Acute Bronchitis',
    'Typhoid Fever',
    'Hypertension (Stage 1)',
    'Upper Respiratory Tract Infection',
    'Bacterial Gastroenteritis',
    'Allergic Rhinitis',
    'Peptic Ulcer Disease',
    'Musculoskeletal Strain',
  ];

  final List<String> _popularMedications = [
    'Artemether 80mg',
    'Artemether-Lumefantrine 20/120mg (Coartem)',
    'Artemether 80/480mg Forte',
    'Artemether Injection 80mg/ml',
    'Artesunate 50mg / Amodiaquine 153mg',
    'Paracetamol 1000mg',
    'Amoxicillin-Clavulanate 1g',
    'Ciprofloxacin 500mg',
    'Omeprazole 20mg',
    'Ibuprofen 400mg',
    'Cetirizine 10mg',
    'Metformin 500mg',
    'Amlodipine 5mg',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedPatientId = widget.patientId;
    _selectedPatientName = widget.patientName;

    _addMedicationItem();

    if (_selectedPatientId == null) {
      _loadPatients();
    } else {
      _loadPatientDetail(_selectedPatientId!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _symptomsCtrl.dispose();
    _bpCtrl.dispose();
    _tempCtrl.dispose();
    _pulseCtrl.dispose();
    _respRateCtrl.dispose();
    _weightCtrl.dispose();
    _sugarCtrl.dispose();
    _spo2Ctrl.dispose();
    _clinicalNotesCtrl.dispose();
    _diagnosisCtrl.dispose();
    _recommendationsCtrl.dispose();
    _pharmacyNotesCtrl.dispose();
    _customLabTestCtrl.dispose();
    _labInstructionsCtrl.dispose();
    for (final item in _medicationItems) {
      item['name']?.dispose();
      item['dosage']?.dispose();
      item['period']?.dispose();
      item['reminderTimes']?.dispose();
      item['mealTiming']?.dispose();
      item['instructions']?.dispose();
      item['duration']?.dispose();
    }
    super.dispose();
  }

  Future<void> _submitLabAnalysisRequest() async {
    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a patient first'), backgroundColor: Colors.orange),
      );
      return;
    }

    final customTest = _customLabTestCtrl.text.trim();
    final allTests = {..._selectedLabTests};
    if (customTest.isNotEmpty) {
      allTests.add(customTest);
    }

    if (allTests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or specify at least one laboratory test to request'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmittingLab = true);

    try {
      final payload = {
        'patientId': _selectedPatientId,
        'appointmentId': widget.appointmentId,
        'symptoms': _symptomsCtrl.text.trim(),
        'vitals': {
          'bloodPressure': _bpCtrl.text.trim(),
          'temperature': _tempCtrl.text.trim(),
          'heartRate': _pulseCtrl.text.trim(),
          'respiratoryRate': _respRateCtrl.text.trim(),
          'weight': _weightCtrl.text.trim(),
          'bloodSugar': _sugarCtrl.text.trim(),
          'spo2': _spo2Ctrl.text.trim(),
        },
        'preliminaryDiagnosis': _diagnosisCtrl.text.trim().isNotEmpty ? _diagnosisCtrl.text.trim() : 'Under Clinical Investigation',
        'clinicalNotes': _clinicalNotesCtrl.text.trim(),
        'labTests': allTests.toList(),
        'urgency': _labUrgency,
        'instructions': _labInstructionsCtrl.text.trim(),
      };

      await _api.post('/prescriptions/lab-request', data: payload);

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: const [
            Icon(Icons.science_outlined, color: AppColors.primary, size: 28),
            SizedBox(width: 10),
            Expanded(child: Text('Lab Order Dispatched!')),
          ]),
          content: Text(
            'The laboratory analysis order for ${allTests.length} test(s) has been dispatched to ${_selectedPatientName ?? 'the patient'}.\n\nPrescription is placed on hold until lab results are submitted.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending lab request: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingLab = false);
    }
  }

  Future<void> _loadPatients() async {
    setState(() => _loadingPatients = true);
    try {
      final res = await _api.get('/doctor/patients');
      final list = res.data['data'] as List? ?? [];
      setState(() {
        _patientsList = list.cast<Map<String, dynamic>>();
      });
    } catch (_) {} finally {
      setState(() => _loadingPatients = false);
    }
  }

  Future<void> _loadPatientDetail(String patientId) async {
    try {
      final res = await _api.get('/doctor/patients/$patientId');
      setState(() {
        _selectedPatientData = res.data['data'];
      });
    } catch (_) {}
  }

  void _addMedicationItem({
    String? name,
    String? dosage,
    String? period,
    String? reminderTimes,
    String? mealTiming,
    String? instructions,
    String? duration,
  }) {
    setState(() {
      _medicationItems.add({
        'name': TextEditingController(text: name ?? ''),
        'dosage': TextEditingController(text: dosage ?? '1 tablet'),
        'period': TextEditingController(text: period ?? 'Twice Daily (Morning & Evening)'),
        'reminderTimes': TextEditingController(text: reminderTimes ?? '08:00 AM, 08:00 PM'),
        'mealTiming': TextEditingController(text: mealTiming ?? 'After Meals'),
        'instructions': TextEditingController(text: instructions ?? 'Take with water after meals'),
        'duration': TextEditingController(text: duration ?? '7'),
      });
    });
  }

  void _removeMedicationItem(int index) {
    if (_medicationItems.length > 1) {
      setState(() {
        _medicationItems[index]['name']?.dispose();
        _medicationItems[index]['dosage']?.dispose();
        _medicationItems[index]['period']?.dispose();
        _medicationItems[index]['reminderTimes']?.dispose();
        _medicationItems[index]['mealTiming']?.dispose();
        _medicationItems[index]['instructions']?.dispose();
        _medicationItems[index]['duration']?.dispose();
        _medicationItems.removeAt(index);
      });
    }
  }

  void _addSymptom(String s) {
    final cur = _symptomsCtrl.text.trim();
    if (cur.isEmpty) {
      _symptomsCtrl.text = s;
    } else if (!cur.toLowerCase().contains(s.toLowerCase())) {
      _symptomsCtrl.text = '$cur, $s';
    }
  }

  void _setDiagnosis(String d) {
    _diagnosisCtrl.text = d;
  }

  Future<void> _saveConsultationAndPrescription() async {
    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a patient first'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_diagnosisCtrl.text.trim().isEmpty) {
      _tabController.animateTo(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a clinical diagnosis for the consultation'), backgroundColor: Colors.red),
      );
      return;
    }

    // Build items list with period and reminder times
    final validItems = _medicationItems
        .where((i) => (i['name']?.text.trim().isNotEmpty ?? false))
        .map((i) {
          final medName = i['name']!.text.trim();
          final dosage = i['dosage']!.text.trim();
          final period = i['period']?.text.trim() ?? 'Twice Daily';
          final reminderTimes = i['reminderTimes']?.text.trim() ?? '08:00 AM, 08:00 PM';
          final mealTiming = i['mealTiming']?.text.trim() ?? 'After Meals';
          final instructions = i['instructions']!.text.trim();
          final durationDays = int.tryParse(i['duration']!.text.trim()) ?? 7;

          return {
            'medicationName': medName,
            'dosage': dosage,
            'period': period,
            'reminderTime': reminderTimes,
            'reminderTimes': reminderTimes,
            'mealTiming': mealTiming,
            'instructions': instructions.isNotEmpty ? instructions : '$period • $mealTiming',
            'durationDays': durationDays,
          };
        })
        .toList();

    if (validItems.isEmpty) {
      _tabController.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one medication in the prescription'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final payload = {
        'patientId': _selectedPatientId,
        'appointmentId': widget.appointmentId,
        'symptoms': _symptomsCtrl.text.trim(),
        'vitals': {
          'bloodPressure': _bpCtrl.text.trim(),
          'temperature': _tempCtrl.text.trim(),
          'heartRate': _pulseCtrl.text.trim(),
          'respiratoryRate': _respRateCtrl.text.trim(),
          'weight': _weightCtrl.text.trim(),
          'bloodSugar': _sugarCtrl.text.trim(),
          'spo2': _spo2Ctrl.text.trim(),
        },
        'diagnosis': _diagnosisCtrl.text.trim(),
        'clinicalNotes': _clinicalNotesCtrl.text.trim(),
        'recommendations': _recommendationsCtrl.text.trim(),
        'notes': _pharmacyNotesCtrl.text.trim(),
        'items': validItems,
      };

      await _api.post('/prescriptions/consultation', data: payload);

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: const [
            Icon(Icons.check_circle, color: AppColors.primary, size: 28),
            SizedBox(width: 10),
            Text('Consultation Saved!'),
          ]),
          content: Text(
            'The consultation has been recorded into ${_selectedPatientName ?? 'the patient'}\'s medical history, and the prescription has been issued for patient pharmacy dispatch.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving consultation: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Clinical Consultation & Rx'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.medical_information_outlined, size: 18), text: '1. Consultation'),
            Tab(icon: Icon(Icons.science_outlined, size: 18), text: '2. Lab Request'),
            Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: '3. Prescription'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildPatientHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildConsultationTab(),
                _buildLabRequestTab(),
                _buildPrescriptionTab(),
              ],
            ),
          ),
          _buildBottomAction(),
        ],
      ),
    );
  }

  Widget _buildPatientHeader() {
    if (_selectedPatientId == null) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.person_search_outlined, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: _loadingPatients
                  ? const Text('Loading patients list...', style: TextStyle(fontSize: 13, color: AppColors.textGrey))
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text('Select Patient to Consult', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        value: _selectedPatientId,
                        items: _patientsList.map((p) {
                          return DropdownMenuItem<String>(
                            value: p['id'],
                            child: Text('${p['name']} (${p['phone'] ?? p['email'] ?? 'Patient'})',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final p = _patientsList.firstWhere((x) => x['id'] == val);
                            setState(() {
                              _selectedPatientId = val;
                              _selectedPatientName = p['name'];
                            });
                            _loadPatientDetail(val);
                          }
                        },
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    final pProf = _selectedPatientData?['patientProfile'];
    final bloodType = pProf?['bloodType'] ?? 'O+';
    final allergies = pProf?['allergies'] ?? 'No known allergies';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.lightGreen,
            radius: 20,
            child: Text(
              (_selectedPatientName ?? 'P')[0].toUpperCase(),
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedPatientName ?? 'Patient',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(4)),
                      child: Text('Blood: $bloodType', style: TextStyle(fontSize: 10, color: Colors.red[800], fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Allergies: $allergies',
                        style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.patientId == null)
            TextButton(
              onPressed: () => setState(() => _selectedPatientId = null),
              child: const Text('Change', style: TextStyle(fontSize: 12, color: AppColors.primary)),
            ),
        ],
      ),
    );
  }

  // ─── TAB 1: CONSULTATION & VITALS ──────────────────────────────────────────
  Widget _buildConsultationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Symptoms Section
          _sectionCard(
            title: 'Chief Complaint & Symptoms',
            icon: Icons.sick_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _symptomsCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Describe patient complaints, onset, duration...',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Quick Add Symptoms:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _quickSymptoms.map((s) {
                    return ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 11)),
                      backgroundColor: AppColors.lightGreen.withOpacity(0.6),
                      labelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      onPressed: () => _addSymptom(s),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Vitals Matrix
          _sectionCard(
            title: 'Vital Signs Examination',
            icon: Icons.monitor_heart_outlined,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _vitalField(controller: _bpCtrl, label: 'Blood Pressure', hint: '120/80', unit: 'mmHg', icon: Icons.favorite_border)),
                    const SizedBox(width: 12),
                    Expanded(child: _vitalField(controller: _tempCtrl, label: 'Body Temp', hint: '37.5', unit: '°C', icon: Icons.thermostat_outlined, isNumeric: true)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _vitalField(controller: _pulseCtrl, label: 'Heart Rate', hint: '75', unit: 'bpm', icon: Icons.timeline, isNumeric: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _vitalField(controller: _respRateCtrl, label: 'Resp. Rate', hint: '16', unit: 'cpm', icon: Icons.air, isNumeric: true)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _vitalField(controller: _weightCtrl, label: 'Weight', hint: '70', unit: 'kg', icon: Icons.scale_outlined, isNumeric: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _vitalField(controller: _sugarCtrl, label: 'Blood Sugar', hint: '95', unit: 'mg/dL', icon: Icons.water_drop_outlined, isNumeric: true)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _vitalField(controller: _spo2Ctrl, label: 'Oxygen Saturation', hint: '98', unit: 'SpO2 %', icon: Icons.bubble_chart_outlined, isNumeric: true)),
                    const SizedBox(width: 12),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Clinical Examination & Observations
          _sectionCard(
            title: 'Physical Examination & Clinical Notes',
            icon: Icons.notes_outlined,
            child: TextFormField(
              controller: _clinicalNotesCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Clinical observations, general appearance, chest sounds, abdominal palpation, neuro exam...',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Diagnosis
          _sectionCard(
            title: 'Clinical Diagnosis *',
            icon: Icons.verified_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _diagnosisCtrl,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
                  decoration: InputDecoration(
                    hintText: 'e.g. Uncomplicated Malaria with Mild Dehydration',
                    prefixIcon: const Icon(Icons.assignment_turned_in, color: AppColors.primary, size: 20),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Common Diagnoses:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _quickDiagnoses.map((d) {
                    return ActionChip(
                      label: Text(d, style: const TextStyle(fontSize: 11)),
                      backgroundColor: Colors.blue[50],
                      labelStyle: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.w600),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      onPressed: () => _setDiagnosis(d),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Recommendations / Advice
          _sectionCard(
            title: 'Patient Advice & Follow-Up Plan',
            icon: Icons.lightbulb_outline,
            child: TextFormField(
              controller: _recommendationsCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g. Maintain high fluid intake, rest for 3 days, follow up in 1 week if fever persists...',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Proceed to Write Prescription (Rx)', style: TextStyle(fontWeight: FontWeight.w600)),
              onPressed: () => _tabController.animateTo(1),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ─── TAB 2: PRESCRIPTION (RX) ──────────────────────────────────────────────
  Widget _buildPrescriptionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Diagnosis Summary Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.lightGreen,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.medical_services_outlined, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Consultation Diagnosis:', style: TextStyle(fontSize: 11, color: AppColors.textGrey, fontWeight: FontWeight.w600)),
                      Text(
                        _diagnosisCtrl.text.isNotEmpty ? _diagnosisCtrl.text : 'No diagnosis entered yet (set in Tab 1)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _diagnosisCtrl.text.isNotEmpty ? AppColors.primary : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Prescribed Medications (Rx)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              TextButton.icon(
                onPressed: () => _addMedicationItem(),
                icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
                label: const Text('Add Drug', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Medication Items Cards
          ..._medicationItems.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return _medicationItemCard(idx, item);
          }),

          const SizedBox(height: 12),

          // Quick Common Medications
          const Text('Quick Add Frequently Prescribed Medications:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _popularMedications.map((med) {
              return ActionChip(
                label: Text(med, style: const TextStyle(fontSize: 11)),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE5E7EB))),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                onPressed: () {
                  _addMedicationItem(
                    name: med,
                    dosage: '1 tablet',
                    period: 'Twice Daily (Morning & Evening)',
                    reminderTimes: '08:00 AM, 08:00 PM',
                    mealTiming: 'After Meals',
                    instructions: 'Take with a glass of water after food',
                    duration: '7',
                  );
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Pharmacy & Dispensing Notes
          _sectionCard(
            title: 'Pharmacy Dispensing Instructions',
            icon: Icons.local_pharmacy_outlined,
            child: TextFormField(
              controller: _pharmacyNotesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Special instructions for the pharmacist or patient regarding medication intake...',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _medicationItemCard(int idx, Map<String, TextEditingController> ctrl) {
    final medName = ctrl['name']!.text.trim();
    final reminderTimes = ctrl['reminderTimes']?.text.trim() ?? '08:00 AM, 08:00 PM';
    final period = ctrl['period']?.text.trim() ?? 'Twice Daily';
    final duration = ctrl['duration']?.text.trim() ?? '7';
    final meal = ctrl['mealTiming']?.text.trim() ?? 'After Meals';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Med # + Delete
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                    child: Center(
                      child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Medication #${idx + 1}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primary)),
                ],
              ),
              if (_medicationItems.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _removeMedicationItem(idx),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),

          const SizedBox(height: 12),

          // 1. Predictive Medication Name Autocomplete
          Autocomplete<String>(
            initialValue: TextEditingValue(text: ctrl['name']!.text),
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.trim().isEmpty) {
                return AppConstants.cameroonMedications.take(6);
              }
              final query = textEditingValue.text.toLowerCase().trim();
              return AppConstants.cameroonMedications.where((med) => med.toLowerCase().contains(query));
            },
            onSelected: (String selection) {
              ctrl['name']!.text = selection;
              setState(() {});
            },
            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
              if (ctrl['name']!.text.isNotEmpty && textEditingController.text != ctrl['name']!.text) {
                textEditingController.text = ctrl['name']!.text;
              }
              return TextFormField(
                controller: textEditingController,
                focusNode: focusNode,
                onChanged: (val) {
                  ctrl['name']!.text = val;
                  setState(() {});
                },
                decoration: InputDecoration(
                  labelText: 'Medication Name *',
                  hintText: 'Type medication name (e.g. Artemether, Paracetamol, Coartem)...',
                  prefixIcon: const Icon(Icons.medication_outlined, color: AppColors.primary, size: 20),
                  suffixIcon: textEditingController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                          onPressed: () {
                            textEditingController.clear();
                            ctrl['name']!.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: MediaQuery.of(context).size.width - 70,
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      shrinkWrap: true,
                      itemCount: options.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) {
                        final option = options.elementAt(index);
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.medication, color: AppColors.primary, size: 18),
                          title: Text(option, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.primary),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          // 2. Dosage & Duration Days Row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: ctrl['dosage'],
                  decoration: InputDecoration(
                    labelText: 'Dosage / Strength',
                    hintText: 'e.g. 1 tablet, 500mg, 10ml',
                    prefixIcon: const Icon(Icons.colorize_outlined, color: AppColors.accent, size: 18),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: ctrl['duration'],
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Duration (Days)',
                    hintText: '7',
                    prefixIcon: const Icon(Icons.calendar_today_outlined, color: AppColors.accent, size: 16),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ─── 3. Period & Schedule to Take Drug (Syncs to Patient Reminders) ─────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.alarm_add, color: AppColors.primary, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Period & Schedule (Directly Updates Patient Reminder)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Timing / Period Quick Presets
                const Text('Choose Intake Period & Alarms:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _scheduleChip(
                      label: '☀️ Morning (08:00 AM)',
                      selected: ctrl['period']?.text.contains('Morning (08:00 AM)') == true || ctrl['reminderTimes']?.text == '08:00 AM',
                      onTap: () {
                        setState(() {
                          ctrl['period']?.text = 'Once Daily (Morning)';
                          ctrl['reminderTimes']?.text = '08:00 AM';
                        });
                      },
                    ),
                    _scheduleChip(
                      label: '☀️ 🌙 Morning & Night (08:00 AM, 08:00 PM)',
                      selected: ctrl['reminderTimes']?.text == '08:00 AM, 08:00 PM',
                      onTap: () {
                        setState(() {
                          ctrl['period']?.text = 'Twice Daily (Morning & Evening)';
                          ctrl['reminderTimes']?.text = '08:00 AM, 08:00 PM';
                        });
                      },
                    ),
                    _scheduleChip(
                      label: '☀️ 🍲 🌙 3x Daily (08:00 AM, 01:00 PM, 08:00 PM)',
                      selected: ctrl['reminderTimes']?.text.contains('01:00 PM') == true,
                      onTap: () {
                        setState(() {
                          ctrl['period']?.text = '3 Times Daily (Morning, Noon & Night)';
                          ctrl['reminderTimes']?.text = '08:00 AM, 01:00 PM, 08:00 PM';
                        });
                      },
                    ),
                    _scheduleChip(
                      label: '⏰ Every 6h (4x Daily)',
                      selected: ctrl['reminderTimes']?.text.contains('12:00 PM') == true,
                      onTap: () {
                        setState(() {
                          ctrl['period']?.text = '4 Times Daily (Every 6h)';
                          ctrl['reminderTimes']?.text = '08:00 AM, 12:00 PM, 04:00 PM, 08:00 PM';
                        });
                      },
                    ),
                    _scheduleChip(
                      label: '🌙 Bedtime Only (09:00 PM)',
                      selected: ctrl['reminderTimes']?.text == '09:00 PM',
                      onTap: () {
                        setState(() {
                          ctrl['period']?.text = 'Once Daily (Night / Bedtime)';
                          ctrl['reminderTimes']?.text = '09:00 PM';
                        });
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Meal Timing & Treatment Duration Presets
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Meal Relation:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: ['After Meals', 'Before Meals', 'With Food', 'Anytime'].map((m) {
                              final isSel = ctrl['mealTiming']?.text == m;
                              return ChoiceChip(
                                label: Text(m, style: TextStyle(fontSize: 10, fontWeight: isSel ? FontWeight.w700 : FontWeight.normal, color: isSel ? Colors.white : AppColors.textDark)),
                                selected: isSel,
                                selectedColor: AppColors.primary,
                                backgroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onSelected: (_) {
                                  setState(() => ctrl['mealTiming']?.text = m);
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Duration Quick Select:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: ['3', '5', '7', '10', '14', '30'].map((d) {
                              final isSel = ctrl['duration']?.text == d;
                              return ChoiceChip(
                                label: Text('$d Days', style: TextStyle(fontSize: 10, fontWeight: isSel ? FontWeight.w700 : FontWeight.normal, color: isSel ? Colors.white : AppColors.textDark)),
                                selected: isSel,
                                selectedColor: AppColors.primary,
                                backgroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onSelected: (_) {
                                  setState(() => ctrl['duration']?.text = d);
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Specific Reminder Times Input
                TextFormField(
                  controller: ctrl['reminderTimes'],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Alarm Reminder Times (Editable)',
                    hintText: 'e.g. 08:00 AM, 08:00 PM',
                    prefixIcon: const Icon(Icons.access_time, color: AppColors.primary, size: 18),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 4. Instructions / Posology
          TextFormField(
            controller: ctrl['instructions'],
            decoration: InputDecoration(
              labelText: 'Instructions / Posology Note',
              hintText: 'e.g. Take with a full glass of water after food',
              prefixIcon: const Icon(Icons.info_outline, color: AppColors.accent, size: 18),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),

          const SizedBox(height: 10),

          // ─── Live Patient Reminder Sync Preview Badge ────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active, size: 16, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Direct Patient Sync: ${medName.isNotEmpty ? medName : 'Medication'} • $reminderTimes • $duration Days ($meal)',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF1E40AF), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scheduleChip({required String label, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AppColors.primary : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B))),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _vitalField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String unit,
    required IconData icon,
    bool isNumeric = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: unit,
        prefixIcon: Icon(icon, size: 16, color: AppColors.accent),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      ),
    );
  }

  Widget _buildLabRequestTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Order laboratory analyses first if confirmation is needed before prescribing medications. The patient will be notified to visit a lab and upload results for your review.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF1E40AF), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Diagnostic Tests Selection Card
          _sectionCard(
            title: 'Diagnostic Lab Tests (Select all required)',
            icon: Icons.science_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _commonLabTests.map((test) {
                    final isSelected = _selectedLabTests.contains(test);
                    return FilterChip(
                      selected: isSelected,
                      label: Text(test, style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : AppColors.textDark,
                      )),
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.grey[100],
                      checkmarkColor: Colors.white,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedLabTests.add(test);
                          } else {
                            _selectedLabTests.remove(test);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _customLabTestCtrl,
                  decoration: InputDecoration(
                    labelText: 'Add Custom Lab Test / Medical Imaging',
                    hintText: 'e.g. Serum Potassium, Thyroid Panel TSH, ECG...',
                    prefixIcon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Urgency Level
          _sectionCard(
            title: 'Test Urgency Level',
            icon: Icons.timer_outlined,
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Routine')),
                    selected: _labUrgency == 'routine',
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(color: _labUrgency == 'routine' ? Colors.white : AppColors.textDark, fontWeight: FontWeight.w600),
                    onSelected: (v) => setState(() => _labUrgency = 'routine'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Urgent (<24h)')),
                    selected: _labUrgency == 'urgent',
                    selectedColor: Colors.orange[700],
                    labelStyle: TextStyle(color: _labUrgency == 'urgent' ? Colors.white : AppColors.textDark, fontWeight: FontWeight.w600),
                    onSelected: (v) => setState(() => _labUrgency = 'urgent'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Emergency / STAT')),
                    selected: _labUrgency == 'stat',
                    selectedColor: Colors.red[700],
                    labelStyle: TextStyle(color: _labUrgency == 'stat' ? Colors.white : AppColors.textDark, fontWeight: FontWeight.w600),
                    onSelected: (v) => setState(() => _labUrgency = 'stat'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Instructions for Patient & Laboratory
          _sectionCard(
            title: 'Instructions for Patient & Laboratory',
            icon: Icons.edit_note_outlined,
            child: TextFormField(
              controller: _labInstructionsCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. Fasting required for 8 hours prior to blood draw. Please submit results promptly.',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSubmittingLab ? null : _submitLabAnalysisRequest,
              icon: _isSubmittingLab
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded, color: Colors.white),
              label: const Text(
                'Send Lab Request to Patient (Hold Rx)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.science_outlined, color: Color(0xFF0F766E)),
              label: const Text('Order Lab Tests', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F766E))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: PharmaButton(
              label: 'Issue Prescription (Rx)',
              icon: Icons.check_circle_outline,
              isLoading: _isSaving,
              onPressed: _saveConsultationAndPrescription,
            ),
          ),
        ],
      ),
    );
  }
}
