import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:esaferide/presentation/shared/app_scaffold.dart';
import 'package:esaferide/presentation/shared/styles.dart';
import 'admin_widgets.dart';
import 'package:esaferide/data/services/ride_service.dart';
import 'package:esaferide/presentation/admin/admin_gate.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int activeRides = 0;
  int pendingRides = 0;
  int completedRides = 0;
  int drivers = 0;
  int students = 0;
  int incidents = 0;

  @override
  void initState() {
    super.initState();
    // Listen to quick aggregates (simple approach)
    FirebaseFirestore.instance.collection('rides').snapshots().listen((snap) {
      final docs = snap.docs;
      setState(() {
        activeRides = docs
            .where((d) => (d.data()['status'] ?? '') == 'active')
            .length;
        pendingRides = docs
            .where((d) => (d.data()['status'] ?? '') == 'pending')
            .length;
        completedRides = docs
            .where((d) => (d.data()['status'] ?? '') == 'completed')
            .length;
      });
    });

    FirebaseFirestore.instance.collection('drivers').snapshots().listen((s) {
      setState(() => drivers = s.docs.length);
    });
    FirebaseFirestore.instance.collection('students').snapshots().listen((s) {
      setState(() => students = s.docs.length);
    });
    FirebaseFirestore.instance.collection('incidents').snapshots().listen((s) {
      setState(() => incidents = s.docs.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      child: AppScaffold(
        title: 'Admin • Dashboard',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // top stats
              Row(
                children: [
                  Expanded(
                    child: statCard(
                      'Active Rides',
                      '$activeRides',
                      icon: Icons.directions_bus,
                      color: kPrimaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: statCard(
                      'Pending',
                      '$pendingRides',
                      icon: Icons.schedule,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: statCard(
                      'Completed',
                      '$completedRides',
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: statCard(
                      'Drivers',
                      '$drivers',
                      icon: Icons.person,
                      color: kPrimaryTeal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: statCard(
                      'Students',
                      '$students',
                      icon: Icons.school,
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: statCard(
                      'Incidents',
                      '$incidents',
                      icon: Icons.report_problem,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              sectionHeader(
                'Trips per day (last 7)',
                trailing: TextButton(
                  onPressed: () {},
                  child: const Text('View'),
                ),
              ),
              const SizedBox(height: 8),
              styledCard(
                child: const SimpleBarChart(values: [3, 5, 2, 8, 6, 4, 7]),
              ),

              const SizedBox(height: 16),
              sectionHeader(
                'Active vs Completed',
                trailing: TextButton(
                  onPressed: () {},
                  child: const Text('Details'),
                ),
              ),
              const SizedBox(height: 8),
              styledCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('Active', style: sectionTitleStyle()),
                        const SizedBox(height: 6),
                        Text(
                          '$activeRides',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Completed', style: sectionTitleStyle()),
                        const SizedBox(height: 6),
                        Text(
                          '$completedRides',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              sectionHeader(
                'Alerts & Notifications',
                trailing: TextButton(
                  onPressed: () {},
                  child: const Text('Open'),
                ),
              ),
              const SizedBox(height: 8),
              styledCard(
                child: Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.warning, color: Colors.orange),
                      title: Text('No high priority alerts'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminRidesPage(),
                        ),
                      );
                    },
                    style: primaryButtonStyle(),
                    child: const Text('Manage Rides'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminDriversPage(),
                        ),
                      );
                    },
                    style: primaryButtonStyle(),
                    child: const Text('Drivers'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminStudentsPage(),
                        ),
                      );
                    },
                    style: primaryButtonStyle(),
                    child: const Text('Students'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Simple stub pages to navigate to
class AdminRidesPage extends StatelessWidget {
  const AdminRidesPage({super.key});

  @override
  Widget build(BuildContext context) => const AdminRidesPageBody();
}

class AdminRidesPageBody extends StatefulWidget {
  const AdminRidesPageBody({super.key});

  @override
  State<AdminRidesPageBody> createState() => _AdminRidesPageBodyState();
}

class _AdminRidesPageBodyState extends State<AdminRidesPageBody> {
  final _rideCol = FirebaseFirestore.instance.collection('rides');
  final RideService _rideService = RideService();

  Future<bool> _confirmAction(BuildContext ctx, String prompt) async {
    final res = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(prompt),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return res == true;
  }

  Future<void> _assignDriver(BuildContext ctx, String rideId) async {
    // open a dialog listing drivers
    await showDialog<void>(
      context: ctx,
      builder: (dctx) {
        final driversCol = FirebaseFirestore.instance.collection('drivers');
        return AlertDialog(
          title: const Text('Assign driver'),
          content: SizedBox(
            width: 400,
            height: 300,
            child: StreamBuilder<QuerySnapshot>(
              stream: driversCol.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Text('Error loading drivers');
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Text('No drivers available');
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final data = d.data() as Map<String, dynamic>;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: data['profilePhotoUrl'] != null
                            ? NetworkImage(data['profilePhotoUrl'])
                            : null,
                        child: data['profilePhotoUrl'] == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(data['fullName'] ?? 'Unnamed'),
                      subtitle: Text(data['phone'] ?? ''),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(dctx).pop();
                          try {
                            final ok = await _rideService.acceptRide(
                              rideId: rideId,
                              driverId: d.id,
                            );
                            if (!mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Driver assigned'
                                      : 'Could not assign driver',
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                        child: const Text('Assign'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      child: AppScaffold(
        title: 'Admin • Rides',
        child: StreamBuilder<QuerySnapshot>(
          stream: _rideCol.orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Error'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs;
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final d = docs[i];
                final data = d.data() as Map<String, dynamic>;
                final gp = data['pickup'] as GeoPoint?;
                final dest = data['destination'] as GeoPoint?;
                final student =
                    data['studentName'] ?? data['studentId'] ?? 'Student';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: styledCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Ride ${d.id}', style: sectionTitleStyle()),
                              const SizedBox(height: 6),
                              Text('Student: $student'),
                              Text('Pickup: ${gp?.latitude},${gp?.longitude}'),
                              Text(
                                'Dest: ${dest?.latitude},${dest?.longitude}',
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            ElevatedButton(
                              onPressed: () async {
                                // choose a driver to assign
                                await _assignDriver(context, d.id);
                              },
                              style: primaryButtonStyle(),
                              child: const Text('Approve'),
                            ),
                            const SizedBox(height: 6),
                            OutlinedButton(
                              onPressed: () async {
                                final ok = await _confirmAction(
                                  context,
                                  'Reject this ride?',
                                );
                                if (!ok) {
                                  return;
                                }
                                try {
                                  await _rideCol.doc(d.id).update({
                                    'status': 'rejected',
                                    'rejectedByAdmin': true,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });
                                  if (!mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text('Ride rejected'),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              },
                              child: const Text('Reject'),
                            ),
                          ],
                        ),
                      ],
                    ),
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

  Future<void> _showDriverDetails(
    BuildContext ctx,
    String id,
    Map<String, dynamic> data,
  ) async {
    await showDialog<void>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: Text(data['fullName'] ?? 'Driver'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data['profilePhotoUrl'] != null) ...[
                  const Text('Profile Photo'),
                  const SizedBox(height: 6),
                  Image.network(
                    data['profilePhotoUrl'],
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(height: 12),
                ],
                if (data['idDocumentUrl'] != null) ...[
                  const Text('ID / Document'),
                  const SizedBox(height: 6),
                  Image.network(
                    data['idDocumentUrl'],
                    height: 160,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 12),
                ],
                Text('Phone: ${data['phone'] ?? '—'}'),
                const SizedBox(height: 6),
                Text('License: ${data['licenseNumber'] ?? '—'}'),
                const SizedBox(height: 6),
                Text('Vehicle: ${data['vehicle'] ?? '—'}'),
                const SizedBox(height: 12),
                if (data['notes'] != null) ...[
                  const Text('Notes'),
                  const SizedBox(height: 6),
                  Text(data['notes']),
                ],
              ],
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
  }

  Future<void> _verifyDriver(
    BuildContext ctx,
    String id,
    Map<String, dynamic> data,
  ) async {
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
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
      await _col.doc(id).update({
        'verified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': adminId,
        'status': 'active',
      });

      // write audit
      await FirebaseFirestore.instance.collection('admin_audit').add({
        'action': 'verify_driver',
        'driverId': id,
        'adminId': adminId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // write notification (global and per-driver)
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
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: const Text('Reject driver'),
        content: const Text(
          'Reject this driver registration? This will mark them as rejected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
      await _col.doc(id).update({
        'verified': false,
        'rejectedByAdmin': true,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': adminId,
        'status': 'rejected',
      });

      await FirebaseFirestore.instance.collection('admin_audit').add({
        'action': 'reject_driver',
        'driverId': id,
        'adminId': adminId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // write notification (global and per-driver)
      final rnotif = {
        'userId': id,
        'type': 'driver_rejected',
        'title': 'Driver registration rejected',
        'body':
            'Your driver registration was rejected. Please contact support for details.',
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
                    backgroundImage: data['profilePhotoUrl'] != null
                        ? NetworkImage(data['profilePhotoUrl'])
                        : null,
                    child: data['profilePhotoUrl'] == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(data['fullName'] ?? 'Unnamed'),
                  subtitle: Text(data['phone'] ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () =>
                            _showDriverDetails(context, d.id, data),
                        child: const Text('View'),
                      ),
                      const SizedBox(width: 6),
                      if (data['verified'] == true) ...[
                        const Chip(
                          label: Text('Verified'),
                          backgroundColor: Colors.greenAccent,
                        ),
                      ] else ...[
                        ElevatedButton(
                          onPressed: () => _verifyDriver(context, d.id, data),
                          style: primaryButtonStyle(),
                          child: const Text('Verify'),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton(
                          onPressed: () => _rejectDriver(context, d.id),
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
    );
  }
}

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
                  title: Text(data['name'] ?? 'Unnamed'),
                  subtitle: Text(
                    'Class: ${data['class'] ?? ''} • Special needs: ${data['specialNeeds'] ?? '—'}',
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {},
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

// The rest of admin pages are placeholders for expansion
class AdminLiveMapPage extends StatelessWidget {
  const AdminLiveMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      child: AppScaffold(
        title: 'Admin • Live Map',
        child: Center(
          child: Text(
            'Live map and active rides will appear here',
            style: sectionTitleStyle(),
          ),
        ),
      ),
    );
  }
}

class AdminNotificationsPage extends StatelessWidget {
  const AdminNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      child: AppScaffold(
        title: 'Admin • Notifications',
        child: Center(
          child: Text('Notifications panel', style: sectionTitleStyle()),
        ),
      ),
    );
  }
}

class AdminReportsPage extends StatelessWidget {
  const AdminReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      child: AppScaffold(
        title: 'Admin • Reports',
        child: Center(
          child: Text('Reports & exports', style: sectionTitleStyle()),
        ),
      ),
    );
  }
}

class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      child: AppScaffold(
        title: 'Admin • Settings',
        child: Center(
          child: Text('System settings', style: sectionTitleStyle()),
        ),
      ),
    );
  }
}
