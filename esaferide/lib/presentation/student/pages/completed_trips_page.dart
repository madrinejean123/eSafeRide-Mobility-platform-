import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:esaferide/presentation/shared/completed_item_helpers.dart';

class CompletedRidesPage extends StatelessWidget {
  const CompletedRidesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Sign in required')));
    }

    // Query only completed rides for the current student
    final ridesStream = FirebaseFirestore.instance
        .collection('rides')
        .where('studentId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'completed')
        .orderBy('completedAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Completed Rides')),
      body: StreamBuilder<QuerySnapshot>(
        stream: ridesStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rides = snapshot.data!.docs;

          if (rides.isEmpty) {
            return const Center(child: Text('No completed rides yet'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: rides.length,
            itemBuilder: (context, index) {
              final ride = rides[index].data() as Map<String, dynamic>;

              final driverId = ride['driverId'] as String?;
              final fare = ride['fare'] ?? 0;
              final duration = ride['durationSeconds'] ?? 0;
              final pickup = ride['pickup'] as GeoPoint?;
              final destination = ride['destination'] as GeoPoint?;
              final completedAt = ride['completedAt'] as Timestamp?;

              return FutureBuilder<DocumentSnapshot>(
                future: driverId != null
                    ? FirebaseFirestore.instance
                          .collection('drivers')
                          .doc(driverId)
                          .get()
                    : null,
                builder: (context, driverSnap) {
                  String driverName = 'Driver';
                  if (driverSnap.hasData && driverSnap.data!.exists) {
                    final data =
                        driverSnap.data!.data() as Map<String, dynamic>?;
                    driverName = data?['fullName'] ?? 'Driver';
                  }

                  final timeStr = completedAt != null
                      ? TimeOfDay.fromDateTime(
                          completedAt.toDate(),
                        ).format(context)
                      : '';

                  final pickupLabelStr =
                      (ride['pickupLabel'] as String?) ??
                      (pickup != null
                          ? '${pickup.latitude.toStringAsFixed(3)}, ${pickup.longitude.toStringAsFixed(3)}'
                          : null);
                  final destLabelStr =
                      (ride['destinationLabel'] as String?) ??
                      (destination != null
                          ? '${destination.latitude.toStringAsFixed(3)}, ${destination.longitude.toStringAsFixed(3)}'
                          : null);

                  return CompletedRideTile(
                    avatarText: driverName,
                    title: driverName,
                    pickupLabel: pickupLabelStr,
                    destinationLabel: destLabelStr,
                    fareLabel:
                        '${formatCurrency(fare)}${duration != 0 ? ' • ${duration}s' : ''}',
                    timeLabel: timeStr,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
