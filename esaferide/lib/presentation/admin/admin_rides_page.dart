import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:esaferide/presentation/shared/app_scaffold.dart';
import 'package:esaferide/presentation/shared/styles.dart';
import 'package:esaferide/presentation/shared/completed_item_helpers.dart';
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
    _ridesStream = _rideCol
        .where('status', whereIn: ['pending', 'completed'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs)
        .asBroadcastStream();
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
              debugPrint('AdminRidesPage stream error: ${snapshot.error}');
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
                try {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final studentId = data['studentId'] as String?;

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

                  final pickup = data['pickup'] as GeoPoint?;
                  final destination = data['destination'] as GeoPoint?;
                  final status = data['status'] as String? ?? 'pending';
                  final createdAt = data['createdAt'] as Timestamp?;
                  final fare = data['fare'];

                  return _RideCard(
                    rideId: doc.id,
                    studentName: studentName,
                    pickup: pickup,
                    destination: destination,
                    status: status,
                    createdAt: createdAt,
                    fare: fare,
                  );
                } catch (e, st) {
                  debugPrint('AdminRidesPage itemBuilder error: $e\n$st');
                  return Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Error rendering ride item'),
                    ),
                  );
                }
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
  final dynamic fare;

  const _RideCard({
    required this.rideId,
    required this.studentName,
    this.pickup,
    this.destination,
    required this.status,
    this.createdAt,
    this.fare,
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

    final fareLabel = formatCurrency(fare);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        title: Text(
          'Ride $rideId — $studentName',
          style: sectionTitleStyle(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
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
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    fareLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(createdStr, style: const TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(50),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
        onTap: () {
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
      ),
    );
  }
}
