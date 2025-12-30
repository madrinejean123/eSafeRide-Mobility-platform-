import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:esaferide/presentation/shared/app_scaffold.dart';
import 'package:esaferide/presentation/shared/styles.dart';

import 'admin_rides_page.dart';
import 'admin_drivers_page.dart';
import 'admin_students_page.dart';
import 'admin_audit_page.dart';
import 'admin_live_map_page.dart';
import 'admin_gate.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  final _rides = FirebaseFirestore.instance.collection('rides');
  final _drivers = FirebaseFirestore.instance.collection('drivers');
  final _students = FirebaseFirestore.instance.collection('students');
  final _audit = FirebaseFirestore.instance.collection('admin_audit');

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      lowerBound: 0.9,
      upperBound: 1.1,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      child: AppScaffold(
        title: 'Admin Dashboard',
        showBackButton: false,
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              final nav = Navigator.of(context);
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              nav.pushReplacementNamed('/login');
            },
          ),
        ],
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAdminHeader(),
                    const SizedBox(height: 24),

                    _buildStatsSection(),
                    const SizedBox(height: 24),

                    _buildNotificationsSection(),
                    const SizedBox(height: 24),

                    _buildLiveTrackingCard(context),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _buildFooterActions(context),
          ],
        ),
      ),
    );
  }

  // -------------------- ADMIN HEADER --------------------

  Widget _buildAdminHeader() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return _adminHeaderUI('System Admin');
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('admin') // ✅ CORRECT COLLECTION
          .doc(uid)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return _adminHeaderUI('System Admin');
        }

        final data = snap.data!.data() as Map<String, dynamic>;
        final name = data['name'] ?? 'System Admin';

        return _adminHeaderUI(name);
      },
    );
  }

  Widget _adminHeaderUI(String name) {
    return Row(
      children: [
        Stack(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: Colors.blue,
              child: Icon(
                Icons.admin_panel_settings,
                color: Colors.white,
                size: 30,
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: const [
                Text(
                  'ONLINE',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  '• Live system monitoring',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // -------------------- STATS --------------------

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Overview', style: sectionTitleStyle()),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _coloredStat(
                title: 'Rides',
                stream: _rides.snapshots(),
                icon: Icons.directions_car,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _coloredStat(
                title: 'Students',
                stream: _students.snapshots(),
                icon: Icons.school,
                color: Colors.pink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _coloredStat(
                title: 'Pending Drivers',
                stream: _drivers
                    .where('verified', isEqualTo: false)
                    .snapshots(),
                icon: Icons.person_outline,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _coloredStat(
                title: 'Audit Logs',
                stream: _audit.snapshots(),
                icon: Icons.history,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _coloredStat({
    required String title,
    required Stream<QuerySnapshot> stream,
    required IconData icon,
    required Color color,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        final count = snap.hasData ? snap.data!.docs.length : 0;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withAlpha((0.12 * 255).round()),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withAlpha((0.2 * 255).round()),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: sectionTitleStyle().copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // -------------------- NOTIFICATIONS --------------------

  Widget _buildNotificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notifications', style: sectionTitleStyle()),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: _drivers.where('verified', isEqualTo: false).snapshots(),
          builder: (context, snap) {
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return _emptyNotice();
            }

            return Column(
              children: snap.data!.docs.take(5).map((doc) {
                final Map<String, dynamic>? ddata =
                    doc.data() as Map<String, dynamic>?;
                final name = ddata == null
                    ? 'Unknown Driver'
                    : (ddata['fullName'] ?? ddata['name'] ?? 'Unknown Driver');
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 165, 0, 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '$name is awaiting verification',
                          style: subtleStyle(),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminDriversPage(),
                            ),
                          );
                        },
                        child: const Text('Review'),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _emptyNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: const [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 12),
          Text('No pending driver verifications'),
        ],
      ),
    );
  }

  // -------------------- LIVE TRACKING --------------------

  Widget _buildLiveTrackingCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminLiveMapPage()),
        );
      },
      child: ScaleTransition(
        scale: _pulseController,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withAlpha((0.12 * 255).round()),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: const [
              Icon(Icons.location_on, color: Colors.blue, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Live Tracking — Tap to monitor rides in real time',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------- FOOTER --------------------

  Widget _buildFooterActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            color: Colors.black.withAlpha((0.05 * 255).round()),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _footerButton(
            icon: Icons.map,
            label: 'Live Map',
            onTap: () => _go(context, const AdminLiveMapPage()),
          ),
          _footerButton(
            icon: Icons.directions_car,
            label: 'Rides',
            onTap: () => _go(context, const AdminRidesPage()),
          ),
          _footerButton(
            icon: Icons.person,
            label: 'Drivers',
            onTap: () => _go(context, const AdminDriversPage()),
          ),
          _footerButton(
            icon: Icons.school,
            label: 'Students',
            onTap: () => _go(context, const AdminStudentsPage()),
          ),
          _footerButton(
            icon: Icons.history,
            label: 'Audit',
            onTap: () => _go(context, const AdminAuditPage()),
          ),
        ],
      ),
    );
  }

  Widget _footerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 26),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  void _go(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}
