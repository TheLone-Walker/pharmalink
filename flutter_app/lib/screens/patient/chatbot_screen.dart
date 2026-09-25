import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../shared/payment_screen.dart';
import 'patient_appointments_screen.dart';
import 'my_orders_screen.dart';
import 'night_guard_screen.dart';
import 'digital_receipt_screen.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});
  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _api = ApiService();
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _loading = false;

  final List<String> _quickPrompts = [
    '📅 Book Doctor Appointment',
    '💊 Order Medication',
    '🌙 24/7 Night Guard & Urgences',
    '🦟 Malaria Treatment Protocol',
    '🧾 My Payment Receipts',
    '📱 Telemedicine Video Call',
    '🏥 Find Doctors at Hôpital Central',
    '💰 Compare Coartem Prices',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add({
      'role': 'bot',
      'text': 'Hello! I\'m PharmaLink Autonomous Clinical Agent 🩺.\n\nI can:\n• **Book doctor appointments** step-by-step with your preferred hospital and exact time slot.\n• **Order medications** with live pharmacy price comparisons.\n• **Access Night Guard pharmacies & 24/7 emergency services**.\n• Provide clinical guidance & digital receipts for all payments.',
      'suggestions': [
        '📅 Book Doctor Appointment',
        '💊 Order Medication',
        '🌙 24/7 Night Guard & Urgences',
        '🦟 Malaria Symptoms & Care',
      ],
    });
  }

  Future<void> _send([String? customText]) async {
    final text = (customText ?? _ctrl.text).trim();
    if (text.isEmpty || _loading) return;
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _loading = true;
    });
    if (customText == null) _ctrl.clear();
    _scrollDown();
    try {
      final historyPayload = _messages
          .where((m) => m['text'] != null && (m['text'] as String).isNotEmpty)
          .map((m) => {'role': m['role'] == 'user' ? 'user' : 'model', 'text': m['text']})
          .toList();

      final res = await _api.post('/chat/gemini', data: {
        'message': text,
        'history': historyPayload,
      });
      final data = res.data['data'] as Map<String, dynamic>;
      final reply = data['reply'] ?? 'Here is what I found for you.';
      final action = data['action'];
      final suggestions = (data['suggestions'] as List?)?.map((e) => e.toString()).toList() ?? [];

      setState(() => _messages.add({
        'role': 'bot',
        'text': reply,
        'action': action,
        'suggestions': suggestions,
      }));
    } catch (_) {
      setState(() => _messages.add({
            'role': 'bot',
            'text': 'I encountered a brief connection issue. Please verify your internet or try asking again.',
          }));
    } finally {
      setState(() => _loading = false);
      _scrollDown();
    }
  }

  void _scrollDown() => Future.delayed(const Duration(milliseconds: 100), () {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PharmaLink AI Health',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(
                      'Clinical Assistant Active',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Medical disclaimer bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFEFF6FF),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI guidance is informational. Consult a licensed doctor for prescriptions.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          // Message stream
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: _messages.length + (_loading ? 1 : 0),
              itemBuilder: (_, i) {
                if (_loading && i == _messages.length) return _typingIndicator();
                final m = _messages[i];
                final isUser = m['role'] == 'user';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUser) ...[
                        Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.only(right: 8, top: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primary),
                        ),
                      ],
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                          decoration: BoxDecoration(
                            color: isUser ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(isUser ? 18 : 4),
                              bottomRight: Radius.circular(isUser ? 4 : 18),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x08000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                            border: isUser ? null : Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m['text'] ?? '',
                                style: GoogleFonts.plusJakartaSans(
                                  color: isUser ? Colors.white : AppColors.textDark,
                                  fontSize: 13.5,
                                  height: 1.4,
                                  fontWeight: isUser ? FontWeight.w500 : FontWeight.w400,
                                ),
                              ),

                              // Interactive Clickable Option Chips
                              if (!isUser && (_getSuggestionsForMessage(m).isNotEmpty)) ...[
                                const SizedBox(height: 10),
                                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                const SizedBox(height: 10),
                                Text(
                                  'Tap an option to proceed:',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _getSuggestionsForMessage(m)
                                      .map((chip) => _buildClickableOptionChip(chip))
                                      .toList(),
                                ),
                              ],

                              if (m['action'] != null) ...[
                                const SizedBox(height: 12),
                                InkWell(
                                  onTap: () {
                                    final act = m['action'];
                                    if (act['type'] == 'appointment') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const PatientAppointmentsScreen(),
                                        ),
                                      );
                                    } else if (act['type'] == 'order') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PaymentScreen(
                                            orderId: act['id']?.toString(),
                                            orderType: 'delivery',
                                            pharmacyId: act['data']?['pharmacyId'] ?? '',
                                            items: (act['data']?['items'] as List?)?.map((it) => {
                                              'medicationId': it['medicationId'] ?? it['id'],
                                              'quantity': it['quantity'] ?? 1,
                                            }).toList() ?? [],
                                            totalFcfa: double.tryParse(act['totalFcfa']?.toString() ?? '0') ?? 0,
                                          ),
                                        ),
                                      );
                                    } else if (act['type'] == 'night_guard') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const NightGuardScreen(),
                                        ),
                                      );
                                    } else if (act['type'] == 'receipt') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => DigitalReceiptScreen(
                                            orderId: act['id'] ?? '',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      gradient: AppColors.primaryGradient,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x220D6E48),
                                          blurRadius: 8,
                                          offset: Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          m['action']['type'] == 'appointment'
                                              ? Icons.calendar_month_rounded
                                              : Icons.shopping_bag_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            m['action']['title'] ?? 'View Details',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 12),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Quick Prompt suggestions
          Container(
            height: 38,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _quickPrompts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final prompt = _quickPrompts[i];
                return ActionChip(
                  label: Text(
                    prompt,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  backgroundColor: const Color(0xFFF0FDF4),
                  side: const BorderSide(color: Color(0xFFA7F3D0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onPressed: () => _send(prompt),
                );
              },
            ),
          ),

          // Bottom Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: _ctrl,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: 'Type your health question...',
                          hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textGrey),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _send(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x280D6E48),
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
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

  Widget _typingIndicator() {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFD1FAE5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primary),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              3,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<String> _getSuggestionsForMessage(Map m) {
    if (m['suggestions'] is List && (m['suggestions'] as List).isNotEmpty) {
      return (m['suggestions'] as List).map((e) => e.toString()).toList();
    }
    return _extractChipsFromText(m['text'] ?? '');
  }

  List<String> _extractChipsFromText(String text) {
    if (text.isEmpty) return [];
    final lines = text.split('\n');
    final chips = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('•') || RegExp(r'^[1-9]\.').hasMatch(trimmed)) {
        final clean = trimmed
            .replaceFirst(RegExp(r'^(•|[1-9]\.)\s*'), '')
            .replaceAll('*', '')
            .split('|')[0]
            .split('—')[0]
            .split('(')[0]
            .trim();
        if (clean.length > 3 && clean.length < 42 && !chips.contains(clean)) {
          chips.add(clean);
        }
      }
    }
    final lower = text.toLowerCase();
    if (lower.contains('confirm') && lower.contains('reply') && !chips.any((c) => c.toLowerCase().contains('confirm'))) {
      chips.insert(0, '✅ Confirm');
      chips.add('❌ Cancel');
    }
    return chips.take(6).toList();
  }

  Widget _buildClickableOptionChip(String chipText) {
    final lower = chipText.toLowerCase();
    final isConfirm = lower.contains('confirm') || chipText.contains('✅');
    final isCancel = lower.contains('cancel') || chipText.contains('❌');

    final bg = isConfirm
        ? const Color(0xFF047857)
        : isCancel
            ? const Color(0xFFEF4444)
            : const Color(0xFFF0FDF4);
    final border = isConfirm
        ? const Color(0xFF059669)
        : isCancel
            ? const Color(0xFFF87171)
            : const Color(0xFFA7F3D0);
    final textCol = isConfirm || isCancel ? Colors.white : const Color(0xFF065F46);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          String sendText = chipText;
          if (isConfirm) {
            sendText = 'Confirm';
          } else if (isCancel) {
            sendText = 'Cancel';
          }
          _send(sendText);
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: (isConfirm ? const Color(0xFF047857) : Colors.black).withOpacity(0.06),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  chipText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textCol,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.touch_app_rounded, size: 13, color: textCol.withOpacity(0.8)),
            ],
          ),
        ),
      ),
    );
  }
}

