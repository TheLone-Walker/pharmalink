import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';

class BookAppointmentScreen extends StatefulWidget {
  final String? initialHospital;
  const BookAppointmentScreen({super.key, this.initialHospital});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _hospitals = [];
  List<Map<String, dynamic>> _allDoctors = [];
  bool _loading = true;

  Map<String, dynamic>? _selectedHospital;
  Map<String, dynamic>? _selectedDoctor;
  Map<String, dynamic>? _doctorSchedule;
  bool _loadingSchedule = false;

  DateTime? _selectedDate;
  String _selectedTime = '';
  String _type = 'in_person';
  final _notesCtrl = TextEditingController();
  final _hospitalTextCtrl = TextEditingController();
  bool _booking = false;

  TextEditingController? _autocompleteCtrl;
  String _hospitalSearchQuery = '';

  final _timeSlots = ['09:00 AM', '10:00 AM', '11:00 AM', '02:00 PM', '03:00 PM', '04:00 PM'];
  final _daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _hospitalTextCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.get('/users/hospitals'),
        _api.get('/users/doctors'),
      ]);

      final List hospitalData = results[0].data['data'] ?? [];
      final List doctorData = results[1].data['data'] ?? [];
      final docs = doctorData.cast<Map<String, dynamic>>();

      // Merge backend hospitals with full Cameroon hospital dataset
      final Map<String, int> docCountByHosp = {};
      for (final d in docs) {
        final h = (d['doctorProfile']?['hospital'] ?? '').toString().trim();
        if (h.isNotEmpty) {
          docCountByHosp[h] = (docCountByHosp[h] ?? 0) + 1;
        }
      }

      final Set<String> hospitalNames = {
        ...AppConstants.cameroonHospitals,
        ...hospitalData.map((h) => (h['name'] ?? '').toString()).where((n) => n.isNotEmpty),
        ...docCountByHosp.keys,
      };

      final List<Map<String, dynamic>> mergedHospitals = hospitalNames.map<Map<String, dynamic>>((name) {
        // Count doctors whose hospital loosely matches this hospital name
        int count = 0;
        for (final d in docs) {
          final dh = (d['doctorProfile']?['hospital'] ?? '').toString();
          if (_isHospitalMatch(dh, name)) {
            count++;
          }
        }
        return <String, dynamic>{
          'name': name,
          'doctorCount': count,
        };
      }).toList();

      // Sort so hospitals with registered doctors appear first, then alphabetical
      mergedHospitals.sort((a, b) {
        final countCmp = (b['doctorCount'] as int).compareTo(a['doctorCount'] as int);
        if (countCmp != 0) return countCmp;
        return (a['name'] as String).compareTo(b['name'] as String);
      });

      setState(() {
        _hospitals = mergedHospitals;
        _allDoctors = docs;
      });

      if (widget.initialHospital != null && widget.initialHospital!.isNotEmpty) {
        _selectHospitalByName(widget.initialHospital!);
      }
    } catch (_) {} finally {
      setState(() => _loading = false);
    }
  }

  bool _isHospitalMatch(String docHospital, String targetHospital) {
    if (docHospital.trim().isEmpty || targetHospital.trim().isEmpty) return false;
    
    final d = docHospital.toLowerCase()
        .replaceAll('ô', 'o').replaceAll('é', 'e').replaceAll('è', 'e')
        .replaceAll('\'', ' ').replaceAll('-', ' ').replaceAll('(', ' ').replaceAll(')', ' ').trim();
    final t = targetHospital.toLowerCase()
        .replaceAll('ô', 'o').replaceAll('é', 'e').replaceAll('è', 'e')
        .replaceAll('\'', ' ').replaceAll('-', ' ').replaceAll('(', ' ').replaceAll(')', ' ').trim();
    
    if (d == t || d.contains(t) || t.contains(d)) return true;

    // Special acronyms & aliases matching
    if ((d.contains('chu') || d.contains('teaching')) && (t.contains('chu') || t.contains('teaching') || t.contains('universitaire'))) return true;
    if (d.contains('chantal') && t.contains('chantal')) return true;
    if (d.contains('hgopy') && (t.contains('hgopy') || t.contains('gyneco') || t.contains('pediatrique'))) return true;
    if (d.contains('bastos') && t.contains('bastos')) return true;
    if (d.contains('central') && t.contains('central')) return true;
    if (d.contains('general') && t.contains('general') && (d.contains('douala') == t.contains('douala'))) return true;
    if (d.contains('laquintinie') && t.contains('laquintinie')) return true;
    if (d.contains('jamot') && t.contains('jamot')) return true;
    if (d.contains('biyem') && t.contains('biyem')) return true;
    if (d.contains('cite verte') && t.contains('cite verte')) return true;
    if ((d.contains('militaire') || d.contains('military')) && (t.contains('militaire') || t.contains('military'))) return true;

    // Word token intersection for distinctive words
    const stopWords = {'hopital', 'hospital', 'centre', 'center', 'regional', 'district', 'yaounde', 'douala', 'de', 'la', 'du', 'des', 'le', 'et'};
    final dWords = d.split(RegExp(r'\s+')).where((w) => w.length >= 3 && !stopWords.contains(w)).toSet();
    final tWords = t.split(RegExp(r'\s+')).where((w) => w.length >= 3 && !stopWords.contains(w)).toSet();

    if (dWords.isNotEmpty && tWords.isNotEmpty && dWords.intersection(tWords).isNotEmpty) {
      return true;
    }

    return false;
  }

  void _selectHospitalByName(String hospName) {
    Map<String, dynamic>? hosp;
    for (final h in _hospitals) {
      if ((h['name'] ?? '').toString().toLowerCase() == hospName.toLowerCase()) {
        hosp = h;
        break;
      }
    }
    hosp ??= <String, dynamic>{'name': hospName, 'doctorCount': 0};

    if (_autocompleteCtrl != null && _autocompleteCtrl!.text != hospName) {
      _autocompleteCtrl!.text = hospName;
    }
    setState(() {
      _selectedHospital = hosp;
      _hospitalSearchQuery = hospName;
      _selectedDoctor = null;
      _doctorSchedule = null;
    });
  }

  Future<void> _loadDoctorSchedule(String doctorId) async {
    setState(() => _loadingSchedule = true);
    try {
      final res = await _api.get('/appointments/schedule/$doctorId');
      setState(() {
        _doctorSchedule = res.data['data'];
      });
    } catch (_) {} finally {
      setState(() => _loadingSchedule = false);
    }
  }

  void _selectDoctor(Map<String, dynamic> doc) {
    setState(() {
      _selectedDoctor = doc;
      _selectedTime = '';
      _doctorSchedule = null;
    });
    _loadDoctorSchedule(doc['id']);
  }

  List<Map<String, dynamic>> get _availableDoctorsForHospital {
    if (_selectedHospital == null && _hospitalSearchQuery.isEmpty) {
      return _allDoctors;
    }

    final targetHosp = _selectedHospital?['name'] ?? _hospitalSearchQuery;

    final matched = _allDoctors.where((d) {
      final dHosp = (d['doctorProfile']?['hospital'] ?? '').toString();
      return _isHospitalMatch(dHosp, targetHosp);
    }).toList();

    return matched;
  }

  // ─── Slot Availability Checker ────────────────────────────────────────────────
  String _getSlotStatus(String slot) {
    if (_selectedDate == null || _doctorSchedule == null) return 'available';

    // 1. Check if day of week is available
    final dayIdx = _selectedDate!.weekday - 1; // 0=Mon..6=Sun
    final availList = _doctorSchedule!['availability'] as List? ?? [];
    Map<String, dynamic>? dayAvail;
    for (final a in availList) {
      if (a is Map && a['dayOfWeek'] == dayIdx) {
        dayAvail = Map<String, dynamic>.from(a);
        break;
      }
    }
    if (dayAvail != null && dayAvail['isAvailable'] == false) {
      return 'off_day';
    }

    final parts = slot.replaceAll(' AM', '').replaceAll(' PM', '').split(':');
    int hour = int.parse(parts[0]);
    final isPm = slot.contains('PM');
    if (isPm && hour != 12) hour += 12;
    if (!isPm && hour == 12) hour = 0;

    final targetDateTime = DateTime(
      _selectedDate!.year, _selectedDate!.month, _selectedDate!.day, hour, 0,
    );

    // 2. Check doctor personal blocked times
    final blockedTimes = _doctorSchedule!['blockedTimes'] as List? ?? [];
    for (final b in blockedTimes) {
      final start = DateTime.tryParse(b['startDate'] ?? '');
      final end = DateTime.tryParse(b['endDate'] ?? '');
      if (start != null && end != null) {
        if (targetDateTime.isAfter(start.subtract(const Duration(minutes: 1))) &&
            targetDateTime.isBefore(end.add(const Duration(minutes: 1)))) {
          return 'blocked';
        }
      }
    }

    // 3. Check booked appointments
    final bookedAppointments = _doctorSchedule!['bookedAppointments'] as List? ?? [];
    for (final a in bookedAppointments) {
      final aptDate = DateTime.tryParse(a['appointmentDate'] ?? '');
      if (aptDate != null) {
        final diff = (aptDate.difference(targetDateTime).inMinutes).abs();
        if (diff < 30) {
          return 'booked';
        }
      }
    }

    return 'available';
  }

  // ─── View Doctor Weekly Schedule Modal ───────────────────────────────────────
  void _showDoctorScheduleModal() {
    if (_selectedDoctor == null) return;
    final availList = (_doctorSchedule?['availability'] as List? ?? []);
    final blockedList = (_doctorSchedule?['blockedTimes'] as List? ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                const Icon(Icons.schedule_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text('Dr. ${_selectedDoctor!['name']}\'s Schedule',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ]),
            const Divider(height: 20),
            const Text('Weekly Consultation Hours', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 10),
            if (availList.isEmpty)
              const Text('Standard Office Hours: Monday - Friday, 08:00 AM - 05:00 PM', style: TextStyle(fontSize: 12, color: AppColors.textGrey))
            else
              ..._daysOfWeek.asMap().entries.map((e) {
                Map<String, dynamic>? day;
                for (final a in availList) {
                  if (a is Map && a['dayOfWeek'] == e.key) {
                    day = Map<String, dynamic>.from(a);
                    break;
                  }
                }
                final isAvailable = day?['isAvailable'] ?? (e.key < 5);
                final start = day?['startTime'] ?? '08:00';
                final end = day?['endTime'] ?? '17:00';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(e.value, style: const TextStyle(fontSize: 12, color: AppColors.textDark)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isAvailable ? AppColors.lightGreen : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isAvailable ? '$start - $end' : 'Day Off',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isAvailable ? AppColors.primary : AppColors.error,
                        ),
                      ),
                    ),
                  ]),
                );
              }),
            if (blockedList.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Doctor Blocked Personal Times', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.orange)),
              const SizedBox(height: 8),
              ...blockedList.take(3).map((b) {
                final start = DateTime.tryParse(b['startDate'] ?? '');
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    const Icon(Icons.block, size: 13, color: Colors.orange),
                    const SizedBox(width: 6),
                    Text(
                      '${start != null ? '${start.day}/${start.month}/${start.year}' : ''} (${b['reason'] ?? 'Personal / Surgery'})',
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ]),
                );
              }),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _book() async {
    if (_selectedHospital == null && _hospitalSearchQuery.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or type a hospital'), backgroundColor: AppColors.error));
      return;
    }
    if (_selectedDoctor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a doctor to book an appointment with'), backgroundColor: AppColors.error));
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an appointment date'), backgroundColor: AppColors.error));
      return;
    }
    if (_selectedTime.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot'), backgroundColor: AppColors.error));
      return;
    }

    final status = _getSlotStatus(_selectedTime);
    if (status == 'booked') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This slot is already booked. Please choose an available time.'), backgroundColor: AppColors.error));
      return;
    }
    if (status == 'blocked') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The doctor has blocked this time slot. Please pick another time.'), backgroundColor: AppColors.error));
      return;
    }

    setState(() => _booking = true);
    try {
      final parts = _selectedTime.replaceAll(' AM', '').replaceAll(' PM', '').split(':');
      int hour = int.parse(parts[0]);
      final isPm = _selectedTime.contains('PM');
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;

      final dateTime = DateTime(
        _selectedDate!.year, _selectedDate!.month, _selectedDate!.day, hour, 0);

      final hospitalName = _selectedHospital?['name'] ?? _hospitalSearchQuery;

      await _api.post('/appointments', data: {
        'doctorId': _selectedDoctor!['id'],
        'hospital': hospitalName,
        'appointmentDate': dateTime.toIso8601String(),
        'type': _type,
        'notes': _notesCtrl.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment booked successfully! Doctor notified.'), backgroundColor: AppColors.primary));
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking failed: ${e.toString().substring(0, 80)}'), backgroundColor: AppColors.error));
    } finally {
      setState(() => _booking = false);
    }
  }

  Widget _buildDoctorCard(Map<String, dynamic> doc) {
    final profile = doc['doctorProfile'] as Map? ?? {};
    final isSelected = _selectedDoctor?['id'] == doc['id'];
    final docHospital = profile['hospital'] ?? 'Medical Center';
    final specialty = profile['specialty'] ?? 'General Practitioner';
    final isOnmcVerified = doc['isOnmcVerified'] == true || profile['isOnmcVerified'] == true;
    final isAvailable = doc['isAvailable'] == true || profile['isAvailable'] == true;

    return GestureDetector(
      onTap: () => _selectDoctor(doc),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? AppColors.primary.withOpacity(0.12) : Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primary.withOpacity(0.12),
                backgroundImage: doc['profilePhotoUrl'] != null
                  ? NetworkImage('${AppConstants.baseUrl.replaceAll('/api', '')}${doc['profilePhotoUrl']}')
                  : null,
                child: doc['profilePhotoUrl'] == null
                  ? Text((doc['name'] as String? ?? 'D')[0].toUpperCase(),
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 20))
                  : null,
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                  children: [
                    Flexible(
                      child: Text('Dr. ${doc['name']}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textDark)),
                    ),
                    if (isOnmcVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, color: AppColors.primary, size: 16),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // Prominent Specialty Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.lightGreen,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.medical_services_outlined, size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        specialty,
                        style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ])),
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? AppColors.primary : Colors.grey[300],
                size: 24,
              ),
            ]),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.apartment_rounded, size: 14, color: AppColors.textGrey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    docHospital,
                    style: const TextStyle(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isAvailable ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isAvailable ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    isAvailable ? '🟢 Available' : '⚪ On Call',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isAvailable ? const Color(0xFF166534) : Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlotPill(String t) {
    final status = _getSlotStatus(t);
    final isSelected = _selectedTime == t;
    final isBooked = status == 'booked';
    final isBlocked = status == 'blocked';
    final isOff = status == 'off_day';
    final isUnavailable = isBooked || isBlocked || isOff;

    Color bg;
    Color border;
    Color textCol;
    String badge = '';

    if (isBooked) {
      bg = const Color(0xFFF5F5F5);
      border = const Color(0xFFE0E0E0);
      textCol = Colors.grey[400]!;
      badge = 'Booked';
    } else if (isBlocked) {
      bg = const Color(0xFFFFF3E0);
      border = const Color(0xFFFFCC80);
      textCol = const Color(0xFFE65100);
      badge = 'Busy';
    } else if (isOff) {
      bg = const Color(0xFFFFEBEE);
      border = const Color(0xFFFFCDD2);
      textCol = Colors.red[300]!;
      badge = 'Off';
    } else if (isSelected) {
      bg = AppColors.primary;
      border = AppColors.primary;
      textCol = Colors.white;
    } else {
      bg = Colors.white;
      border = const Color(0xFFEEEEEE);
      textCol = AppColors.textDark;
    }

    return GestureDetector(
      onTap: isUnavailable ? null : () => setState(() => _selectedTime = t),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(t, style: TextStyle(fontSize: 12, color: textCol, fontWeight: FontWeight.w500)),
          if (badge.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text('($badge)', style: TextStyle(fontSize: 10, color: textCol, fontStyle: FontStyle.italic)),
          ],
        ]),
      ),
    );
  }

  Widget _hospitalChip(String fullHospName, String displayLabel) {
    final isSelected = _isHospitalMatch(_selectedHospital?['name'] ?? _hospitalSearchQuery, fullHospName);
    return ChoiceChip(
      label: Text(displayLabel, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? Colors.white : AppColors.textDark)),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      side: BorderSide(color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0)),
      onSelected: (selected) {
        if (selected) {
          _selectHospitalByName(fullHospName);
        } else {
          if (_autocompleteCtrl != null) {
            _autocompleteCtrl!.clear();
          }
          setState(() {
            _selectedHospital = null;
            _hospitalSearchQuery = '';
            _selectedDoctor = null;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableDoctors = _availableDoctorsForHospital;
    final currentHospitalName = _selectedHospital?['name'] ?? (_hospitalSearchQuery.isNotEmpty ? _hospitalSearchQuery : null);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Book Appointment')),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Step 1: Hospital Search & Predictive Autocomplete ──────────────────
              const Text('1. Select Hospital / Health Center',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              const SizedBox(height: 4),
              const Text('Type hospital name to autocomplete or choose from the list below:',
                style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
              const SizedBox(height: 10),

              // Predictive Hospital Autocomplete Field
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _hospitalSearchQuery),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  final query = textEditingValue.text.toLowerCase().trim();
                  if (query.isEmpty) {
                    return _hospitals.take(8).map((h) => h['name'] as String);
                  }
                  return _hospitals
                      .where((h) {
                        final name = (h['name'] ?? '').toString().toLowerCase();
                        return _isHospitalMatch(name, query) || name.contains(query);
                      })
                      .map((h) => h['name'] as String);
                },
                onSelected: (String selection) {
                  _selectHospitalByName(selection);
                },
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                  _autocompleteCtrl = textEditingController;
                  return TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    onChanged: (v) {
                      Map<String, dynamic>? matchedHosp;
                      final trimmed = v.trim();
                      if (trimmed.isNotEmpty) {
                        for (final h in _hospitals) {
                          if ((h['name'] ?? '').toString().toLowerCase() == trimmed.toLowerCase()) {
                            matchedHosp = h;
                            break;
                          }
                        }
                        matchedHosp ??= <String, dynamic>{'name': v, 'doctorCount': 0};
                      }
                      setState(() {
                        _hospitalSearchQuery = v;
                        _selectedHospital = matchedHosp;
                        _selectedDoctor = null;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Type hospital (e.g. Hôpital Central, CHU Yaoundé, Chantal Biya)...',
                      hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                      prefixIcon: const Icon(Icons.apartment_rounded, color: AppColors.primary, size: 20),
                      suffixIcon: textEditingController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                              onPressed: () {
                                textEditingController.clear();
                                setState(() {
                                  _hospitalSearchQuery = '';
                                  _selectedHospital = null;
                                  _selectedDoctor = null;
                                });
                              },
                            )
                          : const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                    ),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: MediaQuery.of(context).size.width - 40,
                        constraints: const BoxConstraints(maxHeight: 260),
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
                            Map<String, dynamic>? hospObj;
                            for (final h in _hospitals) {
                              if (h['name'] == option) {
                                hospObj = h;
                                break;
                              }
                            }
                            hospObj ??= <String, dynamic>{'name': option, 'doctorCount': 0};
                            final docCount = (hospObj['doctorCount'] as int?) ?? 0;
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.local_hospital_rounded, color: AppColors.primary, size: 22),
                              title: Text(option, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              subtitle: Text(docCount > 0 ? '🟢 $docCount doctor(s) on duty' : 'Health Center • Cameroon',
                                style: TextStyle(fontSize: 11, color: docCount > 0 ? AppColors.primary : AppColors.textGrey, fontWeight: docCount > 0 ? FontWeight.w600 : FontWeight.normal)),
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

              // Quick Hospital Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _hospitalChip('Hôpital Central de Yaoundé', '🏥 Hôpital Central'),
                    const SizedBox(width: 8),
                    _hospitalChip('Centre Hospitalier Universitaire (CHU) Yaoundé', '🏥 CHU Yaoundé'),
                    const SizedBox(width: 8),
                    _hospitalChip('Fondation Chantal Biya, Yaoundé', '🏥 Chantal Biya'),
                    const SizedBox(width: 8),
                    _hospitalChip('Hôpital Gynéco-Obstétrique et Pédiatrique de Yaoundé (HGOPY)', '🏥 HGOPY'),
                    const SizedBox(width: 8),
                    _hospitalChip('Clinique Bastos, Yaoundé', '🏥 Clinique Bastos'),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Step 2: Available Doctors Showing Specialities Working In That Hospital ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentHospitalName != null
                              ? '2. Doctors at $currentHospitalName'
                              : '2. Available Doctors & Specialities',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentHospitalName != null
                              ? 'Showing doctors & specialists affiliated with this hospital'
                              : 'Type a hospital name above to filter, or select any doctor below:',
                          style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      '${availableDoctors.length} Found',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (availableDoctors.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.people_outline, size: 36, color: AppColors.textGrey),
                      const SizedBox(height: 8),
                      Text(
                        currentHospitalName != null
                            ? 'No registered doctors currently found at "$currentHospitalName"'
                            : 'No doctors found',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap "Hôpital Central" or "CHU Yaoundé" above to view available specialists.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                      ),
                    ],
                  ),
                )
              else
                ...availableDoctors.map(_buildDoctorCard),

              // ── View Doctor Schedule Button ─────────────────────────────────────────
              if (_selectedDoctor != null) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: _showDoctorScheduleModal,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'View Dr. ${_selectedDoctor!['name']}\'s working hours & schedule',
                          style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.primary),
                    ]),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ── Step 3: Appointment Details (Type, Date, Time) ───────────────────────
              if (_selectedDoctor != null) ...[
                const Text('3. Appointment Type & Schedule',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const SizedBox(height: 10),

                // In-Person vs Telemedicine
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () => setState(() => _type = 'in_person'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _type == 'in_person' ? AppColors.lightGreen : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _type == 'in_person' ? AppColors.primary : const Color(0xFFEEEEEE), width: 1.5),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.person_outlined, color: _type == 'in_person' ? AppColors.primary : Colors.grey, size: 18),
                        const SizedBox(width: 6),
                        Text('In Person', style: TextStyle(fontSize: 13, color: _type == 'in_person' ? AppColors.primary : Colors.grey, fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: GestureDetector(
                    onTap: () => setState(() => _type = 'telemedicine'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _type == 'telemedicine' ? AppColors.lightGreen : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _type == 'telemedicine' ? AppColors.primary : const Color(0xFFEEEEEE), width: 1.5),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.video_call_outlined, color: _type == 'telemedicine' ? AppColors.primary : Colors.grey, size: 18),
                        const SizedBox(width: 6),
                        Text('Telemedicine', style: TextStyle(fontSize: 13, color: _type == 'telemedicine' ? AppColors.primary : Colors.grey, fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  )),
                ]),

                const SizedBox(height: 16),

                // Date Picker
                const Text('Consultation Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                    );
                    if (d != null) {
                      setState(() {
                        _selectedDate = d;
                        _selectedTime = ''; // reset slot on date change
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: _selectedDate != null ? AppColors.primary : const Color(0xFFE2E8F0), width: 1.5),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_today_outlined, color: _selectedDate != null ? AppColors.primary : AppColors.accent, size: 20),
                      const SizedBox(width: 10),
                      Text(_selectedDate == null ? 'Choose a consultation date' : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                        style: TextStyle(color: _selectedDate == null ? Colors.black38 : AppColors.textDark, fontSize: 13,
                          fontWeight: _selectedDate != null ? FontWeight.w600 : FontWeight.normal)),
                    ]),
                  ),
                ),

                const SizedBox(height: 16),

                // Available Time Slots
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Available Time Slots', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  if (_loadingSchedule)
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                ]),
                const SizedBox(height: 4),
                const Text('Slots marked (Booked) or (Busy) cannot be reserved', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: _timeSlots.map(_buildTimeSlotPill).toList()),

                const SizedBox(height: 16),

                // Notes
                const Text('Notes for the Doctor (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Describe your symptoms or reason for visit...',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.black26),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                ),

                // Live Summary Card
                if (_selectedDoctor != null && _selectedDate != null && _selectedTime.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.lightGreen,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary, width: 1.5),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: const [
                        Icon(Icons.check_circle_outline, color: AppColors.primary, size: 18),
                        SizedBox(width: 8),
                        Text('Booking Summary', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14)),
                      ]),
                      const Divider(height: 16, color: Color(0xFFC8E6C9)),
                      _summaryRow(Icons.apartment_rounded, 'Hospital', currentHospitalName ?? 'Medical Center'),
                      _summaryRow(Icons.person, 'Doctor', 'Dr. ${_selectedDoctor!['name']} (${_selectedDoctor!['doctorProfile']?['specialty'] ?? 'Specialist'})'),
                      _summaryRow(Icons.calendar_today, 'Date', '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
                      _summaryRow(Icons.access_time, 'Time', _selectedTime),
                      _summaryRow(Icons.medical_services_outlined, 'Type', _type == 'in_person' ? 'In Person Visit' : 'Telemedicine Video Call'),
                    ]),
                  ),
                ],

                const SizedBox(height: 24),
                PharmaButton(
                  label: 'Confirm Appointment',
                  onPressed: _book,
                  isLoading: _booking,
                  icon: Icons.check,
                ),
                const SizedBox(height: 30),
              ],
            ]),
          ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark))),
      ]),
    );
  }
}
