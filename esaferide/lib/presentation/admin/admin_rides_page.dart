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
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _RideCard(
                    rideId: d.id,
                    data: data,
                    onAssign: () => _assignDriver(context, d.id),
                    onReject: () async {
                      final ok = await _confirmAction(
                        context,
                        'Reject this ride?',
                      );
                      if (!ok) return false;
                      try {
                        await _rideCol.doc(d.id).update({
                          'status': 'rejected',
                          'rejectedByAdmin': true,
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                        if (!mounted) return false;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(content: Text('Ride rejected')),
                        );
                        return true;
                      } catch (e) {
                        if (!mounted) return false;
                        ScaffoldMessenger.of(
                          this.context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        return false;
                      }
                    },
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

class _RideCard extends StatefulWidget {
  final String rideId;
  final Map<String, dynamic> data;
  final VoidCallback onAssign;
  final Future<bool> Function() onReject;

  const _RideCard({
    required this.rideId,
    required this.data,
    required this.onAssign,
    required this.onReject,
  });

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
            children: [
              ElevatedButton(
                onPressed: widget.onAssign,
                style: primaryButtonStyle(),
                child: const Text('Approve'),
              ),
              const SizedBox(height: 6),
              OutlinedButton(
                onPressed: () async {
                  await widget.onReject();
                },
                child: const Text('Reject'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
