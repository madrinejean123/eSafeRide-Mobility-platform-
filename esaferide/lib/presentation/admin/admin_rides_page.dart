import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:esaferide/presentation/shared/app_scaffold.dart';
import 'package:esaferide/presentation/shared/styles.dart';
import 'package:esaferide/data/services/ride_service.dart';
import 'package:esaferide/data/services/geocode_service.dart';
import 'package:esaferide/presentation/admin/admin_gate.dart';

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

  // ignore: unused_element
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
            style: primaryButtonStyle(),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return res == true;
  }

  // ignore: unused_element
  Future<void> _assignDriver(BuildContext ctx, String rideId) async {
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
                            if (!mounted) return;
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
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                        style: primaryButtonStyle(),
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
          // Admin should only see rides that are either pending (available)
          // or completed (finished). Admins do not assign drivers here.
          stream: _rideCol
              .where('status', whereIn: ['pending', 'completed'])
              .orderBy('createdAt', descending: true)
              .snapshots(),
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
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _RideCard(rideId: d.id, data: data),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _RideCard extends StatefulWidget {
  final String rideId;
  final Map<String, dynamic> data;

  const _RideCard({required this.rideId, required this.data});

  @override
  State<_RideCard> createState() => _RideCardState();
}

class _RideCardState extends State<_RideCard> {
  String? _studentName;
  String? _pickupLabel;
  String? _destLabel;

  @override
  void initState() {
    super.initState();
    _resolveStudentAndLabels();
  }

  Future<void> _resolveStudentAndLabels() async {
    try {
      final data = widget.data;
      final sid = data['studentId'] as String?;
      if (data['studentName'] != null) {
        _studentName = data['studentName'] as String?;
      } else if (sid != null && sid.isNotEmpty) {
        final sdoc = await FirebaseFirestore.instance
            .collection('students')
            .doc(sid)
            .get();
        if (sdoc.exists && sdoc.data() != null) {
          final sdata = sdoc.data() as Map<String, dynamic>;
          _studentName = sdata['fullName'] ?? sdata['name'];
        }
      }

      final gp = data['pickup'] as GeoPoint?;
      final dest = data['destination'] as GeoPoint?;
      if (gp != null) {
        final label = await resolveLabel(gp.latitude, gp.longitude);
        _pickupLabel =
            label ??
            '${gp.latitude.toStringAsFixed(5)}, ${gp.longitude.toStringAsFixed(5)}';
      }
      if (dest != null) {
        final label = await resolveLabel(dest.latitude, dest.longitude);
        _destLabel =
            label ??
            '${dest.latitude.toStringAsFixed(5)}, ${dest.longitude.toStringAsFixed(5)}';
      }
    } catch (e) {
      debugPrint('Error resolving ride labels: $e');
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final gp = data['pickup'] as GeoPoint?;
    final dest = data['destination'] as GeoPoint?;
    final student =
        _studentName ?? data['studentName'] ?? data['studentId'] ?? 'Student';
    // Admins should not approve/reject here. Show ride details and status.
    final status = (data['status'] as String?) ?? 'pending';
    final statusColor = status == 'pending'
        ? Colors.orange
        : (status == 'completed' ? Colors.green : Colors.grey);

    return styledCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ride ${widget.rideId}', style: sectionTitleStyle()),
                const SizedBox(height: 6),
                Text('Student: $student'),
                if (gp != null)
                  Text(
                    'Pickup: ${_pickupLabel ?? '${gp.latitude},${gp.longitude}'}',
                  ),
                if (dest != null)
                  Text(
                    'Dest: ${_destLabel ?? '${dest.latitude},${dest.longitude}'}',
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha((0.12 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: _showDetails, child: const Text('View')),
            ],
          ),
        ],
      ),
    );
  }

  void _showDetails() {
    showDialog<void>(
      context: context,
      builder: (dctx) {
        final data = widget.data;
        final created = data['createdAt'] as Timestamp?;
        final createdStr = created != null
            ? TimeOfDay.fromDateTime(created.toDate()).format(context)
            : '';
        return AlertDialog(
          title: Text('Ride ${widget.rideId}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Student: ${data['studentName'] ?? data['studentId'] ?? ''}',
                ),
                const SizedBox(height: 8),
                Text('Status: ${data['status'] ?? ''}'),
                const SizedBox(height: 8),
                Text('Created: $createdStr'),
              ],
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
}
