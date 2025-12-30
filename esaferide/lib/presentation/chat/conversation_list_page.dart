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
  final ChatService _svc = ChatService();
  final Map<String, String> _nameCache = {};
  final Set<String> _resolving = {};

  /// Resolve the display name for a user UID
  Future<void> _resolveName(String uid) async {
    if (_nameCache.containsKey(uid) || _resolving.contains(uid)) return;
    _resolving.add(uid);

    try {
      // Try common places where a user's display name might live.
      String name = '';

      // 1) users collection (most universal)
      final uDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      name = (uDoc.data()?['displayName'] as String?) ?? '';

      // 2) students collection
      if (name.isEmpty) {
        final sDoc = await FirebaseFirestore.instance
            .collection('students')
            .doc(uid)
            .get();
        name = (sDoc.data()?['fullName'] as String?) ?? '';
      }

      // 3) drivers collection
      if (name.isEmpty) {
        final dDoc = await FirebaseFirestore.instance
            .collection('drivers')
            .doc(uid)
            .get();
        name = (dDoc.data()?['fullName'] as String?) ?? '';
      }

      if (!mounted) return;
      setState(() {
        _nameCache[uid] = name.isNotEmpty ? name : uid;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _nameCache[uid] = uid;
      });
    } finally {
      _resolving.remove(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Sign in required')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Conversations')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _svc.streamChatsForUser(uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading chats: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Only show chats with recent messages (last 2 days)
          final cutoff = DateTime.now().subtract(const Duration(days: 2));
          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) return false;
            final ts = data['lastMessageTime'] as Timestamp?;
            if (ts == null) return true; // include chat without timestamp
            return ts.toDate().isAfter(cutoff);
          }).toList();

          if (docs.isEmpty) {
            return const Center(child: Text('No recent conversations'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            separatorBuilder: (_, __) => const Divider(),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final participants = List<String>.from(
                data['participants'] ?? [],
              );
              final other = participants.firstWhere(
                (p) => p != uid,
                orElse: () => participants.first,
              );

              final lastMessage = data['lastMessage'] as String? ?? '';
              final ts = data['lastMessageTime'] as Timestamp?;
              final timeStr = ts != null
                  ? _timeLabel(ts.toDate(), context)
                  : '';
              final subtitle = lastMessage.isNotEmpty
                  ? lastMessage
                  : (ts != null
                        ? 'Connected ${_ageLabel(ts.toDate())} ago'
                        : 'Tap to chat');

              // Resolve the other user's name asynchronously
              if (!_nameCache.containsKey(other) &&
                  !_resolving.contains(other)) {
                _resolveName(other);
              }

              final displayName =
                  data['title'] as String? ?? _nameCache[other] ?? other;

              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  ),
                ),
                title: Text(displayName),
                subtitle: Text(subtitle),
                trailing: Text(timeStr, style: const TextStyle(fontSize: 12)),
                onTap: () async {
                  // Capture navigator before any await to avoid using BuildContext
                  // across async gaps (lint: use_build_context_synchronously).
                  final navigator = Navigator.of(context);

                  // Ensure we have the resolved human-readable name before opening chat
                  if (!_nameCache.containsKey(other) &&
                      !_resolving.contains(other)) {
                    await _resolveName(other);
                  }

                  if (!mounted) return;

                  final resolved =
                      _nameCache[other] ?? (data['title'] as String?) ?? other;
                  navigator.push(
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        chatId: doc.id,
                        otherUserId: other,
                        otherUserName: resolved,
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

  /// Format time for display
  String _timeLabel(DateTime dt, BuildContext context) {
    final t = TimeOfDay.fromDateTime(dt);
    return t.format(context);
  }

  /// Calculate age label like 2h or 3d
  String _ageLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
