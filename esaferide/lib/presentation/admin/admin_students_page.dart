import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:esaferide/presentation/shared/app_scaffold.dart';
import 'package:esaferide/presentation/shared/styles.dart';
import 'package:esaferide/presentation/admin/admin_gate.dart';

class AdminStudentsPage extends StatelessWidget {
  const AdminStudentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      child: AppScaffold(
        title: 'Admin • Students',
        child: const AdminStudentsList(),
      ),
    );
  }
}

class AdminStudentsList extends StatefulWidget {
  const AdminStudentsList({super.key});

  @override
  State<AdminStudentsList> createState() => _AdminStudentsListState();
}

class _AdminStudentsListState extends State<AdminStudentsList> {
  final _col = FirebaseFirestore.instance.collection('students');

  Future<void> _showStudentDetails(
    BuildContext ctx,
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final doc = await _col.doc(id).get();
      final ddata = (doc.exists && doc.data() != null)
          ? (doc.data() as Map<String, dynamic>)
          : data;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dctx) => AlertDialog(
          title: Text(
            ddata['name'] ?? ddata['fullName'] ?? 'Student',
            style: sectionTitleStyle(),
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: styledCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (ddata['photo'] != null) ...[
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            ddata['photo'],
                            height: 160,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text('Name: ${ddata['fullName'] ?? ddata['name'] ?? '—'}'),
                    const SizedBox(height: 6),
                    Text('Reg#: ${ddata['regNumber'] ?? '—'}'),
                    const SizedBox(height: 6),
                    Text('Course: ${ddata['course'] ?? ddata['class'] ?? '—'}'),
                    const SizedBox(height: 6),
                    Text('Year: ${ddata['year'] ?? '—'}'),
                    const SizedBox(height: 6),
                    Text('Phone: ${ddata['phone'] ?? '—'}'),
                    const SizedBox(height: 12),
                    if (ddata['accessibility'] != null) ...[
                      Text('Accessibility Needs', style: sectionTitleStyle()),
                      const SizedBox(height: 6),
                      Text(ddata['accessibility'].toString()),
                      const SizedBox(height: 12),
                    ],
                    Text('Emergency Contact', style: sectionTitleStyle()),
                    const SizedBox(height: 6),
                    Text(
                      'Name: ${ddata['emergencyName'] ?? ddata['emergencyContact']?['name'] ?? '—'}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Phone: ${ddata['emergencyPhone'] ?? ddata['emergencyContact']?['phone'] ?? '—'}',
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error loading student details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _col.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data() as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: styledCard(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: data['photo'] != null
                        ? NetworkImage(data['photo'])
                        : null,
                    child: data['photo'] == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(data['name'] ?? data['fullName'] ?? 'Unnamed'),
                  subtitle: Text(
                    'Class: ${data['class'] ?? ''} • Special needs: ${data['specialNeeds'] ?? '—'}',
                  ),
                  trailing: ElevatedButton(
                    onPressed: () => _showStudentDetails(context, d.id, data),
                    style: primaryButtonStyle(),
                    child: const Text('View'),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
