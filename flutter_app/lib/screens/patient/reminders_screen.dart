import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});
  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _reminders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/reminders');
      final list = res.data['data'] as List? ?? [];
      setState(() {
        _reminders = list.cast<Map<String, dynamic>>();
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleReminder(Map<String, dynamic> r, bool val) async {
    try {
      await _api.patch('/reminders/${r['id']}', data: {'isActive': val});
      setState(() {
        r['isActive'] = val;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(val ? 'Reminder activated for ${r['medicationName']}' : 'Reminder paused for ${r['medicationName']}'),
          backgroundColor: val ? AppColors.primary : Colors.grey[700],
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      _loadReminders();
    }
  }

  Future<void> _deleteReminder(String id, String medName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Reminder?'),
        content: Text('Are you sure you want to remove the reminder for $medName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _api.delete('/reminders/$id');
        _loadReminders();
      } catch (_) {}
    }
  }

  void _showAddOrEditSheet({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final medCtrl = TextEditingController(text: existing?['medicationName'] ?? '');
    final dosageCtrl = TextEditingController(text: existing?['dosage'] ?? '');
    final freqCtrl = TextEditingController(text: existing?['frequency'] ?? '');
    String reminderTimeStr = existing?['reminderTime'] ?? '08:00 AM';

    final quickFrequencies = [
      'Once Daily (Morning)',
      'Twice Daily (Morning & Night)',
      '3 Times Daily (Every 8h)',
      'Every 6 Hours (4x Daily)',
      'Before Bedtime',
      'As Needed (PRN)',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.alarm_add, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isEdit ? 'Edit Medication Reminder' : 'Add Medication Reminder',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                PharmaField(
                  label: 'Medication Name *',
                  hint: 'e.g. Amoxicillin 500mg, Paracetamol',
                  prefixIcon: Icons.medication_outlined,
                  controller: medCtrl,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: PharmaField(
                        label: 'Dosage',
                        hint: 'e.g. 1 tablet / 10ml',
                        prefixIcon: Icons.colorize_outlined,
                        controller: dosageCtrl,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PharmaField(
                        label: 'Frequency',
                        hint: 'e.g. 3 times daily',
                        prefixIcon: Icons.repeat,
                        controller: freqCtrl,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('Quick Frequencies:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: quickFrequencies.map((f) {
                    return ActionChip(
                      label: Text(f, style: const TextStyle(fontSize: 10)),
                      backgroundColor: AppColors.lightGreen.withOpacity(0.5),
                      labelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      onPressed: () {
                        setModal(() {
                          freqCtrl.text = f;
                          if (f.contains('3 Times')) reminderTimeStr = '08:00 AM, 01:00 PM, 08:00 PM';
                          if (f.contains('Twice')) reminderTimeStr = '08:00 AM, 08:00 PM';
                          if (f.contains('Once')) reminderTimeStr = '08:00 AM';
                          if (f.contains('Bedtime')) reminderTimeStr = '09:00 PM';
                          if (f.contains('6 Hours')) reminderTimeStr = '08:00 AM, 12:00 PM, 04:00 PM, 08:00 PM';
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text('Scheduled Reminder Times *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.fieldBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                reminderTimeStr,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('Pick Time'),
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.now(),
                        );
                        if (t != null) {
                          final formatted = t.format(ctx);
                          setModal(() => reminderTimeStr = formatted);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                PharmaButton(
                  label: isEdit ? 'Update Reminder' : 'Save Reminder',
                  icon: Icons.check,
                  onPressed: () async {
                    if (medCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter medication name')),
                      );
                      return;
                    }

                    final payload = {
                      'medicationName': medCtrl.text.trim(),
                      'dosage': dosageCtrl.text.trim().isNotEmpty ? dosageCtrl.text.trim() : '1 dose',
                      'frequency': freqCtrl.text.trim().isNotEmpty ? freqCtrl.text.trim() : 'Daily',
                      'reminderTime': reminderTimeStr,
                    };

                    if (isEdit) {
                      await _api.patch('/reminders/${existing['id']}', data: payload);
                    } else {
                      await _api.post('/reminders', data: payload);
                    }

                    Navigator.pop(ctx);
                    _loadReminders();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _reminders.where((r) => r['isActive'] == true).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Medication Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReminders,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _showAddOrEditSheet(),
        icon: const Icon(Icons.add_alarm, color: Colors.white),
        label: const Text('Add Reminder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                _buildHeaderBanner(activeCount),
                Expanded(
                  child: _reminders.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                          itemCount: _reminders.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _buildReminderCard(_reminders[i]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderBanner(int activeCount) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D5C3A), AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.alarm_on, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$activeCount Active Pill Reminder${activeCount != 1 ? 's' : ''}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Auto-synced from your doctor consultations & prescriptions.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
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
            child: const Icon(Icons.alarm_outlined, size: 50, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text('No Medication Reminders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Reminders are created automatically when your doctor issues a prescription, or you can add custom pill alarms below.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGrey, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            icon: const Icon(Icons.add),
            label: const Text('Add First Reminder'),
            onPressed: () => _showAddOrEditSheet(),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(Map<String, dynamic> r) {
    final bool isActive = r['isActive'] ?? true;
    final String medName = r['medicationName'] ?? 'Medication';
    final String dosage = r['dosage'] ?? '1 dose';
    final String freq = r['frequency'] ?? 'Daily';
    final String reminderTimes = r['reminderTime'] ?? '08:00 AM';
    final timesList = reminderTimes.split(',').map((t) => t.trim()).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? AppColors.primary.withOpacity(0.3) : const Color(0xFFE5E7EB),
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.lightGreen : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    Icons.medication,
                    color: isActive ? AppColors.primary : Colors.grey,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isActive ? Colors.black87 : Colors.grey[600],
                        decoration: isActive ? null : TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dosage • $freq',
                      style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isActive,
                activeColor: AppColors.primary,
                onChanged: (val) => _toggleReminder(r, val),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Time pills
          Row(
            children: [
              const Text('Alarm Times: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: timesList.map((time) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFFE8F5E9) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isActive ? AppColors.lightGreen : const Color(0xFFE0E0E0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.alarm, size: 12, color: isActive ? AppColors.primary : Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isActive ? AppColors.primary : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Actions: Edit & Delete
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
                label: const Text('Edit', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                onPressed: () => _showAddOrEditSheet(existing: r),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                label: const Text('Delete', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600)),
                onPressed: () => _deleteReminder(r['id'], medName),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
