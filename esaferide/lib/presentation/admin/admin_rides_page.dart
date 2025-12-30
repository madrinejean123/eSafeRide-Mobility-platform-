import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:esaferide/presentation/shared/app_scaffold.dart';
import 'package:esaferide/presentation/shared/styles.dart';
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
  final CollectionReference _rideCol = FirebaseFirestore.instance.collection(
    'rides',
  );

  final Map<String, String> _studentNameCache = {};
  final Set<String> _resolving = {};

  late final Stream<List<QueryDocumentSnapshot>> _ridesStream;

  @override
  void initState() {
    super.initState();

    // Combine pending and completed into a single stream
    _ridesStream = _rideCol
        .where('status', whereIn: ['pending', 'completed'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs)
        .asBroadcastStream(); // Make it broadcast to avoid multiple listens
  }

  Future<void> _resolveStudentName(String id) async {
    if (_studentNameCache.containsKey(id) || _resolving.contains(id)) return;
    _resolving.add(id);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('students')
          .doc(id)
          .get();
      final data = doc.data();
      if (!mounted) return;
      setState(() {
        _studentNameCache[id] = (data?['fullName'] as String?) ?? 'Student';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _studentNameCache[id] = 'Student';
      });
    } finally {
      _resolving.remove(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      child: AppScaffold(
        title: 'Admin • Rides',
        child: StreamBuilder<List<QueryDocumentSnapshot>>(
          stream: _ridesStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Error loading rides'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!;
            if (docs.isEmpty) {
              return const Center(child: Text('No rides available'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final d = docs[index];
                final data = d.data() as Map<String, dynamic>;
                final studentId = data['studentId'] as String?;

                // Resolve student name safely after build
                if (studentId != null &&
                    !_studentNameCache.containsKey(studentId) &&
                    !_resolving.contains(studentId)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _resolveStudentName(studentId);
                  });
                }

                final studentName = studentId != null
                    ? (_studentNameCache[studentId] ?? 'Student')
                    : (data['studentName'] ?? 'Student');

                final gp = data['pickup'] as GeoPoint?;
                final dest = data['destination'] as GeoPoint?;

                return _RideCard(
                  rideId: d.id,
                  studentName: studentName,
                  pickup: gp,
                  destination: dest,
                  status: data['status'] as String? ?? 'pending',
                  createdAt: data['createdAt'] as Timestamp?,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  final String rideId;
  final String studentName;
  final GeoPoint? pickup;
  final GeoPoint? destination;
  final String status;
  final Timestamp? createdAt;

  const _RideCard({
    required this.rideId,
    required this.studentName,
    this.pickup,
    this.destination,
    required this.status,
    this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = status == 'pending' ? Colors.orange : Colors.green;

    String formatGeo(GeoPoint? gp) => gp != null
        ? '${gp.latitude.toStringAsFixed(5)}, ${gp.longitude.toStringAsFixed(5)}'
        : '';

    final createdStr = createdAt != null
        ? TimeOfDay.fromDateTime(createdAt!.toDate()).format(context)
        : '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ride $rideId', style: sectionTitleStyle()),
                  const SizedBox(height: 6),
                  Text(
                    'Student: $studentName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (pickup != null)
                    Text(
                      'Pickup: ${formatGeo(pickup)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (destination != null)
                    Text(
                      'Dest: ${formatGeo(destination)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                    color: statusColor.withAlpha(50),
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
                TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Ride $rideId'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Student: $studentName'),
                            const SizedBox(height: 8),
                            Text('Status: $status'),
                            const SizedBox(height: 8),
                            Text('Created: $createdStr'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('View'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
