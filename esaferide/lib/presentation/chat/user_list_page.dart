import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../data/services/chat_service.dart';
import 'chat_page.dart';

/// Shows only the contacts the current user has active chats with in the
/// last 48 hours. This avoids exposing all users in the system to drivers.
class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  final _chatSvc = ChatService();
  final Map<String, String> _nameCache = {};
  final Set<String> _resolving = {};

  Future<void> _resolveName(String uid) async {
    if (_nameCache.containsKey(uid) || _resolving.contains(uid)) return;
    _resolving.add(uid);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final name = (doc.data()?['displayName'] as String?) ?? '';
      if (!mounted) return;
      setState(() => _nameCache[uid] = name.isNotEmpty ? name : uid);
    } finally {
      _resolving.remove(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Sign in required'));

    // show only chats with recent activity (48 hours)
    final cutoff = DateTime.now().subtract(const Duration(days: 2));

    return Scaffold(
      appBar: AppBar(title: const Text('Recent contacts')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _chatSvc.streamChatsForUser(uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Error'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs.where((d) {
            final data = d.data() as Map<String, dynamic>?;
            if (data == null) return false;
            final ts = data['lastMessageTime'] as Timestamp?;
            if (ts == null) {
              return true; // include chats without timestamp for now
            }
            return ts.toDate().isAfter(cutoff);
          }).toList();

          if (docs.isEmpty) {
            return const Center(child: Text('No recent contacts'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data() as Map<String, dynamic>;
              final parts = List<String>.from(data['participants'] ?? []);
              final other = parts.where((p) => p != uid).isNotEmpty
                  ? parts.where((p) => p != uid).first
                  : parts.first;
              final last = data['lastMessage'] as String? ?? '';
              final ts = data['lastMessageTime'] as Timestamp?;

              if (!_nameCache.containsKey(other) &&
                  !_resolving.contains(other)) {
                _resolveName(other);
              }

              final display = _nameCache[other] ?? other;
              final subtitle = last.isNotEmpty
                  ? last
                  : (ts != null
                        ? 'Connected ${_ageLabel(ts.toDate())} ago'
                        : 'Tap to chat');

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withAlpha((0.1 * 255).round()),
                  child: Text(
                    display.isNotEmpty ? display[0].toUpperCase() : '?',
                  ),
                ),
                title: Text(display),
                subtitle: Text(subtitle),
                onTap: () async {
                  final chatId = d.id;
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        chatId: chatId,
                        otherUserId: other,
                        otherUserName: display,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _ageLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
