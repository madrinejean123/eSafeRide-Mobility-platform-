import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:esaferide/firebase_options.dart';
import 'package:url_launcher/url_launcher_string.dart';

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

                  return Card(
                    elevation: 2,
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          driverName.isNotEmpty ? driverName[0] : '?',
                        ),
                      ),
                      title: Text(
                        'From: ${pickup?.latitude.toStringAsFixed(3)}, ${pickup?.longitude.toStringAsFixed(3)}\nTo: ${destination?.latitude.toStringAsFixed(3)}, ${destination?.longitude.toStringAsFixed(3)}',
                      ),
                      subtitle: Text('Duration: ${duration}s • Fare: \$$fare'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timeStr,
                            style: const TextStyle(fontSize: 12),
                          ),
                          IconButton(
                            tooltip: 'Open in Firebase',
                            onPressed: () async {
                              final projectId =
                                  DefaultFirebaseOptions.currentPlatform.projectId;
                              final path = '~2Frides~2F${rides[index].id}';
                              final url =
                                  'https://console.firebase.google.com/project/$projectId/firestore/data/$path';
                              await launchUrlString(url);
                            },
                            icon: const Icon(Icons.open_in_new),
                          ),
                        ],
                      ),
                    ),
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
