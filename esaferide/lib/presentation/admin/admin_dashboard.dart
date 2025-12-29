import 'package:flutter/material.dart';
import 'package:esaferide/presentation/shared/app_scaffold.dart';
import 'package:esaferide/presentation/shared/styles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_rides_page.dart';
import 'admin_drivers_page.dart';
import 'admin_students_page.dart';
import 'admin_audit_page.dart';
import 'admin_live_map_page.dart';
import 'admin_gate.dart';

// Small, focused admin dashboard that launches the sub-pages implemented
// under lib/presentation/admin/*. This replaces a previously very large
// file that contained multiple page implementations.

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // Firestore collection shortcuts
  final _rides = FirebaseFirestore.instance.collection('rides');
  final _drivers = FirebaseFirestore.instance.collection('drivers');
  final _students = FirebaseFirestore.instance.collection('students');
  final _audit = FirebaseFirestore.instance.collection('admin_audit');

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      child: AppScaffold(
        title: 'Admin Dashboard',
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top quick stats row
                Row(
                  children: [
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _rides.snapshots(),
                        builder: (context, snap) {
                          final count = snap.hasData
                              ? snap.data!.docs.length
                              : 0;
                          return _statCard(
                            title: 'Rides',
                            subtitle: '$count total',
                            icon: Icons.directions_car,
                            color: Colors.blue,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _drivers
                            .where('verified', isEqualTo: false)
                            .snapshots(),
                        builder: (context, snap) {
                          final pending = snap.hasData
                              ? snap.data!.docs.length
                              : 0;
                          return _statCard(
                            title: 'Drivers',
                            subtitle: '$pending pending',
                            icon: Icons.person,
                            color: Colors.green,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _students.snapshots(),
                        builder: (context, snap) {
                          final count = snap.hasData
                              ? snap.data!.docs.length
                              : 0;
                          return _statCard(
                            title: 'Students',
                            subtitle: '$count total',
                            icon: Icons.school,
                            color: Colors.orange,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _audit.snapshots(),
                        builder: (context, snap) {
                          final count = snap.hasData
                              ? snap.data!.docs.length
                              : 0;
                          return _statCard(
                            title: 'Audit',
                            subtitle: '$count entries',
                            icon: Icons.history,
                            color: Colors.purple,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Action tiles
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 3.4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    _actionTile(context, 'Live Map', Icons.map, () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminLiveMapPage(),
                        ),
                      );
                    }),
                    _actionTile(context, 'Rides', Icons.directions_car, () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminRidesPage(),
                        ),
                      );
                    }),
                    _actionTile(context, 'Drivers', Icons.person, () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminDriversPage(),
                        ),
                      );
                    }),
                    _actionTile(context, 'Students', Icons.school, () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminStudentsPage(),
                        ),
                      );
                    }),
                    _actionTile(context, 'Audit', Icons.history, () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminAuditPage(),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withAlpha((0.12 * 255).round()),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: sectionTitleStyle()),
                  const SizedBox(height: 4),
                  Text(subtitle, style: subtleStyle()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: sectionTitleStyle())),
              ElevatedButton(
                onPressed: onTap,
                style: primaryButtonStyle(),
                child: const Text('Open'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
