import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:esaferide/presentation/shared/completed_item_helpers.dart';

class CompletedJobsPage extends StatefulWidget {
  const CompletedJobsPage({super.key});

  @override
  State<CompletedJobsPage> createState() => _CompletedJobsPageState();
}

class _CompletedJobsPageState extends State<CompletedJobsPage> {
  final Map<String, String> _nameCache = {};
  final Set<String> _resolving = {};

  /// Resolve student name by ID, with cache
  Future<void> _resolveStudentName(String id) async {
    if (_nameCache.containsKey(id) || _resolving.contains(id)) return;
    _resolving.add(id);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('students')
          .doc(id)
          .get();
      final data = doc.data();
      if (!mounted) {
        return;
      }
      setState(() {
        _nameCache[id] = (data?['fullName'] as String?) ?? 'Student';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _nameCache[id] = 'Student';
      });
    } finally {
      _resolving.remove(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Sign in required')));
    }

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
            debugPrint('CompletedJobsPage stream error: ${snap.error}');
            return Center(child: Text('Error loading completed jobs'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No completed jobs'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            separatorBuilder: (_, __) => const Divider(),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              try {
                final d = docs[index];
                final data = d.data() as Map<String, dynamic>;
                final studentId = data['studentId'] as String? ?? '';
                final fareRaw = data['fare'];
                final duration = (data['durationSeconds'] as int?) ?? 0;
                final created = data['createdAt'] as Timestamp?;

                // Resolve student name async but safely
                if (!_nameCache.containsKey(studentId) &&
                    !_resolving.contains(studentId)) {
                  _resolveStudentName(studentId);
                }
                final studentName = _nameCache[studentId] ?? 'Student';
                final timeStr = created != null
                    ? TimeOfDay.fromDateTime(created.toDate()).format(context)
                    : '';

                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      studentName.isNotEmpty
                          ? studentName[0].toUpperCase()
                          : '?',
                    ),
                  ),
                  title: Text(studentName),
                  subtitle: Text(
                    'Duration: ${duration}s • Fare: ${formatCurrency(fareRaw)}',
                  ),
                  trailing: Text(timeStr, style: const TextStyle(fontSize: 12)),
                );
              } catch (e, st) {
                debugPrint('completed_jobs itemBuilder error: $e\n$st');
                return Card(
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Error rendering completed job'),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}
