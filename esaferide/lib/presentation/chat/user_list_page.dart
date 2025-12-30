import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../data/services/chat_service.dart';
import 'chat_page.dart';

class UserListPage extends StatelessWidget {
  const UserListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Sign in required'));
    }
    final usersColl = FirebaseFirestore.instance.collection('users');
    final chatSvc = ChatService();
    return Scaffold(
      appBar: AppBar(title: const Text('Start chat')),
      body: StreamBuilder<QuerySnapshot>(
        stream: usersColl.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text('Error'));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs.where((d) => d.id != uid).toList();
          if (docs.isEmpty) {
            return const Center(child: Text('No other users'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data() as Map<String, dynamic>;
              final name = data['displayName'] as String? ?? d.id;
              return ListTile(
                leading: CircleAvatar(
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
                ),
                title: Text(name),
                subtitle: Text(data['email'] as String? ?? ''),
                onTap: () async {
                  final chatId = await chatSvc.createChatIfNotExists(
                    a: uid,
                    b: d.id,
                  );
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ChatPage(chatId: chatId, otherUserId: d.id),
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
}
