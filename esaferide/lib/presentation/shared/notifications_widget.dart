import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// NotificationsList reads notifications from `drivers/{uid}/notifications`.
/// Accepts optional `firestore` and `userId` for testability.
class NotificationsList extends StatefulWidget {
  final FirebaseFirestore? firestore;
  final String? userId;

  const NotificationsList({super.key, this.firestore, this.userId});

  @override
  State<NotificationsList> createState() => _NotificationsListState();
}

class _NotificationsListState extends State<NotificationsList> {
  FirebaseFirestore get _fs => widget.firestore ?? FirebaseFirestore.instance;
  String? get _userId =>
      widget.userId ?? FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final uid = _userId;
    if (uid == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Not signed in'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                // optional: navigate to sign-in
              },
              child: const Text('Sign in'),
            ),
          ],
        ),
      );
    }

    final col = _fs
        .collection('drivers')
        .doc(uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: col.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(child: Text('Error loading notifications'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No notifications'));
        }
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data() as Map<String, dynamic>;
            final title = data['title'] ?? 'Notification';
            final body = data['body'] ?? '';
            final read = data['read'] == true;
            final ts = data['timestamp'] as Timestamp?;
            final time = ts?.toDate();
            return ListTile(
              tileColor: read ? null : Colors.grey.shade100,
              title: Text(title),
              subtitle: Text(body),
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!read)
                    const Icon(Icons.fiber_new, color: Colors.green)
                  else
                    const SizedBox.shrink(),
                  if (time != null)
                    Text(
                      _formatTime(time),
                      style: const TextStyle(fontSize: 11),
                    ),
                ],
              ),
              onTap: () async {
                if (!read) {
                  await d.reference.update({'read': true});
                }
                if (!mounted) {
                  return;
                }
                // maybe navigate to details or open a modal
                showDialog<void>(
                  context: this.context,
                  builder: (ctx) => AlertDialog(
                    title: Text(title),
                    content: Text(body),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
              onLongPress: () async {
                // allow mark/unmark read
                await d.reference.update({'read': !read});
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(read ? 'Marked unread' : 'Marked read'),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
