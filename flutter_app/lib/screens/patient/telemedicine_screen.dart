import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';

class TelemedicineScreen extends StatefulWidget {
  final String? appointmentId;
  final String? doctorId;
  final String? doctorName;
  const TelemedicineScreen({super.key, this.appointmentId, this.doctorId, this.doctorName});
  @override
  State<TelemedicineScreen> createState() => _TelemedicineScreenState();
}

class _TelemedicineScreenState extends State<TelemedicineScreen> {
  final _api = ApiService();
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _loading = false;
  bool _micOn = true;
  bool _camOn = true;
  bool _inCall = false;

  @override
  void initState() {
    super.initState();
    _messages.add({
      'role': 'system',
      'text': 'Telemedicine session started with Dr. ${widget.doctorName ?? 'Doctor'}. '
          'You can chat or start a video call.',
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollDown() => Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _loading) return;
    setState(() {
      _messages.add({'role': 'patient', 'text': text});
      _loading = true;
    });
    _msgCtrl.clear();
    _scrollDown();
    try {
      final res = await _api.post('/chat/gemini', data: {
        'message': text,
        'context': 'This is a telemedicine consultation. The patient is speaking with a doctor.',
      });
      setState(() => _messages.add({'role': 'doctor', 'text': res.data['data']['reply']}));
    } catch (_) {
      setState(() => _messages.add({'role': 'doctor', 'text': 'Unable to connect to doctor. Please try again.'}));
    } finally {
      setState(() => _loading = false);
      _scrollDown();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dr. ${widget.doctorName ?? 'Doctor'}'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.green[700], borderRadius: BorderRadius.circular(20)),
            child: const Row(children: [
              Icon(Icons.circle, color: Colors.greenAccent, size: 8),
              SizedBox(width: 4),
              Text('Online', style: TextStyle(color: Colors.white, fontSize: 12)),
            ]),
          ),
        ],
      ),
      body: Column(children: [
        // Video call area
        if (_inCall)
          Container(
            height: 220,
            color: Colors.black,
            child: Stack(children: [
              Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircleAvatar(
                  radius: 40, backgroundColor: AppColors.primary,
                  child: Text((widget.doctorName ?? 'D')[0],
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                const SizedBox(height: 8),
                Text('Dr. ${widget.doctorName ?? 'Doctor'}',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                const Text('00:03:42', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
              // Self preview
              Positioned(
                bottom: 12, right: 12,
                child: Container(
                  width: 70, height: 90,
                  decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(8)),
                  child: const Center(child: Icon(Icons.person, color: Colors.white54, size: 28)),
                ),
              ),
              // Call controls
              Positioned(
                bottom: 12, left: 0, right: 90,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _callBtn(Icons.mic, _micOn, () => setState(() => _micOn = !_micOn), Colors.grey[700]!),
                  const SizedBox(width: 12),
                  _callBtn(Icons.videocam, _camOn, () => setState(() => _camOn = !_camOn), Colors.grey[700]!),
                  const SizedBox(width: 12),
                  _callBtn(Icons.call_end, true, () => setState(() => _inCall = false), Colors.red),
                ]),
              ),
            ]),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lightGreen,
              border: Border(bottom: BorderSide(color: AppColors.lightGreen)),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 24, backgroundColor: AppColors.primary,
                child: Text((widget.doctorName ?? 'D')[0],
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Dr. ${widget.doctorName ?? 'Doctor'}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const Text('General Practitioner', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
              ])),
              ElevatedButton.icon(
                onPressed: () => setState(() => _inCall = true),
                icon: const Icon(Icons.video_call, size: 18),
                label: const Text('Start Call', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ]),
          ),

        // Chat messages
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_loading ? 1 : 0),
            itemBuilder: (_, i) {
              if (_loading && i == _messages.length) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(12)),
                    child: const SizedBox(width: 40, height: 16,
                      child: Row(children: [
                        _Dot(delay: 0), SizedBox(width: 4),
                        _Dot(delay: 150), SizedBox(width: 4),
                        _Dot(delay: 300),
                      ])),
                  ),
                );
              }
              final m = _messages[i];
              if (m['role'] == 'system') {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                  child: Text(m['text'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textGrey), textAlign: TextAlign.center),
                );
              }
              final isPatient = m['role'] == 'patient';
              return Align(
                alignment: isPatient ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                  decoration: BoxDecoration(
                    color: isPatient ? AppColors.primary : AppColors.lightGreen,
                    borderRadius: BorderRadius.circular(14).copyWith(
                      bottomRight: isPatient ? const Radius.circular(0) : null,
                      bottomLeft: isPatient ? null : const Radius.circular(0),
                    ),
                  ),
                  child: Column(crossAxisAlignment: isPatient ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
                    Text(isPatient ? 'You' : 'Dr. ${widget.doctorName ?? 'Doctor'}',
                      style: TextStyle(fontSize: 10, color: isPatient ? Colors.white70 : AppColors.textGrey, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(m['text'] ?? '', style: TextStyle(color: isPatient ? Colors.white : AppColors.textDark, fontSize: 13)),
                  ]),
                ),
              );
            },
          ),
        ),

        // Input bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2))],
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.lightGreen)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.lightGreen)),
                  filled: true, fillColor: AppColors.fieldBg,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 44, height: 44,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _callBtn(IconData icon, bool active, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(active ? icon : _offIcon(icon), color: Colors.white, size: 20),
      ),
    );
  }

  IconData _offIcon(IconData icon) {
    if (icon == Icons.mic) return Icons.mic_off;
    if (icon == Icons.videocam) return Icons.videocam_off;
    return icon;
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
  );
}
