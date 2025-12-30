import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../data/services/chat_service.dart';
import 'chat_page.dart';

class ConversationListPage extends StatefulWidget {
  const ConversationListPage({super.key});

  @override
  State<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends State<ConversationListPage> {
  final _svc = ChatService();
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
      setState(() {
        _nameCache[uid] = name.isNotEmpty ? name : uid;
      });
    } finally {
      _resolving.remove(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Sign in required'));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Conversations')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _svc.streamChatsForUser(uid),
        builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text('Error'));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final cutoff = DateTime.now().subtract(const Duration(days: 2));
          final docs = snap.data!.docs.where((d) {
            final data = d.data() as Map<String, dynamic>?;
            if (data == null) return false;
            final ts = data['lastMessageTime'] as Timestamp?;
            if (ts == null) return true;
            return ts.toDate().isAfter(cutoff);
          }).toList();
          if (docs.isEmpty) {
            return const Center(child: Text('No recent conversations'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data() as Map<String, dynamic>;
              final participants = List<String>.from(
                data['participants'] ?? [],
              );
              final other = participants.where((p) => p != uid).isNotEmpty
                  ? participants.where((p) => p != uid).first
                  : participants.first;
              final last = data['lastMessage'] as String? ?? '';
              final ts = data['lastMessageTime'] as Timestamp?;
              final timeStr = ts != null
                  ? _timeLabel(ts.toDate(), context)
                  : '';
              final subtitle = last.isNotEmpty
                  ? last
                  : (ts != null
                        ? 'Connected ${_ageLabel(ts.toDate())} ago'
                        : 'Tap to chat');

              if (!_nameCache.containsKey(other) &&
                  !_resolving.contains(other)) {
                _resolveName(other);
              }

              final display =
                  data['title'] as String? ?? _nameCache[other] ?? other;

              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    display.isNotEmpty ? display[0].toUpperCase() : '?',
                  ),
                ),
                title: Text(display),
                subtitle: Text(subtitle),
                trailing: Text(timeStr, style: const TextStyle(fontSize: 12)),
                onTap: () async {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        chatId: d.id,
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

  String _timeLabel(DateTime dt, BuildContext context) {
    final t = TimeOfDay.fromDateTime(dt);
    return t.format(context);
  }

  String _ageLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
