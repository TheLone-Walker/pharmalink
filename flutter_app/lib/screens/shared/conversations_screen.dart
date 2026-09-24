import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabController;

  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _contacts = [];
  bool _loading = true;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _searchCtrl.addListener(() {
      setState(() => _search = _searchCtrl.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final [convRes, contRes] = await Future.wait([
        _api.get('/chat/conversations'),
        _api.get('/chat/contacts'),
      ]);

      setState(() {
        _conversations = (convRes.data['data'] as List? ?? []).cast<Map<String, dynamic>>();
        _contacts = (contRes.data['data'] as List? ?? []).cast<Map<String, dynamic>>();
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Support & Messages'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.chat_bubble_outline, size: 18), text: 'Active Chats'),
            Tab(icon: Icon(Icons.people_alt_outlined, size: 18), text: 'Contacts Directory'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search chats by name, role, pharmacy, or doctor...',
                prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => _searchCtrl.clear())
                    : null,
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildActiveChats(),
                      _buildContactsDirectory(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ─── ACTIVE CHATS TAB ──────────────────────────────────────────────────────
  Widget _buildActiveChats() {
    final filtered = _conversations.where((c) {
      if (_search.isEmpty) return true;
      final name = (c['name'] ?? '').toString().toLowerCase();
      final subtitle = (c['subtitle'] ?? '').toString().toLowerCase();
      final lastMsg = (c['lastMessage'] ?? '').toString().toLowerCase();
      return name.contains(_search) || subtitle.contains(_search) || lastMsg.contains(_search);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.lightGreen, shape: BoxShape.circle),
              child: const Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            const Text('No Active Conversations Yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Select a contact from the Directory tab to start chatting.', style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              icon: const Icon(Icons.contacts, size: 16),
              label: const Text('Browse Contacts Directory'),
              onPressed: () => _tabController.animateTo(1),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 70),
      itemBuilder: (ctx, i) {
        final c = filtered[i];
        final name = c['name'] ?? 'User';
        final subtitle = c['subtitle'] ?? '';
        final lastMsg = c['lastMessage'] ?? '';
        final isUnread = c['unread'] == true;

        return ListTile(
          tileColor: Colors.white,
          leading: CircleAvatar(
            backgroundColor: AppColors.lightGreen,
            radius: 22,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 16),
            ),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: TextStyle(fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600, fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                child: Text(subtitle, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
            ],
          ),
          subtitle: Text(
            lastMsg,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: isUnread ? Colors.black87 : AppColors.textGrey, fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400),
          ),
          trailing: isUnread
              ? Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle))
              : const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InAppChatScreen(
                  receiverId: c['userId'],
                  receiverName: name,
                  receiverRole: c['role'] ?? 'user',
                ),
              ),
            ).then((_) => _loadData());
          },
        );
      },
    );
  }

  // ─── CONTACTS DIRECTORY TAB ────────────────────────────────────────────────
  Widget _buildContactsDirectory() {
    final filtered = _contacts.where((c) {
      if (_search.isEmpty) return true;
      final name = (c['name'] ?? '').toString().toLowerCase();
      final subtitle = (c['subtitle'] ?? '').toString().toLowerCase();
      final phone = (c['phone'] ?? '').toString().toLowerCase();
      return name.contains(_search) || subtitle.contains(_search) || phone.contains(_search);
    }).toList();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 70),
      itemBuilder: (ctx, i) {
        final c = filtered[i];
        final name = c['name'] ?? 'Contact';
        final role = c['role'] ?? 'user';
        final subtitle = c['subtitle'] ?? '';

        Color iconBg = AppColors.lightGreen;
        Color iconColor = AppColors.primary;
        IconData icon = Icons.person_outline;

        if (role == 'doctor') {
          icon = Icons.medical_services_outlined;
          iconBg = const Color(0xFFEFF6FF);
          iconColor = const Color(0xFF2563EB);
        } else if (role == 'pharmacist') {
          icon = Icons.local_pharmacy_outlined;
          iconBg = const Color(0xFFF0FDF4);
          iconColor = const Color(0xFF16A34A);
        } else if (role == 'delivery_driver') {
          icon = Icons.two_wheeler;
          iconBg = const Color(0xFFFEF3C7);
          iconColor = const Color(0xFFD97706);
        } else if (role == 'admin') {
          icon = Icons.support_agent;
          iconBg = const Color(0xFFEDE9FE);
          iconColor = const Color(0xFF7C3AED);
        }

        return ListTile(
          tileColor: Colors.white,
          leading: CircleAvatar(
            backgroundColor: iconBg,
            radius: 22,
            child: Icon(icon, color: iconColor, size: 20),
          ),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
          trailing: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.chat_bubble_outline, size: 12),
            label: const Text('Chat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InAppChatScreen(
                    receiverId: c['id'],
                    receiverName: name,
                    receiverRole: role,
                  ),
                ),
              ).then((_) => _loadData());
            },
          ),
        );
      },
    );
  }
}
