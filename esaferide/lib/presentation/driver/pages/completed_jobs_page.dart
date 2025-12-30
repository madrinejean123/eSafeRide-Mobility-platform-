import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CompletedJobsPage extends StatelessWidget {
  const CompletedJobsPage({super.key});

  Future<String> _resolveStudentName(String id) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('students')
          .doc(id)
          .get();
      final data = doc.data();
      if (data == null) return id;
      return (data['fullName'] as String?) ?? id;
    } catch (_) {
      return id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Sign in required'));

    final tripsCol = FirebaseFirestore.instance
        .collection('trips')
        .where('driverId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50);

    return Scaffold(
      appBar: AppBar(title: const Text('Completed Jobs')),
      body: StreamBuilder<QuerySnapshot>(
        stream: tripsCol.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            // Show the error details in logs and surface a friendlier message
            debugPrint('CompletedJobsPage stream error: ${snap.error}');
            return Center(
              child: Text('Error loading completed jobs: ${snap.error}'),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No completed jobs'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data() as Map<String, dynamic>;
              final studentId = data['studentId'] as String? ?? '';
              final fare = data['fare']?.toString() ?? '';
              final duration = (data['durationSeconds'] as int?) ?? 0;
              final created = data['createdAt'] as Timestamp?;

              return FutureBuilder<String>(
                future: _resolveStudentName(studentId),
                builder: (context, nameSnap) {
                  final name = nameSnap.data ?? studentId;
                  final timeStr = created != null
                      ? TimeOfDay.fromDateTime(created.toDate()).format(context)
                      : '';
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                      ),
                    ),
                    title: Text(name),
                    subtitle: Text('Duration: ${duration}s • Fare: \$$fare'),
                    trailing: Text(
                      timeStr,
                      style: const TextStyle(fontSize: 12),
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
