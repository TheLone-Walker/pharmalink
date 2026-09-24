import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';
import 'set_availability_screen.dart';
import 'write_prescription_screen.dart';

class DoctorAppointmentsScreen extends StatefulWidget {
  const DoctorAppointmentsScreen({super.key});
  @override
  State<DoctorAppointmentsScreen> createState() => _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen> {
  final _api = ApiService();
  final _socket = SocketService();
  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _blockedTimes = [];
  bool _loading = true;
  String _activeFilter = 'all'; // all, pending, confirmed, completed, cancelled

  @override
  void initState() {
    super.initState();
    _loadData();
    _socket.onAppointmentNew(_onSocketApt);
    _socket.onAppointmentUpdated(_onSocketApt);
  }

  void _onSocketApt(dynamic data) {
    if (mounted) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _socket.removeListener('appointment:new', _onSocketApt);
    _socket.removeListener('appointment:updated', _onSocketApt);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.get('/appointments'),
        _api.get('/appointments/blocked-times'),
      ]);
      final List aptData = results[0].data['data'] ?? [];
      final List blockedData = results[1].data['data'] ?? [];
      setState(() {
        _appointments = aptData.cast<Map<String, dynamic>>();
        _blockedTimes = blockedData.cast<Map<String, dynamic>>();
      });
    } catch (_) {} finally {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredAppointments {
    if (_activeFilter == 'all') return _appointments;
    return _appointments.where((a) => (a['status'] ?? '').toString().toLowerCase() == _activeFilter).toList();
  }

  // ─── Confirm Appointment ──────────────────────────────────────────────────────
  Future<void> _confirmAppointment(Map<String, dynamic> apt) async {
    try {
      await _api.patch('/appointments/${apt['id']}/status', data: {'status': 'confirmed'});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment confirmed! Patient notified.'), backgroundColor: AppColors.primary),
      );
      _loadData();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to confirm appointment.'), backgroundColor: AppColors.error),
      );
    }
  }

  // ─── Cancel Appointment ───────────────────────────────────────────────────────
  Future<void> _cancelAppointment(Map<String, dynamic> apt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: const [
          Icon(Icons.cancel_outlined, color: AppColors.error),
          SizedBox(width: 8),
          Text('Cancel Appointment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          'Cancel appointment with ${apt['patient']?['name'] ?? 'Patient'}?',
          style: const TextStyle(fontSize: 13, color: AppColors.textDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back', style: TextStyle(color: AppColors.textGrey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _api.patch('/appointments/${apt['id']}/status', data: {'status': 'cancelled'});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment cancelled.'), backgroundColor: AppColors.primary),
      );
      _loadData();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to cancel appointment.'), backgroundColor: AppColors.error),
      );
    }
  }

  // ─── Reschedule Appointment ───────────────────────────────────────────────────
  Future<void> _rescheduleAppointment(Map<String, dynamic> apt) async {
    DateTime? newDate;
    String newTime = '10:00 AM';
    final timeSlots = ['08:30 AM', '09:00 AM', '10:00 AM', '11:00 AM', '02:00 PM', '03:00 PM', '04:00 PM', '05:00 PM'];
    bool rescheduling = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: const [
                    Icon(Icons.edit_calendar_rounded, color: AppColors.primary, size: 22),
                    SizedBox(width: 8),
                    Text('Reschedule Appointment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ]),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Patient: ${apt['patient']?['name'] ?? 'Patient'}',
                style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
              const Divider(height: 20),
              const Text('Select New Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (picked != null) {
                    setModalState(() => newDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.fieldBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: newDate != null ? AppColors.primary : const Color(0xFFEEEEEE)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text(
                      newDate == null ? 'Tap to choose a new date' : '${newDate!.day}/${newDate!.month}/${newDate!.year}',
                      style: TextStyle(fontSize: 13, color: newDate == null ? Colors.black38 : AppColors.textDark, fontWeight: FontWeight.w500),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Select New Time Slot', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: timeSlots.map((t) => GestureDetector(
                  onTap: () => setModalState(() => newTime = t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: newTime == t ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: newTime == t ? AppColors.primary : const Color(0xFFEEEEEE)),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(fontSize: 12, color: newTime == t ? Colors.white : AppColors.textDark, fontWeight: FontWeight.w500),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 24),
              PharmaButton(
                label: 'Confirm Reschedule',
                isLoading: rescheduling,
                onPressed: () async {
                  if (newDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a new date first'), backgroundColor: AppColors.error),
                    );
                    return;
                  }
                  setModalState(() => rescheduling = true);
                  try {
                    final parts = newTime.replaceAll(' AM', '').replaceAll(' PM', '').split(':');
                    int hour = int.parse(parts[0]);
                    final isPm = newTime.contains('PM');
                    if (isPm && hour != 12) hour += 12;
                    if (!isPm && hour == 12) hour = 0;

                    final fullDate = DateTime(newDate!.year, newDate!.month, newDate!.day, hour, 0);

                    await _api.patch('/appointments/${apt['id']}/reschedule', data: {
                      'appointmentDate': fullDate.toIso8601String(),
                    });

                    if (!mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Appointment rescheduled! Patient notified.'), backgroundColor: AppColors.primary),
                    );
                    _loadData();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reschedule failed: ${e.toString().substring(0, 60)}'), backgroundColor: AppColors.error),
                    );
                  } finally {
                    setModalState(() => rescheduling = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Block Personal Time Modal ────────────────────────────────────────────────
  Future<void> _showBlockPersonalTimeDialog() async {
    DateTime? blockDate = DateTime.now();
    TimeOfDay startTime = const TimeOfDay(hour: 14, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 16, minute: 0);
    final reasonCtrl = TextEditingController(text: 'Personal / Surgery');
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: const [
            Icon(Icons.block_outlined, color: Colors.orange, size: 22),
            SizedBox(width: 8),
            Text('Block Personal Time', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Patients will not be able to book appointments during this blocked time.',
                  style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                const SizedBox(height: 16),
                const Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: blockDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (d != null) setDialogState(() => blockDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.fieldBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('${blockDate!.day}/${blockDate!.month}/${blockDate!.year}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('From', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () async {
                          final t = await showTimePicker(context: context, initialTime: startTime);
                          if (t != null) setDialogState(() => startTime = t);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.fieldBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFEEEEEE))),
                          child: Text(startTime.format(context), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('To', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () async {
                          final t = await showTimePicker(context: context, initialTime: endTime);
                          if (t != null) setDialogState(() => endTime = t);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.fieldBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFEEEEEE))),
                          child: Text(endTime.format(context), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ]),
                  ),
                ]),
                const SizedBox(height: 14),
                const Text('Reason', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. Surgery, Training, Personal',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              onPressed: saving ? null : () async {
                setDialogState(() => saving = true);
                try {
                  final start = DateTime(blockDate!.year, blockDate!.month, blockDate!.day, startTime.hour, startTime.minute);
                  final end = DateTime(blockDate!.year, blockDate!.month, blockDate!.day, endTime.hour, endTime.minute);

                  await _api.post('/appointments/block-time', data: {
                    'startDate': start.toIso8601String(),
                    'endDate': end.toIso8601String(),
                    'reason': reasonCtrl.text.trim(),
                  });

                  if (!mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Personal time blocked!'), backgroundColor: AppColors.primary),
                  );
                  _loadData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to block time.'), backgroundColor: AppColors.error),
                  );
                } finally {
                  setDialogState(() => saving = false);
                }
              },
              child: saving
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Block Time'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Unblock Personal Time ───────────────────────────────────────────────────
  Future<void> _unblockTime(String id) async {
    try {
      await _api.delete('/appointments/blocked-times/$id');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Time unblocked successfully.'), backgroundColor: AppColors.primary),
      );
      _loadData();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to unblock time.'), backgroundColor: AppColors.error),
      );
    }
  }

  // ─── Status Badge ─────────────────────────────────────────────────────────────
  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label = status.toUpperCase();

    switch (status.toLowerCase()) {
      case 'confirmed':
        bg = AppColors.lightGreen;
        fg = AppColors.primary;
        break;
      case 'completed':
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1976D2);
        break;
      case 'cancelled':
        bg = const Color(0xFFFFEBEE);
        fg = AppColors.error;
        break;
      case 'pending':
      default:
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFF57F17);
        label = 'PENDING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  // ─── Appointment Card ─────────────────────────────────────────────────────────
  Widget _buildAppointmentCard(Map<String, dynamic> apt) {
    final dt = DateTime.tryParse(apt['appointmentDate'] ?? '');
    final pt = apt['patient'] as Map? ?? {};
    final profile = pt['patientProfile'] as Map? ?? {};
    final status = (apt['status'] ?? 'pending').toString().toLowerCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: Text(
                (pt['name'] as String? ?? 'P')[0].toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pt['name'] ?? 'Patient', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              if (pt['phone'] != null)
                Text(pt['phone'], style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
            ]),
          ]),
          _buildStatusBadge(status),
        ]),
        const Divider(height: 20, color: Color(0xFFF0F0F0)),
        Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textGrey),
          const SizedBox(width: 6),
          Text(
            dt != null ? '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}' : 'Date not set',
            style: const TextStyle(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 14),
          Icon(
            apt['type'] == 'telemedicine' ? Icons.video_call_outlined : Icons.person_outline,
            size: 15,
            color: AppColors.accent,
          ),
          const SizedBox(width: 4),
          Text(
            apt['type'] == 'telemedicine' ? 'Telemedicine' : 'In Person',
            style: const TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w500),
          ),
        ]),
        if (profile['bloodType'] != null || profile['allergies'] != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            if (profile['bloodType'] != null)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFEEEEEE), borderRadius: BorderRadius.circular(4)),
                child: Text('Blood: ${profile['bloodType']}', style: const TextStyle(fontSize: 10, color: AppColors.textDark)),
              ),
            if (profile['allergies'] != null && profile['allergies'] != 'None')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(4)),
                child: Text('Allergies: ${profile['allergies']}', style: const TextStyle(fontSize: 10, color: AppColors.error)),
              ),
          ]),
        ],
        if (apt['notes'] != null && apt['notes'].toString().isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(6)),
            child: Text('Notes: ${apt['notes']}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ),
        ],
        const SizedBox(height: 12),
        // ── Actions ─────────────────────────────────────────────────────────────
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (status == 'pending')
            ElevatedButton.icon(
              onPressed: () => _confirmAppointment(apt),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.check, size: 14),
              label: const Text('Confirm', style: TextStyle(fontSize: 12)),
            ),
          if (status != 'cancelled' && status != 'completed') ...[
            OutlinedButton.icon(
              onPressed: () => _rescheduleAppointment(apt),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.edit_calendar_outlined, size: 14, color: AppColors.primary),
              label: const Text('Reschedule', style: TextStyle(fontSize: 12, color: AppColors.primary)),
            ),
            OutlinedButton.icon(
              onPressed: () => _cancelAppointment(apt),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.close, size: 14, color: AppColors.error),
              label: const Text('Cancel', style: TextStyle(fontSize: 12, color: AppColors.error)),
            ),
          ],
          if (status == 'confirmed' || status == 'pending')
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WritePrescriptionScreen(
                    patientId: pt['id'],
                    patientName: pt['name'],
                    appointmentId: apt['id'],
                  ),
                ),
              ).then((_) => _loadData()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.medical_services_outlined, size: 14),
              label: const Text('Consult & Prescribe', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAppointments;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.block_outlined),
            tooltip: 'Block Personal Time',
            onPressed: _showBlockPersonalTimeDialog,
          ),
          IconButton(
            icon: const Icon(Icons.settings_suggest_outlined),
            tooltip: 'Set Working Hours',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SetAvailabilityScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(children: [
        // ── Doctor Blocked Times Banner (if any) ───────────────────────────────
        if (_blockedTimes.isNotEmpty)
          Container(
            color: const Color(0xFFFFF3E0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              const Icon(Icons.event_busy, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_blockedTimes.length} personal time slot(s) blocked',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFE65100)),
                ),
              ),
              TextButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (ctx) => Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('My Blocked Personal Times', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                        ]),
                        const Divider(),
                        ..._blockedTimes.map((b) {
                          final start = DateTime.tryParse(b['startDate'] ?? '');
                          final end = DateTime.tryParse(b['endDate'] ?? '');
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.block, color: Colors.orange),
                            title: Text(b['reason'] ?? 'Personal Time', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            subtitle: Text(
                              start != null && end != null
                                ? '${start.day}/${start.month} ${start.hour}:${start.minute.toString().padLeft(2, '0')} - ${end.hour}:${end.minute.toString().padLeft(2, '0')}'
                                : '',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _unblockTime(b['id']);
                              },
                            ),
                          );
                        }),
                      ]),
                    ),
                  );
                },
                child: const Text('Manage', style: TextStyle(fontSize: 12, color: Color(0xFFE65100), fontWeight: FontWeight.bold)),
              ),
            ]),
          ),

        // ── Filter Chips ───────────────────────────────────────────────────────
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _filterChip('all', 'All (${_appointments.length})'),
              _filterChip('pending', 'Pending (${_appointments.where((a) => a['status'] == 'pending').length})'),
              _filterChip('confirmed', 'Confirmed'),
              _filterChip('completed', 'Completed'),
              _filterChip('cancelled', 'Cancelled'),
            ],
          ),
        ),

        // ── Appointments List ──────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : filtered.isEmpty
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          _activeFilter == 'all'
                              ? 'No appointments found.'
                              : 'No $_activeFilter appointments.',
                          style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                        ),
                      ]),
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _loadData,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _buildAppointmentCard(filtered[i]),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _filterChip(String key, String label) {
    final active = _activeFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = key),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : const Color(0xFFEEEEEE),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppColors.textDark,
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
