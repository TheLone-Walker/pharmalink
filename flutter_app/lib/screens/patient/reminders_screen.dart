import 'dart:convert';
import 'dart:math' as math;
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
    // 1. Instantly load from local storage first
    try {
      final prefs = await SharedPreferences.getInstance();
      final localData = prefs.getString(_storageKey);
      if (localData != null && localData.isNotEmpty) {
        final decoded = jsonDecode(localData) as List;
        if (mounted) {
          setState(() {
            _reminders = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = _reminders.isEmpty);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }

    // 2. Fetch from cloud API and merge with short timeout
    try {
      final res = await _api.get('/reminders');
      if (res.data != null && res.data['data'] is List) {
        final cloudList = (res.data['data'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        if (cloudList.isNotEmpty && mounted) {
          final Map<String, Map<String, dynamic>> merged = {};
          for (final r in _reminders) {
            merged[r['id'].toString()] = r;
          }
          for (final c in cloudList) {
            merged[c['id'].toString()] = c;
          }
          setState(() {
            _reminders = merged.values.toList();
          });
          await _saveToLocalStorage();
        }
      }
    } catch (_) {
      // Offline or local storage fallback
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

  void _openAddOrEditModal({Map<String, dynamic>? existing}) async {
    HapticFeedback.lightImpact();
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width > 700;
    final modalWidth = isDesktop ? math.min(screenSize.width * 0.9, 580.0) : math.min(screenSize.width * 0.95, 520.0);
    final modalHeight = math.min(screenSize.height * 0.88, 760.0);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 24,
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SizedBox(
          width: modalWidth,
          height: modalHeight,
          child: Material(
            color: Colors.white,
            child: AddEditReminderContent(
              existing: existing,
              prescriptionSuggestions: _prescriptionSuggestions,
              onClose: () => Navigator.of(ctx, rootNavigator: true).pop(),
              onSave: (data) => Navigator.of(ctx, rootNavigator: true).pop(data),
            ),
          ),
        ),
      ),
    );

    if (result != null && mounted) {
      final isEdit = existing != null;
      final reminderId = result['id'].toString();
      final medName = result['medicationName'] ?? 'Medication';

      setState(() {
        if (isEdit) {
          final idx = _reminders.indexWhere((r) => r['id'].toString() == reminderId);
          if (idx != -1) {
            _reminders[idx] = result;
          } else {
            _reminders.insert(0, result);
          }
        } else {
          _reminders.insert(0, result);
        }
      });
      _saveToLocalStorage();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.alarm_on_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isEdit ? '✅ Reminder updated for $medName' : '✅ Alarm scheduled for $medName at ${result['reminderTime']}!',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );

      // Safe local notification trigger (non-blocking)
      NotificationService().show(
        id: reminderId.hashCode,
        title: 'Medication Reminder 💊',
        body: 'Scheduled alarm for $medName at ${result['reminderTime']}',
        payload: 'reminder:$reminderId',
      ).catchError((_) {});

      // Background Cloud Sync (Non-blocking)
      Future.microtask(() async {
        try {
          if (isEdit) {
            await _api.patch('/reminders/$reminderId', data: result);
          } else {
            final res = await _api.post('/reminders', data: result);
            if (res.data?['data']?['id'] != null && mounted) {
              final serverId = res.data['data']['id'].toString();
              setState(() {
                final idx = _reminders.indexWhere((r) => r['id'].toString() == reminderId);
                if (idx != -1) {
                  _reminders[idx]['id'] = serverId;
                }
              });
              _saveToLocalStorage();
            }
          }
        } catch (cloudErr) {
          debugPrint('Cloud reminder sync in background: $cloudErr');
        }
      });
    }
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
        onPressed: () => _openAddOrEditModal(),
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
              icon: const Icon(Icons.add_alarm_rounded, size: 18),
              label: const Text('Add Medication Reminder'),
              onPressed: () => _openAddOrEditModal(),
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
                onPressed: () => _openAddOrEditModal(existing: r),
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

// ─────────────────────────────────────────────────────────────────────────────
// PERFECT ADAPTIVE MODAL CONTENT: ADD / EDIT MEDICATION ALARM REMINDER
// ─────────────────────────────────────────────────────────────────────────────
class AddEditReminderContent extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final List<Map<String, dynamic>> prescriptionSuggestions;
  final VoidCallback onClose;
  final ValueChanged<Map<String, dynamic>> onSave;

  const AddEditReminderContent({
    super.key,
    this.existing,
    this.prescriptionSuggestions = const [],
    required this.onClose,
    required this.onSave,
  });

  @override
  State<AddEditReminderContent> createState() => _AddEditReminderContentState();
}

class _AddEditReminderContentState extends State<AddEditReminderContent> {
  late final TextEditingController _medCtrl;
  late final TextEditingController _dosageCtrl;
  late final TextEditingController _freqCtrl;
  late final TextEditingController _notesCtrl;
  late String _reminderTimeStr;
  late String _selectedSound;

  final List<String> _quickFrequencies = [
    'Once Daily (Morning)',
    'Twice Daily (Morning & Night)',
    '3 Times Daily (Every 8h)',
    'Every 6 Hours (4x Daily)',
    'Before Bedtime',
    'As Needed (PRN)',
  ];

  @override
  void initState() {
    super.initState();
    _medCtrl = TextEditingController(text: widget.existing?['medicationName'] ?? '');
    _dosageCtrl = TextEditingController(text: widget.existing?['dosage'] ?? '');
    _freqCtrl = TextEditingController(text: widget.existing?['frequency'] ?? '');
    _notesCtrl = TextEditingController(text: widget.existing?['notes'] ?? '');
    _reminderTimeStr = widget.existing?['reminderTime'] ?? '08:00 AM';
    _selectedSound = widget.existing?['sound'] ?? 'gentle_chime';
  }

  @override
  void dispose() {
    _medCtrl.dispose();
    _dosageCtrl.dispose();
    _freqCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _handleSave() {
    final medName = _medCtrl.text.trim();
    if (medName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the medication name'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final String reminderId = widget.existing != null
        ? widget.existing!['id'].toString()
        : 'rem_${DateTime.now().millisecondsSinceEpoch}';

    final result = {
      'id': reminderId,
      'medicationName': medName,
      'dosage': _dosageCtrl.text.trim().isNotEmpty ? _dosageCtrl.text.trim() : '1 dose',
      'frequency': _freqCtrl.text.trim().isNotEmpty ? _freqCtrl.text.trim() : 'Daily',
      'reminderTime': _reminderTimeStr,
      'sound': _selectedSound,
      'notes': _notesCtrl.text.trim(),
      'isActive': widget.existing != null ? (widget.existing!['isActive'] ?? true) : true,
      'createdAt': widget.existing != null
          ? (widget.existing!['createdAt'] ?? DateTime.now().toIso8601String())
          : DateTime.now().toIso8601String(),
    };

    widget.onSave(result);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Modal Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppColors.lightGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.alarm_add_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEdit ? 'Edit Medication Alarm' : 'Set Medication Alarm',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Set exact pill schedule with personalized alarm sounds',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.textGrey),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 20),

          // Modal Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(context).viewInsets.bottom + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Prescription Suggestions (if available)
                  if (!isEdit && widget.prescriptionSuggestions.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome, color: Color(0xFF16A34A), size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Quick-fill from Doctor Prescriptions:',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF166534),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.prescriptionSuggestions.map((s) {
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _medCtrl.text = s['medicationName'] ?? '';
                                    _dosageCtrl.text = s['dosage'] ?? '';
                                    _freqCtrl.text = s['frequency'] ?? '';
                                    if (s['reminderTime'] != null && (s['reminderTime'] as String).isNotEmpty) {
                                      _reminderTimeStr = s['reminderTime'];
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF86EFAC)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.medication, size: 14, color: AppColors.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${s['medicationName']} (${s['dosage']})',
                                        style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Medication Name
                  PharmaField(
                    label: 'Medication Name *',
                    hint: 'e.g. Artemether, Amoxicillin 500mg, Paracetamol',
                    prefixIcon: Icons.medication_outlined,
                    controller: _medCtrl,
                  ),
                  const SizedBox(height: 14),

                  // Dosage & Frequency
                  Row(
                    children: [
                      Expanded(
                        child: PharmaField(
                          label: 'Dosage',
                          hint: 'e.g. 1 tablet, 2 capsules',
                          prefixIcon: Icons.colorize_outlined,
                          controller: _dosageCtrl,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PharmaField(
                          label: 'Frequency',
                          hint: 'e.g. Twice Daily',
                          prefixIcon: Icons.repeat_rounded,
                          controller: _freqCtrl,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Quick Frequencies
                  const Text('Quick Presets:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _quickFrequencies.map((f) {
                      final isCur = _freqCtrl.text == f;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _freqCtrl.text = f;
                            if (f.contains('3 Times')) _reminderTimeStr = '08:00 AM, 01:00 PM, 08:00 PM';
                            if (f.contains('Twice')) _reminderTimeStr = '08:00 AM, 08:00 PM';
                            if (f.contains('Once')) _reminderTimeStr = '08:00 AM';
                            if (f.contains('Bedtime')) _reminderTimeStr = '09:00 PM';
                            if (f.contains('6 Hours')) _reminderTimeStr = '08:00 AM, 12:00 PM, 04:00 PM, 08:00 PM';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isCur ? AppColors.primary : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isCur ? AppColors.primary : const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            f,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isCur ? Colors.white : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // Scheduled Alarm Time Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(color: Color(0xFFE0F2FE), shape: BoxShape.circle),
                          child: const Icon(Icons.access_time_filled, color: Color(0xFF0284C7), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _reminderTimeStr,
                                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary),
                              ),
                              const Text('Alarm rings at this time', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.schedule, size: 15),
                          label: const Text('Pick Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          onPressed: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (t != null && mounted) {
                              setState(() => _reminderTimeStr = t.format(context));
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Sound Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Alert Sound Tone', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      Icon(Icons.volume_up_outlined, size: 16, color: AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _RemindersScreenState.soundThemes.map((s) {
                      final isSelected = _selectedSound == s['id'];
                      final color = s['color'] as Color;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedSound = s['id']);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected ? color.withValues(alpha: 0.12) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isSelected ? color : const Color(0xFFE2E8F0), width: isSelected ? 2.0 : 1.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(s['icon'] as IconData, size: 14, color: isSelected ? color : Colors.grey[600]),
                              const SizedBox(width: 5),
                              Text(
                                s['title'] as String,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                  color: isSelected ? color : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Notes / Instructions
                  PharmaField(
                    label: 'Instructions & Notes (Optional)',
                    hint: 'e.g. Take with a large glass of water after meal',
                    prefixIcon: Icons.notes_rounded,
                    controller: _notesCtrl,
                  ),
                  const SizedBox(height: 22),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: Text(
                        isEdit ? 'Update Medication Reminder' : 'Save & Set Reminder Alarm ⏰',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      onPressed: _handleSave,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
