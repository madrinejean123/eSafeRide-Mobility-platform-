import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:esaferide/presentation/shared/app_scaffold.dart';
import 'package:esaferide/presentation/shared/styles.dart';
import 'package:esaferide/presentation/admin/admin_gate.dart';

class AdminAuditPage extends StatelessWidget {
  const AdminAuditPage({super.key});

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance.collection('admin_audit');
    return AdminGate(
      child: AppScaffold(
        title: 'Admin • Audit',
        child: StreamBuilder<QuerySnapshot>(
          stream: col.orderBy('timestamp', descending: true).snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return Center(
                child: Text('No audit entries', style: sectionTitleStyle()),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, i) {
                final d = docs[i];
                final data = d.data() as Map<String, dynamic>;
                final ts = data['timestamp'] as Timestamp?;
                final when = ts != null
                    ? ts.toDate().toLocal().toString()
                    : '—';
                return ListTile(
                  title: Text(
                    '${data['action'] ?? 'action'} • ${data['driverId'] ?? data['targetId'] ?? ''}',
                  ),
                  subtitle: Text(
                    'By: ${data['adminId'] ?? '—'} • $when\n${data['reason'] ?? ''}',
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
