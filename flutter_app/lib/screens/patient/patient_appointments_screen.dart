import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';
import 'book_appointment_screen.dart';

class PatientAppointmentsScreen extends StatefulWidget {
  const PatientAppointmentsScreen({super.key});
  @override
  State<PatientAppointmentsScreen> createState() => _PatientAppointmentsScreenState();
}

class _PatientAppointmentsScreenState extends State<PatientAppointmentsScreen> {
  final _api = ApiService();
  final _socket = SocketService();
  List<Map<String, dynamic>> _appointments = [];
  bool _loading = true;
  String _activeFilter = 'all'; // all, pending, confirmed, completed, cancelled

  @override
  void initState() {
    super.initState();
    _loadAppointments();
    _socket.onAppointmentNew(_onSocketApt);
    _socket.onAppointmentUpdated(_onSocketApt);
  }

  void _onSocketApt(dynamic data) {
    if (mounted) {
      _loadAppointments();
    }
  }

  @override
  void dispose() {
    _socket.removeListener('appointment:new', _onSocketApt);
    _socket.removeListener('appointment:updated', _onSocketApt);
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/appointments');
      final List data = res.data['data'] ?? [];
      setState(() => _appointments = data.cast<Map<String, dynamic>>());
    } catch (_) {} finally {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredAppointments {
    if (_activeFilter == 'all') return _appointments;
    return _appointments.where((a) => (a['status'] ?? '').toString().toLowerCase() == _activeFilter).toList();
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
          'Are you sure you want to cancel your appointment with Dr. ${apt['doctor']?['name'] ?? 'Doctor'}?',
          style: const TextStyle(fontSize: 13, color: AppColors.textDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Appointment', style: TextStyle(color: AppColors.textGrey)),
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
      await _api.delete('/appointments/${apt['id']}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment cancelled.'), backgroundColor: AppColors.primary),
      );
      _loadAppointments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to cancel appointment.'), backgroundColor: AppColors.error),
      );
    }
  }

  // ─── Reschedule Appointment ───────────────────────────────────────────────────
  Future<void> _rescheduleAppointment(Map<String, dynamic> apt) async {
    DateTime? newDate;
    String newTime = '10:00 AM';
    final timeSlots = ['09:00 AM', '10:00 AM', '11:00 AM', '02:00 PM', '03:00 PM', '04:00 PM'];
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
              const SizedBox(height: 6),
              Text(
                'Doctor: Dr. ${apt['doctor']?['name'] ?? 'Doctor'} (${apt['doctor']?['doctorProfile']?['specialty'] ?? ''})',
                style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
              const Divider(height: 24),
              const Text('1. Pick New Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
              const SizedBox(height: 16),
              const Text('2. Pick New Time Slot', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
                      const SnackBar(content: Text('Appointment rescheduled successfully!'), backgroundColor: AppColors.primary),
                    );
                    _loadAppointments();
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
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  // ─── Appointment Card ─────────────────────────────────────────────────────────
  Widget _buildAppointmentCard(Map<String, dynamic> apt) {
    final dt = DateTime.tryParse(apt['appointmentDate'] ?? '');
    final doc = apt['doctor'] as Map? ?? {};
    final profile = doc['doctorProfile'] as Map? ?? {};
    final status = (apt['status'] ?? 'pending').toString().toLowerCase();
    final isUpcoming = status == 'pending' || status == 'confirmed';

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
                (doc['name'] as String? ?? 'D')[0].toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Dr. ${doc['name'] ?? 'Doctor'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(profile['specialty'] ?? 'General Practitioner', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            ]),
          ]),
          _buildStatusBadge(status),
        ]),
        const Divider(height: 20, color: Color(0xFFF0F0F0)),
        if (apt['hospital'] != null || profile['hospital'] != null) ...[
          Row(children: [
            const Icon(Icons.local_hospital_outlined, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(apt['hospital'] ?? profile['hospital'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 6),
        ],
        Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textGrey),
          const SizedBox(width: 6),
          Text(
            dt != null ? '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}' : 'Date not set',
            style: const TextStyle(fontSize: 12, color: AppColors.textDark),
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
        if (apt['notes'] != null && apt['notes'].toString().isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(6)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.notes, size: 13, color: AppColors.textGrey),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Notes: ${apt['notes']}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ),
            ]),
          ),
        ],
        if (isUpcoming) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _rescheduleAppointment(apt),
                icon: const Icon(Icons.edit_calendar_outlined, size: 14, color: AppColors.primary),
                label: const Text('Reschedule', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _cancelAppointment(apt),
                icon: const Icon(Icons.cancel_outlined, size: 14, color: AppColors.error),
                label: const Text('Cancel', style: TextStyle(fontSize: 12, color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAppointments;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Appointments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadAppointments,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Book New', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () async {
          final booked = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const BookAppointmentScreen()),
          );
          if (booked == true) _loadAppointments();
        },
      ),
      body: Column(children: [
        // ── Filter Pills ───────────────────────────────────────────────────────
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _filterChip('all', 'All (${_appointments.length})'),
              _filterChip('pending', 'Pending'),
              _filterChip('confirmed', 'Confirmed'),
              _filterChip('completed', 'Completed'),
              _filterChip('cancelled', 'Cancelled'),
            ],
          ),
        ),

        // ── List ───────────────────────────────────────────────────────────────
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
                              ? 'You have no appointments yet.'
                              : 'No $_activeFilter appointments found.',
                          style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Book an Appointment'),
                          onPressed: () async {
                            final booked = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(builder: (_) => const BookAppointmentScreen()),
                            );
                            if (booked == true) _loadAppointments();
                          },
                        ),
                      ]),
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _loadAppointments,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
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
