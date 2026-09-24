import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../utils/constants.dart';

class InAppChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String? receiverRole;
  final String? orderId;

  const InAppChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    this.receiverRole,
    this.orderId,
  });

  @override
  State<InAppChatScreen> createState() => _InAppChatScreenState();
}

class _InAppChatScreenState extends State<InAppChatScreen> {
  final _api = ApiService();
  final _socket = SocketService();
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _listenSocket();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final meRes = await _api.get('/users/me');
      _currentUserId = meRes.data['data']['id'];
      final res = await _api.get('/chat/messages/${widget.receiverId}');
      setState(() => _messages = res.data['data'] ?? []);
    } catch (_) {} finally {
      setState(() => _loading = false);
      _scrollDown();
    }
  }

  void _listenSocket() {
    _socket.onChatMessage((data) {
      if (data['senderId'] == widget.receiverId) {
        setState(() => _messages.add(data));
        _scrollDown();
      }
    });
  }

  void _scrollDown() => Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() { _sending = true; });
    _msgCtrl.clear();
    try {
      final res = await _api.post('/chat/messages', data: {
        'receiverId': widget.receiverId,
        'content': text,
        if (widget.orderId != null) 'orderId': widget.orderId,
      });
      setState(() => _messages.add(res.data['data']));
      _scrollDown();
    } catch (_) {} finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          CircleAvatar(
            radius: 18, backgroundColor: Colors.white,
            child: Text(widget.receiverName[0],
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.receiverName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            if (widget.receiverRole != null)
              Text(widget.receiverRole!.replaceAll('_', ' '),
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ]),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.phone_outlined), onPressed: () {}),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _messages.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Start a conversation with ${widget.receiverName}',
                        style: const TextStyle(color: AppColors.textGrey), textAlign: TextAlign.center),
                    ]))
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final m = _messages[i];
                        final isMe = m['senderId'] == _currentUserId;
                        final time = DateTime.tryParse(m['createdAt'] ?? '');
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                            decoration: BoxDecoration(
                              color: isMe ? AppColors.primary : AppColors.lightGreen,
                              borderRadius: BorderRadius.circular(14).copyWith(
                                bottomRight: isMe ? const Radius.circular(0) : null,
                                bottomLeft: isMe ? null : const Radius.circular(0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Text(m['content'] ?? '',
                                  style: TextStyle(
                                    color: isMe ? Colors.white : AppColors.textDark,
                                    fontSize: 13,
                                  )),
                                const SizedBox(height: 3),
                                if (time != null)
                                  Text('${time.hour.toString().padLeft(2,'0')}:${time.minute.toString().padLeft(2,'0')}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isMe ? Colors.white60 : AppColors.textGrey,
                                    )),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.lightGreen),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.lightGreen),
                  ),
                  filled: true, fillColor: AppColors.fieldBg,
                ),
                onSubmitted: (_) => _send(),
                maxLines: null,
                textInputAction: TextInputAction.send,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 44, height: 44,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: _sending
                    ? const Padding(padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
