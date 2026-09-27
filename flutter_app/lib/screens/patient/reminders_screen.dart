import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
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

  static const List<Map<String, dynamic>> soundThemes = [
    {
      'id': 'gentle_chime',
      'title': 'Gentle Chime',
      'subtitle': 'Soft calming harmonic chime',
      'icon': Icons.notifications_active_outlined,
      'color': Color(0xFF10B981),
    },
    {
      'id': 'pill_box_bell',
      'title': 'Pill Box Bell',
      'subtitle': 'Clear acoustic reminder bell',
      'icon': Icons.alarm_rounded,
      'color': Color(0xFF0284C7),
    },
    {
      'id': 'clinical_alert',
      'title': 'Clinical Alert',
      'subtitle': 'Crisp medical alert tone',
      'icon': Icons.local_hospital_rounded,
      'color': Color(0xFF6366F1),
    },
    {
      'id': 'morning_zen',
      'title': 'Morning Zen',
      'subtitle': 'Tranquil peaceful nature chime',
      'icon': Icons.spa_rounded,
      'color': Color(0xFF0D9488),
    },
    {
      'id': 'urgent_pulse',
      'title': 'Urgent Pulse',
      'subtitle': 'Distinct beep for critical drugs',
      'icon': Icons.bolt_rounded,
      'color': Color(0xFFEA580C),
    },
    {
      'id': 'soft_marimba',
      'title': 'Soft Marimba',
      'subtitle': 'Warm melodic reminder notes',
      'icon': Icons.music_note_rounded,
      'color': Color(0xFF8B5CF6),
    },
  ];

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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Reminder for $medName removed.'), backgroundColor: Colors.black87),
          );
        }
      } catch (_) {}
    }
  }

  void _showAddOrEditSheet({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final medCtrl = TextEditingController(text: existing?['medicationName'] ?? '');
    final dosageCtrl = TextEditingController(text: existing?['dosage'] ?? '');
    final freqCtrl = TextEditingController(text: existing?['frequency'] ?? '');
    final notesCtrl = TextEditingController(text: existing?['notes'] ?? '');
    String reminderTimeStr = existing?['reminderTime'] ?? '08:00 AM';
    String selectedSound = existing?['sound'] ?? 'gentle_chime';
    bool isSubmitting = false;

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
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit ? 'Edit Medication Reminder' : 'Add Medication Reminder',
                            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Personalized alerts & sound notifications',
                            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textGrey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // 1. Medication Info
                PharmaField(
                  label: 'Medication Name *',
                  hint: 'e.g. Amoxicillin 500mg, Paracetamol, Coartem',
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
                      label: Text(f, style: const TextStyle(fontSize: 10.5)),
                      backgroundColor: AppColors.lightGreen.withValues(alpha: 0.5),
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
                const SizedBox(height: 16),

                // 2. Schedule Times
                const Text('Scheduled Alarm Time *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
                      icon: const Icon(Icons.edit, size: 14, color: Colors.white),
                      label: const Text('Pick Time', style: TextStyle(color: Colors.white, fontSize: 12)),
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
                const SizedBox(height: 18),

                // 3. Personalized Notification Sound Theme
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Personalized Notification Sound', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    TextButton.icon(
                      icon: const Icon(Icons.volume_up_rounded, size: 14, color: AppColors.primary),
                      label: const Text('Test Sound', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700)),
                      onPressed: () async {
                        final chosen = soundThemes.firstWhere((s) => s['id'] == selectedSound, orElse: () => soundThemes[0]);
                        await NotificationService().show(
                          id: 777,
                          title: '💊 Pill Reminder (${chosen['title']})',
                          body: 'Time to take ${medCtrl.text.trim().isNotEmpty ? medCtrl.text.trim() : "your medication"} (${dosageCtrl.text.trim().isNotEmpty ? dosageCtrl.text.trim() : "1 dose"})',
                          payload: 'reminder_test',
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('🔔 Notification sound "${chosen['title']}" played!'),
                              backgroundColor: AppColors.primary,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: soundThemes.map((s) {
                    final isSelected = selectedSound == s['id'];
                    final color = s['color'] as Color;
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setModal(() => selectedSound = s['id']),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? color.withValues(alpha: 0.12) : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? color : const Color(0xFFE5E7EB),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(s['icon'] as IconData, size: 16, color: isSelected ? color : Colors.grey[600]),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s['title'] as String,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? color : Colors.black87,
                                  ),
                                ),
                                Text(
                                  s['subtitle'] as String,
                                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                PharmaField(
                  label: 'Notes (Optional)',
                  hint: 'e.g. Take with a glass of water after food',
                  prefixIcon: Icons.notes_rounded,
                  controller: notesCtrl,
                ),
                const SizedBox(height: 20),

                // Submit Button
                PharmaButton(
                  label: isEdit ? 'Update Reminder' : 'Save Reminder',
                  icon: Icons.check,
                  isLoading: isSubmitting,
                  onPressed: () async {
                    if (medCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter medication name')),
                      );
                      return;
                    }

                    setModal(() => isSubmitting = true);

                    final payload = {
                      'medicationName': medCtrl.text.trim(),
                      'dosage': dosageCtrl.text.trim().isNotEmpty ? dosageCtrl.text.trim() : '1 dose',
                      'frequency': freqCtrl.text.trim().isNotEmpty ? freqCtrl.text.trim() : 'Daily',
                      'reminderTime': reminderTimeStr,
                      'sound': selectedSound,
                      'notes': notesCtrl.text.trim(),
                    };

                    try {
                      if (isEdit) {
                        await _api.patch('/reminders/${existing['id']}', data: payload);
                      } else {
                        await _api.post('/reminders', data: payload);
                      }

                      // Schedule local notification on device
                      await NotificationService().show(
                        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                        title: 'Reminder Created 💊',
                        body: 'Scheduled alarm for ${payload['medicationName']} at $reminderTimeStr',
                      );

                      if (mounted) {
                        Navigator.pop(ctx);
                        _loadReminders();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isEdit ? 'Reminder updated successfully!' : '✅ Reminder for ${payload['medicationName']} saved!'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        setModal(() => isSubmitting = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not save reminder: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
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
        title: Text('Medication Reminders', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
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
        label: Text('Add Reminder', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w700)),
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
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.alarm_on, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$activeCount Active Pill Reminder${activeCount != 1 ? 's' : ''}',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  'Custom sounds & auto-sync from doctor prescriptions.',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 11),
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: AppColors.lightGreen, shape: BoxShape.circle),
              child: const Icon(Icons.alarm_outlined, size: 50, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text('No Medication Reminders', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Set daily pill alarms with personalized notification tones to never miss a dose.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(color: AppColors.textGrey, fontSize: 13),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Medication Reminder'),
              onPressed: () => _showAddOrEditSheet(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(Map<String, dynamic> r) {
    final bool isActive = r['isActive'] ?? true;
    final String medName = r['medicationName'] ?? 'Medication';
    final String dosage = r['dosage'] ?? '1 dose';
    final String freq = r['frequency'] ?? 'Daily';
    final String reminderTimes = r['reminderTime'] ?? '08:00 AM';
    final String soundId = r['sound'] ?? 'gentle_chime';
    final soundTheme = soundThemes.firstWhere((s) => s['id'] == soundId, orElse: () => soundThemes[0]);
    final timesList = reminderTimes.split(',').map((t) => t.trim()).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? AppColors.primary.withValues(alpha: 0.3) : const Color(0xFFE5E7EB),
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
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
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isActive ? Colors.black87 : Colors.grey[600],
                        decoration: isActive ? null : TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dosage • $freq',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textGrey),
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

          // Alarm Times & Tone Badge
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ...timesList.map((time) {
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
                    }),
                    // Sound Tone Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (soundTheme['color'] as Color).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(soundTheme['icon'] as IconData, size: 12, color: soundTheme['color'] as Color),
                          const SizedBox(width: 4),
                          Text(
                            soundTheme['title'] as String,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: soundTheme['color'] as Color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
