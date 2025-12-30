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

            Future<Map<String, String>> resolveNames(
              Map<String, dynamic> data,
            ) async {
              final db = FirebaseFirestore.instance;
              String adminName = data['adminId'] ?? '—';
              String subjectName = '';

              // Try resolve admin name from users collection first
              try {
                if (data['adminId'] != null) {
                  final aDoc = await db
                      .collection('users')
                      .doc(data['adminId'])
                      .get();
                  if (aDoc.exists && aDoc.data() != null) {
                    final aData = aDoc.data() as Map<String, dynamic>;
                    adminName =
                        (aData['fullName'] ??
                                aData['name'] ??
                                aData['displayName'])
                            as String? ??
                        adminName;
                  }
                }
              } catch (_) {
                // ignore
              }

              // Resolve subject (driver / student / target)
              try {
                if (data['driverId'] != null) {
                  final doc = await db
                      .collection('drivers')
                      .doc(data['driverId'])
                      .get();
                  if (doc.exists && doc.data() != null) {
                    final d = doc.data() as Map<String, dynamic>;
                    subjectName =
                        (d['fullName'] ?? d['name']) as String? ??
                        data['driverId'];
                  } else {
                    subjectName = data['driverId'];
                  }
                } else if (data['studentId'] != null) {
                  final doc = await db
                      .collection('students')
                      .doc(data['studentId'])
                      .get();
                  if (doc.exists && doc.data() != null) {
                    final d = doc.data() as Map<String, dynamic>;
                    subjectName =
                        (d['fullName'] ?? d['name']) as String? ??
                        data['studentId'];
                  } else {
                    subjectName = data['studentId'];
                  }
                } else if (data['targetId'] != null) {
                  // try drivers then students then users
                  final tryDriver = await db
                      .collection('drivers')
                      .doc(data['targetId'])
                      .get();
                  if (tryDriver.exists && tryDriver.data() != null) {
                    final d = tryDriver.data() as Map<String, dynamic>;
                    subjectName =
                        (d['fullName'] ?? d['name']) as String? ??
                        data['targetId'];
                  } else {
                    final tryStudent = await db
                        .collection('students')
                        .doc(data['targetId'])
                        .get();
                    if (tryStudent.exists && tryStudent.data() != null) {
                      final d = tryStudent.data() as Map<String, dynamic>;
                      subjectName =
                          (d['fullName'] ?? d['name']) as String? ??
                          data['targetId'];
                    } else {
                      final tryUser = await db
                          .collection('users')
                          .doc(data['targetId'])
                          .get();
                      if (tryUser.exists && tryUser.data() != null) {
                        final d = tryUser.data() as Map<String, dynamic>;
                        subjectName =
                            (d['fullName'] ?? d['name'] ?? d['displayName'])
                                as String? ??
                            data['targetId'];
                      } else {
                        subjectName = data['targetId'];
                      }
                    }
                  }
                } else if (data['userId'] != null) {
                  final doc = await db
                      .collection('users')
                      .doc(data['userId'])
                      .get();
                  if (doc.exists && doc.data() != null) {
                    final d = doc.data() as Map<String, dynamic>;
                    subjectName =
                        (d['fullName'] ?? d['name'] ?? d['displayName'])
                            as String? ??
                        data['userId'];
                  } else {
                    subjectName = data['userId'];
                  }
                } else {
                  subjectName = data['objectId']?.toString() ?? '';
                }
              } catch (_) {
                subjectName =
                    (data['driverId'] ??
                            data['studentId'] ??
                            data['targetId'] ??
                            data['userId'] ??
                            '')
                        as String;
              }

              return {'admin': adminName, 'subject': subjectName};
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final d = docs[i];
                final data = d.data() as Map<String, dynamic>;
                final ts = data['timestamp'] as Timestamp?;
                final when = ts != null
                    ? ts.toDate().toLocal().toString()
                    : '—';

                return FutureBuilder<Map<String, String>>(
                  future: resolveNames(data),
                  builder: (context, snapNames) {
                    final adminName = snapNames.hasData
                        ? snapNames.data!['admin'] ?? (data['adminId'] ?? '—')
                        : (data['adminId'] ?? '—');
                    final subjectName = snapNames.hasData
                        ? snapNames.data!['subject'] ??
                              (data['driverId'] ?? data['targetId'] ?? '')
                        : (data['driverId'] ?? data['targetId'] ?? '');

                    return styledCard(
                      child: ListTile(
                        title: Text(
                          '${data['action'] ?? 'action'} • $subjectName',
                          style: sectionTitleStyle(),
                        ),
                        subtitle: Text(
                          'By: $adminName • $when\n${data['reason'] ?? ''}',
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
