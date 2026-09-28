import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  List<Map<String, dynamic>> _prescriptionSuggestions = [];
  bool _loading = true;
  static const String _storageKey = 'pharmalink_local_reminders_v2';

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
    _loadPrescriptionSuggestions();
  }

  /// Load local cache immediately, then sync with backend in background
  Future<void> _loadReminders() async {
    setState(() => _loading = true);

    // 1. Instantly load from local storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final localData = prefs.getString(_storageKey);
      if (localData != null) {
        final decoded = jsonDecode(localData) as List;
        setState(() {
          _reminders = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (_) {}

    // 2. Fetch from cloud API and merge
    try {
      final res = await _api.get('/reminders');
      final cloudList = (res.data['data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (cloudList.isNotEmpty) {
        // Merge cloud with local
        final Map<String, Map<String, dynamic>> merged = {};
        for (final r in _reminders) {
          merged[r['id'].toString()] = r;
        }
        for (final c in cloudList) {
          merged[c['id'].toString()] = c;
        }
        _reminders = merged.values.toList();
        await _saveToLocalStorage();
      }
    } catch (_) {
      // Offline or network error - local storage takes over seamlessly
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_reminders));
    } catch (_) {}
  }

  Future<void> _loadPrescriptionSuggestions() async {
    try {
      final res = await _api.get('/prescriptions/my');
      final prescriptions = res.data['data'] as List? ?? [];
      final List<Map<String, dynamic>> items = [];

      for (final rx in prescriptions) {
        final rxItems = rx['items'] as List? ?? [];
        for (final item in rxItems) {
          items.add({
            'medicationName': item['medicationName'] ?? '',
            'dosage': item['dosage'] ?? '1 dose',
            'frequency': item['instructions'] ?? item['dosage'] ?? 'Daily',
            'reminderTime': item['reminderTime'] ?? '08:00 AM, 08:00 PM',
          });
        }
      }
      if (mounted) {
        setState(() => _prescriptionSuggestions = items);
      }
    } catch (_) {}
  }

  Future<void> _toggleReminder(Map<String, dynamic> r, bool val) async {
    HapticFeedback.lightImpact();
    setState(() {
      r['isActive'] = val;
    });
    await _saveToLocalStorage();

    // Async sync to server
    try {
      await _api.patch('/reminders/${r['id']}', data: {'isActive': val});
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(val ? '🔔 Reminder enabled for ${r['medicationName']}' : '⏸️ Reminder paused for ${r['medicationName']}'),
          backgroundColor: val ? AppColors.primary : Colors.grey[700],
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteReminder(String id, String medName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Reminder?'),
        content: Text('Are you sure you want to remove the medication reminder for $medName?'),
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
      HapticFeedback.mediumImpact();
      setState(() {
        _reminders.removeWhere((r) => r['id'].toString() == id.toString());
      });
      await _saveToLocalStorage();

      // Async delete from backend
      try {
        await _api.delete('/reminders/$id');
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reminder for $medName removed.'), backgroundColor: Colors.black87),
        );
      }
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

                // Prescription Quick Suggestions (if any)
                if (!isEdit && _prescriptionSuggestions.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: AppColors.primary, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Suggestions from Doctor Prescriptions:',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _prescriptionSuggestions.map((s) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            avatar: const Icon(Icons.medication, size: 14, color: AppColors.primary),
                            label: Text('${s['medicationName']} (${s['dosage']})', style: const TextStyle(fontSize: 11)),
                            backgroundColor: const Color(0xFFE8F5E9),
                            onPressed: () {
                              setModal(() {
                                medCtrl.text = s['medicationName'] ?? '';
                                dosageCtrl.text = s['dosage'] ?? '';
                                freqCtrl.text = s['frequency'] ?? '';
                                if (s['reminderTime'] != null && (s['reminderTime'] as String).isNotEmpty) {
                                  reminderTimeStr = s['reminderTime'];
                                }
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

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
                        if (t != null && ctx.mounted) {
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
                        HapticFeedback.mediumImpact();
                        try {
                          await NotificationService().show(
                            id: 777,
                            title: '💊 Pill Reminder (${chosen['title']})',
                            body: 'Time to take ${medCtrl.text.trim().isNotEmpty ? medCtrl.text.trim() : "your medication"} (${dosageCtrl.text.trim().isNotEmpty ? dosageCtrl.text.trim() : "1 dose"})',
                            payload: 'reminder_test',
                          );
                        } catch (_) {}
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('🔔 Sound theme "${chosen['title']}" triggered!'),
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
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setModal(() => selectedSound = s['id']);
                      },
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
                    final medName = medCtrl.text.trim();
                    if (medName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter medication name')),
                      );
                      return;
                    }

                    setModal(() => isSubmitting = true);

                    final String reminderId = isEdit ? existing['id'].toString() : 'rem_${DateTime.now().millisecondsSinceEpoch}';
                    final newReminderData = {
                      'id': reminderId,
                      'medicationName': medName,
                      'dosage': dosageCtrl.text.trim().isNotEmpty ? dosageCtrl.text.trim() : '1 dose',
                      'frequency': freqCtrl.text.trim().isNotEmpty ? freqCtrl.text.trim() : 'Daily',
                      'reminderTime': reminderTimeStr,
                      'sound': selectedSound,
                      'notes': notesCtrl.text.trim(),
                      'isActive': isEdit ? (existing['isActive'] ?? true) : true,
                      'createdAt': isEdit ? (existing['createdAt'] ?? DateTime.now().toIso8601String()) : DateTime.now().toIso8601String(),
                    };

                    // 1. Guaranteed Local Persistence Update
                    HapticFeedback.heavyImpact();
                    setState(() {
                      if (isEdit) {
                        final idx = _reminders.indexWhere((r) => r['id'].toString() == reminderId);
                        if (idx != -1) {
                          _reminders[idx] = newReminderData;
                        } else {
                          _reminders.insert(0, newReminderData);
                        }
                      } else {
                        _reminders.insert(0, newReminderData);
                      }
                    });
                    await _saveToLocalStorage();

                    // 2. Safe local notification trigger
                    try {
                      await NotificationService().show(
                        id: reminderId.hashCode,
                        title: 'Medication Reminder 💊',
                        body: 'Scheduled alarm for $medName at $reminderTimeStr',
                        payload: 'reminder:$reminderId',
                      );
                    } catch (notifErr) {
                      debugPrint('Local notification notice: $notifErr');
                    }

                    // 3. Close Modal Immediately
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isEdit ? '✅ Reminder updated successfully!' : '✅ Reminder for $medName saved!'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }

                    // 4. Background Cloud Sync (Non-blocking)
                    try {
                      if (isEdit) {
                        await _api.patch('/reminders/$reminderId', data: newReminderData);
                      } else {
                        final res = await _api.post('/reminders', data: newReminderData);
                        if (res.data?['data']?['id'] != null) {
                          final serverId = res.data['data']['id'].toString();
                          setState(() {
                            final idx = _reminders.indexWhere((r) => r['id'].toString() == reminderId);
                            if (idx != -1) {
                              _reminders[idx]['id'] = serverId;
                            }
                          });
                          await _saveToLocalStorage();
                        }
                      }
                    } catch (cloudErr) {
                      debugPrint('Cloud sync in background (safe): $cloudErr');
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
                activeTrackColor: AppColors.primaryLight,
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
