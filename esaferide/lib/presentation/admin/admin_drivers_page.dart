import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:esaferide/presentation/shared/app_scaffold.dart';
import 'package:esaferide/presentation/shared/styles.dart';
import 'package:esaferide/presentation/admin/admin_gate.dart';

class AdminDriversPage extends StatelessWidget {
  const AdminDriversPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      child: AppScaffold(
        title: 'Admin • Drivers',
        child: const AdminDriversList(),
      ),
    );
  }
}

class AdminDriversList extends StatefulWidget {
  const AdminDriversList({super.key});

  @override
  State<AdminDriversList> createState() => _AdminDriversListState();
}

class _AdminDriversListState extends State<AdminDriversList> {
  final _col = FirebaseFirestore.instance.collection('drivers');
  String _filter = 'pending'; // 'pending' | 'approved' | 'all'

  Future<void> _showDriverDetails(
    BuildContext ctx,
    String id,
    Map<String, dynamic> data,
  ) async {
    // fetch latest driver doc
    try {
      final doc = await _col.doc(id).get();
      final Map<String, dynamic> ddata = (doc.exists && doc.data() != null)
          ? (doc.data() as Map<String, dynamic>)
          : data;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dctx) => AlertDialog(
          title: Text(
            ddata['fullName'] ?? 'Driver',
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
                    if (ddata['profilePhotoUrl'] != null) ...[
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            ddata['profilePhotoUrl'],
                            height: 160,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (ddata['govIdUrl'] != null) ...[
                      Text('ID / Document', style: sectionTitleStyle()),
                      const SizedBox(height: 6),
                      Image.network(
                        ddata['govIdUrl'],
                        height: 160,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (ddata['licenseUrl'] != null) ...[
                      Text('License', style: sectionTitleStyle()),
                      const SizedBox(height: 6),
                      Image.network(
                        ddata['licenseUrl'],
                        height: 140,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text('Phone: ${ddata['phone'] ?? '—'}'),
                    const SizedBox(height: 6),
                    Text('Email: ${ddata['email'] ?? '—'}'),
                    const SizedBox(height: 6),
                    Text('Address: ${ddata['address'] ?? '—'}'),
                    const SizedBox(height: 6),
                    Text('License #: ${ddata['licenseNo'] ?? '—'}'),
                    const SizedBox(height: 6),
                    Text(
                      'Motorcycle: ${ddata['motorcycle']?['makeModel'] ?? '—'} • ${ddata['motorcycle']?['regNo'] ?? ''}',
                    ),
                    const SizedBox(height: 12),
                    if (ddata['emergencyContact'] != null) ...[
                      Text('Emergency Contact', style: sectionTitleStyle()),
                      const SizedBox(height: 6),
                      Text(
                        'Name: ${ddata['emergencyContact']?['name'] ?? '—'}',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Phone: ${ddata['emergencyContact']?['phone'] ?? '—'}',
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (ddata['notes'] != null) ...[
                      Text('Notes', style: sectionTitleStyle()),
                      const SizedBox(height: 6),
                      Text(ddata['notes']),
                    ],
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
      debugPrint('Error loading driver details: $e');
    }
  }

  Future<void> _verifyDriver(BuildContext ctx, String id) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: const Text('Verify driver'),
        content: const Text('Mark this driver as verified and active?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            style: primaryButtonStyle(),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    try {
      final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
      await _col.doc(id).update({
        'verified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': adminId,
        'status': 'active',
      });
      await FirebaseFirestore.instance.collection('admin_audit').add({
        'action': 'verify_driver',
        'driverId': id,
        'adminId': adminId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      final notif = {
        'userId': id,
        'type': 'driver_verified',
        'title': 'Driver account verified',
        'body': 'Your driver account has been verified and is now active.',
        'adminId': adminId,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      };
      await FirebaseFirestore.instance.collection('notifications').add(notif);
      await _col.doc(id).collection('notifications').add(notif);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Driver verified')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error verifying driver: $e')));
    }
  }

  Future<void> _rejectDriver(BuildContext ctx, String id) async {
    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: const Text('Reject driver'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Reject this driver registration? This will mark them as rejected.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. Documents incomplete, invalid license',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            style: primaryButtonStyle(),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    try {
      final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
      final reason = reasonController.text.trim();
      await _col.doc(id).update({
        'verified': false,
        'rejectedByAdmin': true,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': adminId,
        'status': 'rejected',
        if (reason.isNotEmpty) 'rejectionReason': reason,
      });
      await FirebaseFirestore.instance.collection('admin_audit').add({
        'action': 'reject_driver',
        'driverId': id,
        'adminId': adminId,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });
      final rnotif = {
        'userId': id,
        'type': 'driver_rejected',
        'title': 'Driver registration rejected',
        'body': reason.isEmpty
            ? 'Your driver registration was rejected. Please contact support for details.'
            : 'Your driver registration was rejected. Reason: $reason',
        'adminId': adminId,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      };
      await FirebaseFirestore.instance.collection('notifications').add(rnotif);
      await _col.doc(id).collection('notifications').add(rnotif);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Driver rejected')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error rejecting driver: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    Stream<QuerySnapshot> stream;
    if (_filter == 'pending') {
      stream = _col.where('status', isEqualTo: 'pending').snapshots();
    } else if (_filter == 'approved') {
      stream = _col.where('verified', isEqualTo: true).snapshots();
    } else {
      stream = _col.snapshots();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Pending'),
                selected: _filter == 'pending',
                onSelected: (_) => setState(() => _filter = 'pending'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Approved'),
                selected: _filter == 'approved',
                onSelected: (_) => setState(() => _filter = 'approved'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('All'),
                selected: _filter == 'all',
                onSelected: (_) => setState(() => _filter = 'all'),
              ),
              const Spacer(),
              Text(
                'Showing: ${_filter[0].toUpperCase()}${_filter.substring(1)}',
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return Center(
                  child: Text('No drivers', style: sectionTitleStyle()),
                );
              }
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
                          backgroundImage: data['profilePhotoUrl'] != null
                              ? NetworkImage(data['profilePhotoUrl'])
                              : null,
                          child: data['profilePhotoUrl'] == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(
                          data['fullName'] ?? 'Unnamed',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(data['phone'] ?? ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              onPressed: () =>
                                  _showDriverDetails(context, d.id, data),
                              style: primaryButtonStyle(),
                              child: const Text('View'),
                            ),
                            const SizedBox(width: 6),
                            if (data['verified'] == true)
                              const Chip(
                                label: Text('Verified'),
                                backgroundColor: Colors.greenAccent,
                              )
                            else ...[
                              ElevatedButton(
                                onPressed: () => _verifyDriver(context, d.id),
                                style: primaryButtonStyle(),
                                child: const Text('Verify'),
                              ),
                              const SizedBox(width: 6),
                              OutlinedButton(
                                onPressed: () => _rejectDriver(context, d.id),
                                style: outlinedButtonStyle(),
                                child: const Text('Reject'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
