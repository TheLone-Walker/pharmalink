import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';

class SetAvailabilityScreen extends StatefulWidget {
  const SetAvailabilityScreen({super.key});
  @override
  State<SetAvailabilityScreen> createState() => _SetAvailabilityScreenState();
}

class _SetAvailabilityScreenState extends State<SetAvailabilityScreen> {
  final _api = ApiService();
  bool _saving = false;

  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  // dayOfWeek (0=Mon) → { isAvailable, startTime, endTime }
  final Map<int, Map<String, dynamic>> _slots = {
    0: {'isAvailable': true, 'startTime': '08:00', 'endTime': '17:00'},
    1: {'isAvailable': true, 'startTime': '08:00', 'endTime': '17:00'},
    2: {'isAvailable': true, 'startTime': '08:00', 'endTime': '17:00'},
    3: {'isAvailable': true, 'startTime': '08:00', 'endTime': '17:00'},
    4: {'isAvailable': true, 'startTime': '08:00', 'endTime': '17:00'},
    5: {'isAvailable': false, 'startTime': '09:00', 'endTime': '13:00'},
    6: {'isAvailable': false, 'startTime': '09:00', 'endTime': '13:00'},
  };

  Future<void> _pickTime(int dayIndex, String key) async {
    final parts = (_slots[dayIndex]![key] as String).split(':');
    final initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() => _slots[dayIndex]![key] =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final slots = _slots.entries.map((e) => {
        'dayOfWeek': e.key,
        'startTime': e.value['startTime'],
        'endTime': e.value['endTime'],
        'isAvailable': e.value['isAvailable'],
      }).toList();
      await _api.put('/doctor/availability', data: {'slots': slots});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Availability saved!'), backgroundColor: AppColors.primary));
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save. Try again.'), backgroundColor: AppColors.error));
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Availability')),
      body: Column(children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _days.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final slot = _slots[i]!;
              final isAvailable = slot['isAvailable'] as bool;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isAvailable ? Colors.white : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isAvailable ? AppColors.lightGreen : const Color(0xFFEEEEEE),
                    width: 1.5,
                  ),
                ),
                child: Column(children: [
                  Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: isAvailable ? AppColors.lightGreen : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(_days[i].substring(0, 3),
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: isAvailable ? AppColors.primary : Colors.grey,
                          )),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_days[i],
                        style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14,
                          color: isAvailable ? AppColors.textDark : Colors.grey,
                        )),
                    ),
                    Switch(
                      value: isAvailable,
                      onChanged: (val) => setState(() => _slots[i]!['isAvailable'] = val),
                      activeColor: AppColors.primary,
                    ),
                  ]),
                  if (isAvailable) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(children: [
                      const Icon(Icons.access_time, color: AppColors.accent, size: 16),
                      const SizedBox(width: 6),
                      const Text('Hours:', style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _pickTime(i, 'startTime'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.lightGreen,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(slot['startTime'],
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('→', style: TextStyle(color: AppColors.textGrey)),
                      ),
                      GestureDetector(
                        onTap: () => _pickTime(i, 'endTime'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.lightGreen,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(slot['endTime'],
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ),
                    ]),
                  ],
                ]),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: PharmaButton(label: 'Save Availability', onPressed: _save, isLoading: _saving, icon: Icons.save),
        ),
      ]),
    );
  }
}
